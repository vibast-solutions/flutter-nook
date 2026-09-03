import 'package:meta/meta.dart';

import 'spec.dart';
import 'technique.dart';

/// What one run of [DuoLogicSolver] found.
///
/// A run that stops short is not an error. "This puzzle cannot be finished by
/// reasoning a person could do" is the single most useful thing the engine can
/// say about a Duo puzzle, because it is what keeps such a puzzle from ever
/// reaching a player.
class DuoSolveReport {
  DuoSolveReport({
    required this.isSolved,
    required List<DuoSymbol?> cells,
    required Map<DuoTechnique, int> steps,
  }) : cells = List<DuoSymbol?>.unmodifiable(cells),
       steps = Map<DuoTechnique, int>.unmodifiable(steps);

  /// Whether every cell was filled by reasoning alone.
  final bool isSolved;

  /// What the solver worked out, cell by cell: the symbol it deduced, or `null`
  /// where reasoning ran out. Every filled cell was deduced, never guessed, so
  /// a partial result is still a correct one.
  final List<DuoSymbol?> cells;

  /// How many times each technique was the one that broke the deadlock.
  final Map<DuoTechnique, int> steps;

  /// The hardest technique the puzzle actually required, or `null` if it needed
  /// none (a board that was already complete).
  DuoTechnique? get hardest {
    DuoTechnique? hardest;
    for (final DuoTechnique technique in steps.keys) {
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
    steps.forEach((DuoTechnique technique, int count) {
      if (technique.tier == tier) {
        total += count;
      }
    });
    return total;
  }

  /// How many times [technique] was needed.
  int countTechnique(DuoTechnique technique) => steps[technique] ?? 0;

  @override
  String toString() =>
      'DuoSolveReport(${isSolved ? 'solved' : 'stalled'}, '
      'hardest ${hardest?.name ?? 'none'})';
}

/// One symbol a solver worked out, and the reasoning that justified it.
///
/// The unit a hint (VIB-97) is made of: where the symbol goes and which rung of
/// the ladder produced it. In the same shape as `StarsPlacement`.
@immutable
class DuoPlacement {
  const DuoPlacement({
    required this.index,
    required this.symbol,
    required this.technique,
  });

  /// The cell the symbol belongs in.
  final int index;

  /// The symbol the deduction placed.
  final DuoSymbol symbol;

  /// The deduction that placed it.
  final DuoTechnique technique;

  @override
  bool operator ==(Object other) =>
      other is DuoPlacement &&
      other.index == index &&
      other.symbol == symbol &&
      other.technique == technique;

  @override
  int get hashCode => Object.hash(index, symbol, technique);

  @override
  String toString() =>
      'DuoPlacement($index, ${symbol.name}, ${technique.name})';
}

/// Solves a Duo puzzle using only deductions a person could make.
///
/// The opposite of [DuoSolver], and both are deliberate: that one searches,
/// backtracks and answers "how many completions?"; this one never guesses,
/// never backtracks and never fills a cell it cannot justify — which is why its
/// verdict can be trusted as a measure of how hard a puzzle is for a human, and
/// why a puzzle it cannot finish is thrown away rather than sold to a player.
///
/// The whole ladder, easiest first (see [DuoTechnique]):
///
/// * **simple** — [DuoTechnique.badge], [DuoTechnique.noTriple] (two alike sit
///   next to a cell) and [DuoTechnique.lineFull] (a line already has all of one
///   symbol). Each read straight off a badge, a pair or a full count.
/// * **intermediate** — [DuoTechnique.sandwich]: two alike one cell apart force
///   the gap to the other symbol.
/// * **advanced** — [DuoTechnique.lineReading]: a cell that comes out the same
///   symbol in every way a whole line could still be completed.
///
/// A puzzle this solver cannot finish rates as unsolvable, which is a rejection:
/// the rater ([DuoRater]) turns it into `null`, and the generator restores
/// givens rather than offering a puzzle that would need a guess. There is no
/// rung above the advanced one, so a puzzle past it is discarded, never promoted.
class DuoLogicSolver {
  DuoLogicSolver(this.spec) {
    spec.validate();
  }

  /// The grid shape being solved.
  final DuoSpec spec;

  /// Solves [givens] and [badges] as far as pure deduction reaches.
  DuoSolveReport solve(List<DuoSymbol?> givens, List<DuoBadge> badges) {
    final _Board board = _Board(spec, givens, badges);
    final Map<DuoTechnique, int> steps = <DuoTechnique, int>{};

    while (!board.isComplete) {
      final DuoTechnique? applied = _applyEasiest(board);
      if (applied == null || board.isBroken) {
        break;
      }
      steps.update(applied, (int count) => count + 1, ifAbsent: () => 1);
    }

    return DuoSolveReport(
      isSolved: board.isComplete && !board.isBroken,
      cells: board.cells,
      steps: steps,
    );
  }

  /// The symbols the solver can work out from [givens] and [badges], in the
  /// order a person would reach them.
  ///
  /// The entry point a hint (VIB-97) is built on, in the shape
  /// `StarsLogicSolver.placements` has. Lazy: it stops where reasoning does — at
  /// a full board, at a contradiction, or at a puzzle this solver cannot finish.
  Iterable<DuoPlacement> placements(
    List<DuoSymbol?> givens,
    List<DuoBadge> badges,
  ) sync* {
    final _Board board = _Board(spec, givens, badges);
    if (board.isBroken) {
      return;
    }
    while (!board.isComplete) {
      board.placedThisStep.clear();
      final DuoTechnique? applied = _applyEasiest(board);
      if (applied == null || board.isBroken) {
        return;
      }
      for (final int cell in board.placedThisStep) {
        yield DuoPlacement(
          index: cell,
          symbol: board.symbolAt(cell)!,
          technique: applied,
        );
      }
    }
  }

  /// Runs the ladder from the bottom and returns the first rung that filled a
  /// cell, so a puzzle is only charged for the easiest thing that worked.
  DuoTechnique? _applyEasiest(_Board board) {
    for (final DuoTechnique technique in DuoTechnique.values) {
      if (_apply(technique, board)) {
        return technique;
      }
    }
    return null;
  }

  bool _apply(DuoTechnique technique, _Board board) {
    switch (technique) {
      case DuoTechnique.badge:
        return _badge(board);
      case DuoTechnique.noTriple:
        return _noTriple(board);
      case DuoTechnique.lineFull:
        return _lineFull(board);
      case DuoTechnique.sandwich:
        return _sandwich(board);
      case DuoTechnique.lineReading:
        return _lineReading(board);
    }
  }

  /// A cell across a badge from a filled one takes the symbol the badge dictates.
  bool _badge(_Board board) {
    for (final DuoBadge badge in board.badges) {
      final DuoSymbol? near = board.symbolAt(badge.a);
      final DuoSymbol? far = board.symbolAt(badge.b);
      if (near != null && far == null) {
        board.place(badge.b, badge.relation.from(near));
        return true;
      }
      if (far != null && near == null) {
        board.place(badge.a, badge.relation.from(far));
        return true;
      }
    }
    return false;
  }

  /// A cell with a run of alike cells ending right beside it is forced the other
  /// way — the two-in-a-row read straight off the adjacent cells.
  bool _noTriple(_Board board) {
    for (int index = 0; index < spec.cellCount; index++) {
      if (!board.isEmpty(index)) {
        continue;
      }
      final bool circleBanned = board.adjacentRunBans(index, DuoSymbol.circle);
      final bool squareBanned = board.adjacentRunBans(index, DuoSymbol.square);
      if (circleBanned && squareBanned) {
        board.isBroken = true;
        return false;
      }
      if (circleBanned) {
        board.place(index, DuoSymbol.square);
        return true;
      }
      if (squareBanned) {
        board.place(index, DuoSymbol.circle);
        return true;
      }
    }
    return false;
  }

  /// A row or column that already holds all of one symbol fills a remaining
  /// cell with the other.
  bool _lineFull(_Board board) {
    for (int line = 0; line < spec.size; line++) {
      for (final bool byRow in const <bool>[true, false]) {
        for (int symbol = 0; symbol < 2; symbol++) {
          if (board.countInLine(line, byRow, symbol) != spec.perSymbol) {
            continue;
          }
          final DuoSymbol other = DuoSymbol.values[symbol].other;
          for (final int cell in board.lineCells(line, byRow)) {
            if (board.isEmpty(cell)) {
              board.place(cell, other);
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// A cell with a matching symbol one step away on each side: filling it alike
  /// would make three across the gap, so it is the other symbol.
  bool _sandwich(_Board board) {
    for (int index = 0; index < spec.cellCount; index++) {
      if (!board.isEmpty(index)) {
        continue;
      }
      final bool circleBanned = board.spanningRunBans(index, DuoSymbol.circle);
      final bool squareBanned = board.spanningRunBans(index, DuoSymbol.square);
      if (circleBanned && squareBanned) {
        board.isBroken = true;
        return false;
      }
      if (circleBanned) {
        board.place(index, DuoSymbol.square);
        return true;
      }
      if (squareBanned) {
        board.place(index, DuoSymbol.circle);
        return true;
      }
    }
    return false;
  }

  /// A cell that is the same symbol in every legal completion of a line.
  ///
  /// Each row and column is completed in every way the balance rule, the run
  /// rule, its own badges and the filled crossing cells allow; a cell that comes
  /// out the same in all of them is forced. Sound because the true answer is one
  /// of those completions, so a cell they all agree on cannot be anything else.
  bool _lineReading(_Board board) {
    for (int line = 0; line < spec.size; line++) {
      for (final bool byRow in const <bool>[true, false]) {
        final _Forced? forced = board.readLine(line, byRow);
        if (forced == null) {
          continue;
        }
        if (forced.broken) {
          board.isBroken = true;
          return false;
        }
        if (forced.cells.isEmpty) {
          continue;
        }
        forced.cells.forEach((int cell, DuoSymbol symbol) {
          board.place(cell, symbol);
        });
        return true;
      }
    }
    return false;
  }
}

/// What [_Board.readLine] agreed on: the cells forced, or that the line has no
/// legal completion at all.
class _Forced {
  _Forced(this.cells, {this.broken = false});

  final Map<int, DuoSymbol> cells;
  final bool broken;
}

/// The mutable board one solve runs against.
class _Board {
  _Board(this.spec, List<DuoSymbol?> givens, this.badges)
    : _grid = <int>[
        for (final DuoSymbol? symbol in givens)
          symbol == null ? _empty : symbol.index,
      ],
      _rowCount = List<int>.filled(spec.size * 2, 0),
      _columnCount = List<int>.filled(spec.size * 2, 0) {
    if (givens.length != spec.cellCount) {
      throw ArgumentError(
        'Expected ${spec.cellCount} given entries, got ${givens.length}.',
      );
    }
    for (int index = 0; index < spec.cellCount; index++) {
      final int value = _grid[index];
      if (value != _empty) {
        _placed++;
        _rowCount[spec.rowOf(index) * 2 + value]++;
        _columnCount[spec.columnOf(index) * 2 + value]++;
      }
    }
  }

  static const int _empty = -1;

  final DuoSpec spec;
  final List<int> _grid;
  final List<DuoBadge> badges;
  final List<int> _rowCount;
  final List<int> _columnCount;

  int _placed = 0;
  bool isBroken = false;

  /// The cells the last technique application filled.
  final List<int> placedThisStep = <int>[];

  bool get isComplete => _placed == spec.cellCount;

  bool isEmpty(int index) => _grid[index] == _empty;

  DuoSymbol? symbolAt(int index) =>
      _grid[index] == _empty ? null : DuoSymbol.values[_grid[index]];

  /// What the solver has worked out so far, `null` where it is still stuck.
  List<DuoSymbol?> get cells => <DuoSymbol?>[
    for (final int value in _grid)
      value == _empty ? null : DuoSymbol.values[value],
  ];

  void place(int index, DuoSymbol symbol) {
    if (_grid[index] != _empty) {
      return;
    }
    _grid[index] = symbol.index;
    _placed++;
    placedThisStep.add(index);
    _rowCount[spec.rowOf(index) * 2 + symbol.index]++;
    _columnCount[spec.columnOf(index) * 2 + symbol.index]++;
  }

  /// How many of [symbol] the [byRow] line numbered [line] holds.
  int countInLine(int line, bool byRow, int symbol) =>
      (byRow ? _rowCount : _columnCount)[line * 2 + symbol];

  /// The cells of the [byRow] line numbered [line], in order.
  List<int> lineCells(int line, bool byRow) => <int>[
    for (int i = 0; i < spec.size; i++)
      byRow ? spec.indexOf(line, i) : spec.indexOf(i, line),
  ];

  /// Whether putting [symbol] in the empty cell at [index] would make a run
  /// longer than [DuoSpec.runLimit] in its row or its column.
  bool wouldOverrun(int index, DuoSymbol symbol) {
    final int horizontal =
        1 + _run(index, symbol, 0, -1) + _run(index, symbol, 0, 1);
    if (horizontal > spec.runLimit) {
      return true;
    }
    final int vertical =
        1 + _run(index, symbol, -1, 0) + _run(index, symbol, 1, 0);
    return vertical > spec.runLimit;
  }

  /// Whether [symbol] at [index] would overrun because a run of
  /// [DuoSpec.runLimit] alike ends right beside it — the adjacent, simple case.
  bool adjacentRunBans(int index, DuoSymbol symbol) =>
      _run(index, symbol, 0, -1) >= spec.runLimit ||
      _run(index, symbol, 0, 1) >= spec.runLimit ||
      _run(index, symbol, -1, 0) >= spec.runLimit ||
      _run(index, symbol, 1, 0) >= spec.runLimit;

  /// Whether [symbol] at [index] would overrun only by bridging alike cells on
  /// both sides — the gap, intermediate case, and never the adjacent one.
  bool spanningRunBans(int index, DuoSymbol symbol) =>
      wouldOverrun(index, symbol) && !adjacentRunBans(index, symbol);

  /// The cells the line running [byRow] through [line] is forced into, taken
  /// over every legal completion of it, or `null` when the line is already full.
  ///
  /// A completion is legal when it balances the line, keeps every run within the
  /// limit, honours the badges inside the line, and — against the filled cells of
  /// the crossing lines only — neither overfills a crossing line nor breaks a
  /// crossing badge. Only cells the completions all agree on are returned.
  _Forced? readLine(int line, bool byRow) {
    final List<int> cells = lineCells(line, byRow);
    final List<int> empties = <int>[
      for (final int cell in cells)
        if (isEmpty(cell)) cell,
    ];
    if (empties.isEmpty) {
      return null;
    }

    // Symbols still owed to the line, and the badges that live wholly inside it.
    final List<int> need = <int>[
      for (int symbol = 0; symbol < 2; symbol++)
        spec.perSymbol - countInLine(line, byRow, symbol),
    ];
    final Set<int> lineCellSet = cells.toSet();
    final List<DuoBadge> inside = <DuoBadge>[
      for (final DuoBadge badge in badges)
        if (lineCellSet.contains(badge.a) && lineCellSet.contains(badge.b))
          badge,
    ];

    // For each empty slot: -1 not yet seen, -2 seen disagreeing (so not forced),
    // otherwise the one symbol every legal completion so far has put there. The
    // bit set in a mask means square; unset means circle.
    final int slots = empties.length;
    final List<int> seen = List<int>.filled(slots, -1);
    bool any = false;

    for (int mask = 0; mask < (1 << slots); mask++) {
      // Balance first: the completion must place exactly what the line owes.
      int placedCircle = 0;
      for (int i = 0; i < slots; i++) {
        if (((mask >> i) & 1) == 0) {
          placedCircle++;
        }
      }
      if (placedCircle != need[DuoSymbol.circle.index]) {
        continue;
      }

      if (!_completionLegal(mask, empties, cells, inside, byRow)) {
        continue;
      }

      any = true;
      for (int i = 0; i < slots; i++) {
        final int symbol = ((mask >> i) & 1) == 0
            ? DuoSymbol.circle.index
            : DuoSymbol.square.index;
        if (seen[i] == -1) {
          seen[i] = symbol;
        } else if (seen[i] != symbol) {
          seen[i] = -2; // Disagreement: this cell is not forced.
        }
      }
    }

    if (!any) {
      return _Forced(<int, DuoSymbol>{}, broken: true);
    }
    final Map<int, DuoSymbol> forced = <int, DuoSymbol>{};
    for (int i = 0; i < slots; i++) {
      if (seen[i] >= 0) {
        forced[empties[i]] = DuoSymbol.values[seen[i]];
      }
    }
    return _Forced(forced);
  }

  /// Whether the assignment [mask] to [empties] completes [cells] legally:
  /// runs within the line stay under the limit, the line's own [inside] badges
  /// hold, and each filled cell agrees with the crossing lines' filled cells.
  bool _completionLegal(
    int mask,
    List<int> empties,
    List<int> cells,
    List<DuoBadge> inside,
    bool byRow,
  ) {
    // The line's symbols with the assignment applied, in line order.
    final Map<int, int> assigned = <int, int>{};
    for (int i = 0; i < empties.length; i++) {
      assigned[empties[i]] = ((mask >> i) & 1) == 0
          ? DuoSymbol.circle.index
          : DuoSymbol.square.index;
    }
    int symbolOf(int cell) => assigned[cell] ?? _grid[cell];

    // No run past the limit along the line.
    int run = 1;
    for (int i = 1; i < cells.length; i++) {
      if (symbolOf(cells[i]) == symbolOf(cells[i - 1])) {
        run++;
        if (run > spec.runLimit) {
          return false;
        }
      } else {
        run = 1;
      }
    }

    // Every badge inside the line is satisfied.
    for (final DuoBadge badge in inside) {
      if (!badge.relation.holds(
        DuoSymbol.values[symbolOf(badge.a)],
        DuoSymbol.values[symbolOf(badge.b)],
      )) {
        return false;
      }
    }

    // Each newly filled cell against the crossing line's filled cells only.
    for (final int cell in empties) {
      final int symbol = assigned[cell]!;
      final int crossLine = byRow ? spec.columnOf(cell) : spec.rowOf(cell);
      if (countInLine(crossLine, !byRow, symbol) >= spec.perSymbol) {
        return false;
      }
      if (_crossRunBanned(cell, symbol, byRow)) {
        return false;
      }
      for (final DuoBadge badge in _crossBadgesAt(cell, byRow)) {
        final int other = badge.a == cell ? badge.b : badge.a;
        if (isEmpty(other)) {
          continue;
        }
        if (!badge.relation.holds(
          DuoSymbol.values[symbol],
          DuoSymbol.values[_grid[other]],
        )) {
          return false;
        }
      }
    }
    return true;
  }

  /// Whether [symbol] at [cell] would overrun the crossing line — the vertical
  /// run for a row, the horizontal run for a column — against filled cells.
  bool _crossRunBanned(int cell, int symbol, bool byRow) {
    final DuoSymbol value = DuoSymbol.values[symbol];
    if (byRow) {
      final int run = 1 + _run(cell, value, -1, 0) + _run(cell, value, 1, 0);
      return run > spec.runLimit;
    }
    final int run = 1 + _run(cell, value, 0, -1) + _run(cell, value, 0, 1);
    return run > spec.runLimit;
  }

  /// The badges joining [cell] to a cell on its crossing line.
  Iterable<DuoBadge> _crossBadgesAt(int cell, bool byRow) sync* {
    for (final DuoBadge badge in badges) {
      if (badge.a != cell && badge.b != cell) {
        continue;
      }
      // A crossing badge for a row is a vertical one, and the reverse.
      if (badge.isHorizontal != byRow) {
        yield badge;
      }
    }
  }

  /// How many filled cells equal to [symbol] run from [index] in the direction
  /// `(dRow, dColumn)`, not counting [index] itself.
  int _run(int index, DuoSymbol symbol, int dRow, int dColumn) {
    int run = 0;
    int row = spec.rowOf(index) + dRow;
    int column = spec.columnOf(index) + dColumn;
    while (row >= 0 &&
        row < spec.size &&
        column >= 0 &&
        column < spec.size &&
        _grid[spec.indexOf(row, column)] == symbol.index) {
      run++;
      row += dRow;
      column += dColumn;
    }
    return run;
  }
}
