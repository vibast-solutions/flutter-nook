import 'package:meta/meta.dart';

import 'spec.dart';
import 'technique.dart';

/// What one run of [SudokuLogicSolver] found.
///
/// A run that stops short is not an error. "This puzzle cannot be finished by
/// reasoning a person could do" is the single most useful thing the engine can
/// say, because it is what keeps such a puzzle from ever reaching a player.
class SudokuSolveReport {
  SudokuSolveReport({
    required this.isSolved,
    required List<int> cells,
    required Map<SudokuTechnique, int> steps,
  }) : cells = List<int>.unmodifiable(cells),
       steps = Map<SudokuTechnique, int>.unmodifiable(steps);

  /// Whether the board was filled completely.
  final bool isSolved;

  /// The board as far as the solver got. Every digit here was deduced, never
  /// assumed, so a partial result is still a correct partial result.
  final List<int> cells;

  /// How many times each technique was the one that broke the deadlock.
  final Map<SudokuTechnique, int> steps;

  /// The hardest technique the puzzle actually required, or `null` if it needed
  /// none at all (an already-solved grid).
  SudokuTechnique? get hardest {
    SudokuTechnique? hardest;
    for (final SudokuTechnique technique in steps.keys) {
      if (hardest == null || technique.index > hardest.index) {
        hardest = technique;
      }
    }
    return hardest;
  }

  /// The band [hardest] belongs to.
  TechniqueTier? get hardestTier => hardest?.tier;

  /// How many deductions of [tier] the puzzle needed.
  int countOf(TechniqueTier tier) {
    int total = 0;
    steps.forEach((SudokuTechnique technique, int count) {
      if (technique.tier == tier) {
        total += count;
      }
    });
    return total;
  }

  /// How many times [technique] was needed.
  int countTechnique(SudokuTechnique technique) => steps[technique] ?? 0;

  @override
  String toString() =>
      'SudokuSolveReport(${isSolved ? 'solved' : 'stalled'}, '
      'hardest ${hardest?.name ?? 'none'})';
}

/// One digit a solver worked out, and the reasoning that justified it.
///
/// The unit a hint is made of: where the digit goes, what it is, and which
/// rung of the ladder produced it. Only [SudokuTechnique.nakedSingle] and
/// [SudokuTechnique.hiddenSingle] ever place a digit — the rest of the ladder
/// rules candidates out — so [technique] is always one of those two, reached
/// after however much elimination the board needed first.
@immutable
class SudokuPlacement {
  const SudokuPlacement({
    required this.index,
    required this.digit,
    required this.technique,
  });

  /// Which cell the digit belongs in.
  final int index;

  /// The digit itself.
  final int digit;

  /// The deduction that put it there.
  final SudokuTechnique technique;

  @override
  bool operator ==(Object other) {
    return other is SudokuPlacement &&
        other.index == index &&
        other.digit == digit &&
        other.technique == technique;
  }

  @override
  int get hashCode => Object.hash(index, digit, technique);

  @override
  String toString() => 'SudokuPlacement($digit at $index, ${technique.name})';
}

/// Solves a Sudoku using only deductions a person could make.
///
/// This is the opposite of [SudokuSolver] in `solver.dart`, and both are
/// deliberate. That one searches, backtracks and answers "how many solutions?".
/// This one never guesses, never backtracks and never places a digit it cannot
/// justify — which is exactly why its verdict can be trusted as a measure of
/// how hard a puzzle is for a human, and why a puzzle it cannot finish is
/// thrown away rather than sold as a harder one.
///
/// Candidates are bitmasks: bit `d - 1` set means digit `d` is still possible.
class SudokuLogicSolver {
  SudokuLogicSolver(this.spec)
    : _size = spec.size,
      _cellCount = spec.cellCount,
      _allDigits = (1 << spec.size) - 1 {
    spec.validate();
    _units = _buildUnits();
    _rows = _units.sublist(0, _size);
    _columns = _units.sublist(_size, _size * 2);
    _boxes = _units.sublist(_size * 2, _size * 3);
    _unitsOf = List<List<int>>.generate(_cellCount, (int _) => <int>[]);
    for (int unit = 0; unit < _units.length; unit++) {
      for (final int cell in _units[unit]) {
        _unitsOf[cell].add(unit);
      }
    }
    _peers = List<Set<int>>.generate(_cellCount, (int cell) {
      final Set<int> peers = <int>{};
      for (final int unit in _unitsOf[cell]) {
        peers.addAll(_units[unit]);
      }
      return peers..remove(cell);
    });
  }

  /// The grid shape being solved.
  final SudokuSpec spec;

  final int _size;
  final int _cellCount;
  final int _allDigits;

  /// Every row, then every column, then every box.
  late final List<List<int>> _units;
  late final List<List<int>> _rows;
  late final List<List<int>> _columns;
  late final List<List<int>> _boxes;
  late final List<List<int>> _unitsOf;
  late final List<Set<int>> _peers;

  List<List<int>> _buildUnits() {
    final List<List<int>> rows = List<List<int>>.generate(
      _size,
      (int _) => <int>[],
    );
    final List<List<int>> columns = List<List<int>>.generate(
      _size,
      (int _) => <int>[],
    );
    final List<List<int>> boxes = List<List<int>>.generate(
      _size,
      (int _) => <int>[],
    );
    for (int index = 0; index < _cellCount; index++) {
      rows[spec.rowOf(index)].add(index);
      columns[spec.columnOf(index)].add(index);
      boxes[spec.boxOf(index)].add(index);
    }
    return <List<int>>[...rows, ...columns, ...boxes];
  }

  /// Solves [givens] as far as pure deduction reaches.
  ///
  /// [givens] is a flat grid with `0` for empty cells. A grid that already
  /// breaks the rules comes back unsolved with no steps recorded, because
  /// there was nothing legitimate to deduce from it.
  SudokuSolveReport solve(List<int> givens) {
    if (givens.length != _cellCount) {
      throw ArgumentError('Expected $_cellCount cells, got ${givens.length}.');
    }
    final _Board board = _Board(this, givens);
    final Map<SudokuTechnique, int> steps = <SudokuTechnique, int>{};
    if (board.isBroken) {
      return SudokuSolveReport(
        isSolved: false,
        cells: board.cells,
        steps: steps,
      );
    }

    while (!board.isComplete) {
      final SudokuTechnique? applied = _applyEasiest(board);
      if (applied == null || board.isBroken) {
        break;
      }
      steps.update(applied, (int count) => count + 1, ifAbsent: () => 1);
    }

    return SudokuSolveReport(
      isSolved: board.isComplete && !board.isBroken,
      cells: board.cells,
      steps: steps,
    );
  }

  /// The digits the solver can work out from [cells], in the order a person
  /// would reach them.
  ///
  /// Lazy on purpose: a hint needs the first placement it can use and nothing
  /// more, and solving a 9x9 to the end to answer that would be dozens of
  /// deductions of wasted work. The sequence stops where reasoning does — at a
  /// full grid, at a board that contradicts itself, or at a puzzle this solver
  /// cannot finish.
  Iterable<SudokuPlacement> placements(List<int> cells) sync* {
    if (cells.length != _cellCount) {
      throw ArgumentError('Expected $_cellCount cells, got ${cells.length}.');
    }
    final _Board board = _Board(this, cells);
    if (board.isBroken) {
      return;
    }
    while (!board.isComplete) {
      board.lastPlaced = null;
      final SudokuTechnique? applied = _applyEasiest(board);
      if (applied == null || board.isBroken) {
        return;
      }
      final int? index = board.lastPlaced;
      if (index != null) {
        yield SudokuPlacement(
          index: index,
          digit: board.cells[index],
          technique: applied,
        );
      }
    }
  }

  /// Runs the ladder from the bottom and returns the first rung that moved the
  /// board, so a puzzle is only ever charged for the easiest thing that worked.
  SudokuTechnique? _applyEasiest(_Board board) {
    for (final SudokuTechnique technique in SudokuTechnique.values) {
      if (_apply(technique, board)) {
        return technique;
      }
    }
    return null;
  }

  bool _apply(SudokuTechnique technique, _Board board) {
    switch (technique) {
      case SudokuTechnique.nakedSingle:
        return _nakedSingle(board);
      case SudokuTechnique.hiddenSingle:
        return _hiddenSingle(board);
      case SudokuTechnique.nakedPair:
        return _nakedSubset(board, 2);
      case SudokuTechnique.hiddenPair:
        return _hiddenSubset(board, 2);
      case SudokuTechnique.pointingPair:
        return _pointing(board);
      case SudokuTechnique.boxLineReduction:
        return _boxLineReduction(board);
      case SudokuTechnique.nakedTriple:
        return _nakedSubset(board, 3);
      case SudokuTechnique.hiddenTriple:
        return _hiddenSubset(board, 3);
      case SudokuTechnique.xWing:
        return _fish(board, 2);
      case SudokuTechnique.swordfish:
        return _fish(board, 3);
      case SudokuTechnique.xyWing:
        return _xyWing(board);
      case SudokuTechnique.simpleColouring:
        return _simpleColouring(board);
    }
  }

  bool _nakedSingle(_Board board) {
    for (int index = 0; index < _cellCount; index++) {
      if (board.cells[index] != 0) {
        continue;
      }
      final int candidates = board.candidates[index];
      if (_bitCount(candidates) == 1) {
        board.place(index, _lowestDigit(candidates));
        return true;
      }
    }
    return false;
  }

  bool _hiddenSingle(_Board board) {
    for (final List<int> unit in _units) {
      for (int digit = 1; digit <= _size; digit++) {
        final int bit = 1 << (digit - 1);
        int only = -1;
        int seen = 0;
        bool placed = false;
        for (final int index in unit) {
          if (board.cells[index] == digit) {
            placed = true;
            break;
          }
          if ((board.candidates[index] & bit) != 0) {
            seen++;
            only = index;
          }
        }
        if (!placed && seen == 1) {
          board.place(only, digit);
          return true;
        }
      }
    }
    return false;
  }

  /// Naked pairs and triples: [size] cells in a unit sharing exactly [size]
  /// candidates between them, which therefore belong to those cells alone.
  bool _nakedSubset(_Board board, int size) {
    for (final List<int> unit in _units) {
      final List<int> open = <int>[
        for (final int index in unit)
          if (board.cells[index] == 0) index,
      ];
      if (open.length <= size) {
        continue;
      }
      final List<List<int>> groups = _combinations(open.length, size);
      for (final List<int> group in groups) {
        int union = 0;
        bool tooWide = false;
        for (final int slot in group) {
          union |= board.candidates[open[slot]];
          if (_bitCount(union) > size) {
            tooWide = true;
            break;
          }
        }
        if (tooWide || _bitCount(union) != size) {
          continue;
        }
        final Set<int> members = <int>{
          for (final int slot in group) open[slot],
        };
        bool changed = false;
        for (final int index in open) {
          if (members.contains(index)) {
            continue;
          }
          changed |= board.eliminate(index, union);
        }
        if (changed) {
          return true;
        }
      }
    }
    return false;
  }

  /// Hidden pairs and triples: [size] digits in a unit confined to the same
  /// [size] cells, which therefore hold nothing else.
  bool _hiddenSubset(_Board board, int size) {
    for (final List<int> unit in _units) {
      final List<int> digits = <int>[];
      final List<int> masks = <int>[];
      for (int digit = 1; digit <= _size; digit++) {
        final int bit = 1 << (digit - 1);
        int cellMask = 0;
        int seen = 0;
        for (int slot = 0; slot < unit.length; slot++) {
          if ((board.candidates[unit[slot]] & bit) != 0) {
            cellMask |= 1 << slot;
            seen++;
          }
        }
        if (seen >= 2 && seen <= size) {
          digits.add(digit);
          masks.add(cellMask);
        }
      }
      if (digits.length < size) {
        continue;
      }
      for (final List<int> group in _combinations(digits.length, size)) {
        int cells = 0;
        int digitMask = 0;
        for (final int slot in group) {
          cells |= masks[slot];
          digitMask |= 1 << (digits[slot] - 1);
        }
        if (_bitCount(cells) != size) {
          continue;
        }
        bool changed = false;
        for (int slot = 0; slot < unit.length; slot++) {
          if ((cells & (1 << slot)) == 0) {
            continue;
          }
          changed |= board.eliminate(unit[slot], ~digitMask & _allDigits);
        }
        if (changed) {
          return true;
        }
      }
    }
    return false;
  }

  /// A digit whose candidates within one box all fall on a single row or
  /// column cannot appear anywhere else on that line.
  bool _pointing(_Board board) {
    for (final List<int> box in _boxes) {
      for (int digit = 1; digit <= _size; digit++) {
        final int bit = 1 << (digit - 1);
        final List<int> places = <int>[
          for (final int index in box)
            if ((board.candidates[index] & bit) != 0) index,
        ];
        if (places.length < 2) {
          continue;
        }
        for (final bool byRow in <bool>[true, false]) {
          final int line = byRow
              ? spec.rowOf(places.first)
              : spec.columnOf(places.first);
          final bool aligned = places.every(
            (int index) =>
                (byRow ? spec.rowOf(index) : spec.columnOf(index)) == line,
          );
          if (!aligned) {
            continue;
          }
          final Set<int> inBox = places.toSet();
          bool changed = false;
          for (final int index in byRow ? _rows[line] : _columns[line]) {
            if (inBox.contains(index) ||
                spec.boxOf(index) == spec.boxOf(places.first)) {
              continue;
            }
            changed |= board.eliminate(index, bit);
          }
          if (changed) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// The mirror of [_pointing]: a digit whose candidates on one line all fall
  /// inside a single box cannot appear anywhere else in that box.
  bool _boxLineReduction(_Board board) {
    for (final List<List<int>> lines in <List<List<int>>>[_rows, _columns]) {
      for (final List<int> line in lines) {
        for (int digit = 1; digit <= _size; digit++) {
          final int bit = 1 << (digit - 1);
          final List<int> places = <int>[
            for (final int index in line)
              if ((board.candidates[index] & bit) != 0) index,
          ];
          if (places.length < 2) {
            continue;
          }
          final int box = spec.boxOf(places.first);
          if (!places.every((int index) => spec.boxOf(index) == box)) {
            continue;
          }
          final Set<int> onLine = places.toSet();
          bool changed = false;
          for (final int index in _boxes[box]) {
            if (onLine.contains(index)) {
              continue;
            }
            changed |= board.eliminate(index, bit);
          }
          if (changed) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// X-wing ([size] 2) and swordfish ([size] 3): a digit confined to the same
  /// [size] columns across [size] rows must occupy those intersections, so it
  /// leaves the rest of those columns — and the transpose.
  bool _fish(_Board board, int size) {
    for (final bool byRow in <bool>[true, false]) {
      final List<List<int>> lines = byRow ? _rows : _columns;
      for (int digit = 1; digit <= _size; digit++) {
        final int bit = 1 << (digit - 1);
        final List<int> usable = <int>[];
        final List<int> crossMasks = <int>[];
        for (int line = 0; line < lines.length; line++) {
          int mask = 0;
          int seen = 0;
          for (final int index in lines[line]) {
            if ((board.candidates[index] & bit) != 0) {
              mask |= 1 << (byRow ? spec.columnOf(index) : spec.rowOf(index));
              seen++;
            }
          }
          if (seen >= 2 && seen <= size) {
            usable.add(line);
            crossMasks.add(mask);
          }
        }
        if (usable.length < size) {
          continue;
        }
        for (final List<int> group in _combinations(usable.length, size)) {
          int cover = 0;
          for (final int slot in group) {
            cover |= crossMasks[slot];
          }
          if (_bitCount(cover) != size) {
            continue;
          }
          final Set<int> rowsUsed = <int>{
            for (final int slot in group) usable[slot],
          };
          bool changed = false;
          for (int cross = 0; cross < _size; cross++) {
            if ((cover & (1 << cross)) == 0) {
              continue;
            }
            for (final int index in byRow ? _columns[cross] : _rows[cross]) {
              final int line = byRow ? spec.rowOf(index) : spec.columnOf(index);
              if (rowsUsed.contains(line)) {
                continue;
              }
              changed |= board.eliminate(index, bit);
            }
          }
          if (changed) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// A pivot holding `{x, y}` with one wing holding `{x, z}` and another
  /// holding `{y, z}`: whichever way the pivot falls, one wing becomes `z`, so
  /// nothing both wings can see may be `z`.
  bool _xyWing(_Board board) {
    final List<int> pairs = <int>[
      for (int index = 0; index < _cellCount; index++)
        if (board.cells[index] == 0 && _bitCount(board.candidates[index]) == 2)
          index,
    ];
    for (final int pivot in pairs) {
      final int pivotMask = board.candidates[pivot];
      final List<int> wings = <int>[
        for (final int index in pairs)
          if (index != pivot &&
              _peers[pivot].contains(index) &&
              _bitCount(board.candidates[index] & pivotMask) == 1)
            index,
      ];
      for (int a = 0; a < wings.length; a++) {
        for (int b = a + 1; b < wings.length; b++) {
          final int first = board.candidates[wings[a]];
          final int second = board.candidates[wings[b]];
          // The wings must take different candidates from the pivot, and share
          // the one digit that is not the pivot's.
          if ((first & pivotMask) == (second & pivotMask)) {
            continue;
          }
          final int shared = first & second & ~pivotMask & _allDigits;
          if (_bitCount(shared) != 1) {
            continue;
          }
          bool changed = false;
          for (final int index in _peers[wings[a]]) {
            if (index == pivot ||
                index == wings[b] ||
                board.cells[index] != 0 ||
                !_peers[wings[b]].contains(index)) {
              continue;
            }
            changed |= board.eliminate(index, shared);
          }
          if (changed) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// Follows the either-or chains one digit forms and looks for the two ways a
  /// chain can contradict itself: one colour appearing twice in a unit, or an
  /// outside cell that can see both colours.
  bool _simpleColouring(_Board board) {
    for (int digit = 1; digit <= _size; digit++) {
      final int bit = 1 << (digit - 1);

      // A strong link is a unit where the digit has exactly two homes left: one
      // of them is true, so the two are opposites.
      final Map<int, List<int>> links = <int, List<int>>{};
      for (final List<int> unit in _units) {
        final List<int> places = <int>[
          for (final int index in unit)
            if ((board.candidates[index] & bit) != 0) index,
        ];
        if (places.length != 2) {
          continue;
        }
        links.putIfAbsent(places[0], () => <int>[]).add(places[1]);
        links.putIfAbsent(places[1], () => <int>[]).add(places[0]);
      }

      final Map<int, int> colour = <int, int>{};
      for (final int start in links.keys) {
        if (colour.containsKey(start)) {
          continue;
        }
        final List<int> chain = <int>[start];
        final List<int> queue = <int>[start];
        colour[start] = 0;
        while (queue.isNotEmpty) {
          final int current = queue.removeLast();
          for (final int next in links[current]!) {
            if (colour.containsKey(next)) {
              continue;
            }
            colour[next] = 1 - colour[current]!;
            chain.add(next);
            queue.add(next);
          }
        }
        if (chain.length < 4) {
          continue;
        }

        final List<int> sides = <int>[
          for (final int index in chain)
            if (colour[index] == 0) index,
        ];
        final List<int> others = <int>[
          for (final int index in chain)
            if (colour[index] == 1) index,
        ];

        // Twice in one unit: that colour cannot be the true one.
        for (final List<int> side in <List<int>>[sides, others]) {
          if (!_shareAUnit(side)) {
            continue;
          }
          bool changed = false;
          for (final int index in side) {
            changed |= board.eliminate(index, bit);
          }
          if (changed) {
            return true;
          }
        }

        // Seeing both colours: whichever colour is true, this cell loses.
        bool changed = false;
        final Set<int> chainCells = chain.toSet();
        for (int index = 0; index < _cellCount; index++) {
          if (chainCells.contains(index) ||
              (board.candidates[index] & bit) == 0) {
            continue;
          }
          final bool seesOne = sides.any(
            (int cell) => _peers[index].contains(cell),
          );
          final bool seesOther = others.any(
            (int cell) => _peers[index].contains(cell),
          );
          if (seesOne && seesOther) {
            changed |= board.eliminate(index, bit);
          }
        }
        if (changed) {
          return true;
        }
      }
    }
    return false;
  }

  bool _shareAUnit(List<int> cells) {
    for (int a = 0; a < cells.length; a++) {
      for (int b = a + 1; b < cells.length; b++) {
        if (_peers[cells[a]].contains(cells[b])) {
          return true;
        }
      }
    }
    return false;
  }

  /// Every way of choosing [take] of [count] slots, as slot indices.
  static List<List<int>> _combinations(int count, int take) {
    final List<List<int>> out = <List<int>>[];
    final List<int> current = List<int>.filled(take, 0);
    void walk(int start, int depth) {
      if (depth == take) {
        out.add(List<int>.of(current));
        return;
      }
      for (int i = start; i < count; i++) {
        current[depth] = i;
        walk(i + 1, depth + 1);
      }
    }

    walk(0, 0);
    return out;
  }

  static int _bitCount(int mask) {
    int count = 0;
    int value = mask;
    while (value != 0) {
      value &= value - 1;
      count++;
    }
    return count;
  }

  static int _lowestDigit(int mask) {
    int digit = 1;
    int value = mask;
    while ((value & 1) == 0) {
      value >>= 1;
      digit++;
    }
    return digit;
  }
}

/// The mutable board one solve runs against: the digits, and what is still
/// possible in each empty cell.
class _Board {
  _Board(this._solver, List<int> givens)
    : cells = List<int>.of(givens),
      candidates = List<int>.filled(givens.length, 0) {
    for (int index = 0; index < cells.length; index++) {
      if (cells[index] == 0) {
        candidates[index] = _solver._allDigits;
      }
    }
    for (int index = 0; index < cells.length; index++) {
      final int digit = cells[index];
      if (digit == 0) {
        continue;
      }
      if (digit < 1 || digit > _solver._size) {
        isBroken = true;
        return;
      }
      final int bit = 1 << (digit - 1);
      for (final int peer in _solver._peers[index]) {
        if (cells[peer] == digit) {
          isBroken = true;
          return;
        }
        candidates[peer] &= ~bit;
      }
    }
    _empty = cells.where((int digit) => digit == 0).length;
    for (int index = 0; index < cells.length; index++) {
      if (cells[index] == 0 && candidates[index] == 0) {
        isBroken = true;
        return;
      }
    }
  }

  final SudokuLogicSolver _solver;
  final List<int> cells;
  final List<int> candidates;

  /// Whether the grid contradicts itself. Only ever true for a board that was
  /// already impossible: the solver's own moves cannot create one.
  bool isBroken = false;

  int _empty = 0;

  bool get isComplete => _empty == 0;

  /// The cell the last technique filled, or `null` if it only eliminated.
  ///
  /// Cleared by the caller between rungs, which is how [placements] tells a
  /// deduction that placed a digit from one that merely narrowed the board.
  int? lastPlaced;

  /// Writes [digit] into [index] and takes it away from everything that cell
  /// can see.
  void place(int index, int digit) {
    lastPlaced = index;
    cells[index] = digit;
    candidates[index] = 0;
    _empty--;
    final int bit = 1 << (digit - 1);
    for (final int peer in _solver._peers[index]) {
      if (cells[peer] == 0 && (candidates[peer] & bit) != 0) {
        candidates[peer] &= ~bit;
        if (candidates[peer] == 0) {
          isBroken = true;
        }
      }
    }
  }

  /// Rules the digits in [mask] out of [index]. Returns whether that changed
  /// anything, which is how a technique tells "this applies" from "this applies
  /// but tells us nothing new".
  bool eliminate(int index, int mask) {
    if (cells[index] != 0) {
      return false;
    }
    final int remaining = candidates[index] & ~mask;
    if (remaining == candidates[index]) {
      return false;
    }
    candidates[index] = remaining;
    if (remaining == 0) {
      isBroken = true;
    }
    return true;
  }
}
