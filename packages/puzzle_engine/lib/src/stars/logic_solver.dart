import 'package:meta/meta.dart';

import 'spec.dart';
import 'technique.dart';

/// What one run of [StarsLogicSolver] found.
///
/// A run that stops short is not an error. "This region map cannot be finished
/// by reasoning a person could do" is the single most useful thing the engine
/// can say about a Stars puzzle, because it is what keeps such a puzzle from
/// ever reaching a player.
class StarsSolveReport {
  StarsSolveReport({
    required this.isSolved,
    required List<int> stars,
    required Map<StarsTechnique, int> steps,
  }) : stars = List<int>.unmodifiable(stars),
       steps = Map<StarsTechnique, int>.unmodifiable(steps);

  /// Whether every star was placed by reasoning alone.
  final bool isSolved;

  /// The star cells the solver worked out, sorted. Every one of them was
  /// deduced, never guessed, so a partial result is still a correct one.
  final List<int> stars;

  /// How many times each technique was the one that broke the deadlock.
  final Map<StarsTechnique, int> steps;

  /// The hardest technique the puzzle actually required, or `null` if it
  /// needed none (a board that fell out with no deduction at all).
  StarsTechnique? get hardest {
    StarsTechnique? hardest;
    for (final StarsTechnique technique in steps.keys) {
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
    steps.forEach((StarsTechnique technique, int count) {
      if (technique.tier == tier) {
        total += count;
      }
    });
    return total;
  }

  /// How many times [technique] was needed.
  int countTechnique(StarsTechnique technique) => steps[technique] ?? 0;

  @override
  String toString() =>
      'StarsSolveReport(${isSolved ? 'solved' : 'stalled'}, '
      'hardest ${hardest?.name ?? 'none'})';
}

/// One star a solver worked out, and the reasoning that justified it.
///
/// The unit a hint (VIB-90) is made of: where the star goes and which rung of
/// the ladder produced it. In the same shape as `SudokuPlacement`.
@immutable
class StarsPlacement {
  const StarsPlacement({required this.index, required this.technique});

  /// The cell the star belongs in.
  final int index;

  /// The deduction that put it there.
  final StarsTechnique technique;

  @override
  bool operator ==(Object other) =>
      other is StarsPlacement &&
      other.index == index &&
      other.technique == technique;

  @override
  int get hashCode => Object.hash(index, technique);

  @override
  String toString() => 'StarsPlacement($index, ${technique.name})';
}

/// Solves a Stars puzzle using only deductions a person could make.
///
/// The opposite of `StarsSolver`, and both are deliberate: that one searches,
/// backtracks and answers "how many placements?"; this one never guesses,
/// never backtracks and never places a star it cannot justify — which is why
/// its verdict can be trusted as a measure of how hard a puzzle is for a human,
/// and why a puzzle it cannot finish is thrown away rather than sold to a
/// player.
///
/// The ladder, easiest first:
///
/// * **simple** — a region, row or column already down to as many open cells
///   as it has stars left, so each of them is a star. Placing a star rules out
///   the cells that touch it and, once a unit is full, the rest of that unit.
/// * **intermediate** — a region whose open cells all lie on one line hands
///   that line to the region (and the reverse).
/// * **advanced** — set counting: N regions confined to N rows take those rows
///   between them (and the same on columns).
///
/// A puzzle that needs something past the advanced rung is left unsolved, which
/// is a rejection: the rater ([StarsRater]) turns it into `null`, and the
/// generator throws it away rather than offering it as a harder tier.
class StarsLogicSolver {
  StarsLogicSolver(this.spec) {
    spec.validate();
  }

  /// The grid shape being solved.
  final StarsSpec spec;

  /// Solves [regions] as far as pure deduction reaches.
  StarsSolveReport solve(List<int> regions) {
    _check(regions);
    final _Board board = _Board(spec, regions);
    final Map<StarsTechnique, int> steps = <StarsTechnique, int>{};

    while (!board.isComplete) {
      final StarsTechnique? applied = _applyEasiest(board);
      if (applied == null || board.isBroken) {
        break;
      }
      steps.update(applied, (int count) => count + 1, ifAbsent: () => 1);
    }

    return StarsSolveReport(
      isSolved: board.isComplete && !board.isBroken,
      stars: board.stars,
      steps: steps,
    );
  }

  /// The stars the solver can work out from [regions], in the order a person
  /// would reach them.
  ///
  /// The entry point a hint (VIB-90) is built on, in the shape
  /// `SudokuLogicSolver.placements` has. Lazy: it stops where reasoning does —
  /// at a full board, at a contradiction, or at a puzzle this solver cannot
  /// finish. Only the simple rungs place a star; the harder ones only rule
  /// cells out, so a placement is always tagged with the single that made it.
  Iterable<StarsPlacement> placements(List<int> regions) sync* {
    _check(regions);
    final _Board board = _Board(spec, regions);
    if (board.isBroken) {
      return;
    }
    while (!board.isComplete) {
      board.placedThisStep.clear();
      final StarsTechnique? applied = _applyEasiest(board);
      if (applied == null || board.isBroken) {
        return;
      }
      for (final int cell in board.placedThisStep) {
        yield StarsPlacement(index: cell, technique: applied);
      }
    }
  }

  void _check(List<int> regions) {
    if (regions.length != spec.cellCount) {
      throw ArgumentError(
        'Expected ${spec.cellCount} region entries, got ${regions.length}.',
      );
    }
  }

  /// Runs the ladder from the bottom and returns the first rung that moved the
  /// board, so a puzzle is only charged for the easiest thing that worked.
  StarsTechnique? _applyEasiest(_Board board) {
    for (final StarsTechnique technique in StarsTechnique.values) {
      if (_apply(technique, board)) {
        return technique;
      }
    }
    return null;
  }

  bool _apply(StarsTechnique technique, _Board board) {
    switch (technique) {
      case StarsTechnique.regionSingle:
        return _single(board, board.regionUnits);
      case StarsTechnique.lineSingle:
        return _single(board, board.lineUnits);
      case StarsTechnique.regionConfinedToLine:
        return _regionConfinedToLine(board);
      case StarsTechnique.lineConfinedToRegion:
        return _lineConfinedToRegion(board);
      case StarsTechnique.regionSetCover:
        return _setCover(board);
    }
  }

  /// A unit in [units] with exactly as many open cells as stars still to place:
  /// every one of them is a star.
  bool _single(_Board board, List<int> units) {
    for (final int unit in units) {
      final int needed = spec.starsPerUnit - board.starsIn[unit];
      if (needed <= 0 || board.openIn[unit] != needed) {
        continue;
      }
      for (final int cell in board.cellsOf(unit)) {
        if (board.isOpen(cell)) {
          board.placeStar(cell);
        }
      }
      return true;
    }
    return false;
  }

  /// A region whose open cells all fall on one line rules the rest of that
  /// line out; and the mirror handled by [_lineConfinedToRegion].
  bool _regionConfinedToLine(_Board board) {
    for (final int unit in board.regionUnits) {
      if (spec.starsPerUnit - board.starsIn[unit] <= 0) {
        continue;
      }
      final List<int> open = board.openCells(unit);
      if (open.length < 2) {
        continue;
      }
      for (final bool byRow in const <bool>[true, false]) {
        final int line = byRow
            ? spec.rowOf(open.first)
            : spec.columnOf(open.first);
        final bool aligned = open.every(
          (int cell) =>
              (byRow ? spec.rowOf(cell) : spec.columnOf(cell)) == line,
        );
        if (!aligned) {
          continue;
        }
        final List<int> lineCells = byRow
            ? board.rowCells(line)
            : board.columnCells(line);
        bool changed = false;
        for (final int cell in lineCells) {
          if (board.regionOf(cell) != board.regionOf(open.first) &&
              board.isOpen(cell)) {
            board.exclude(cell);
            changed = true;
          }
        }
        if (changed) {
          return true;
        }
      }
    }
    return false;
  }

  /// A row or column whose open cells all lie inside one region rules the rest
  /// of that region out.
  bool _lineConfinedToRegion(_Board board) {
    for (final int unit in board.lineUnits) {
      if (spec.starsPerUnit - board.starsIn[unit] <= 0) {
        continue;
      }
      final List<int> open = board.openCells(unit);
      if (open.length < 2) {
        continue;
      }
      final int region = board.regionOf(open.first);
      if (!open.every((int cell) => board.regionOf(cell) == region)) {
        continue;
      }
      bool changed = false;
      for (final int cell in board.cellsOf(board.regionUnits[region])) {
        if (board.isOpen(cell) && !open.contains(cell)) {
          board.exclude(cell);
          changed = true;
        }
      }
      if (changed) {
        return true;
      }
    }
    return false;
  }

  /// N regions whose open cells lie wholly within N rows (or N columns) take
  /// those lines between them, so every cell on those lines that belongs to
  /// another region is ruled out.
  bool _setCover(_Board board) {
    for (final bool byRow in const <bool>[true, false]) {
      // Which lines each still-open region occupies, as a bitmask.
      final List<int> lineMask = <int>[];
      final List<int> regionsInPlay = <int>[];
      for (int region = 0; region < spec.regionCount; region++) {
        final int unit = board.regionUnits[region];
        if (spec.starsPerUnit - board.starsIn[unit] <= 0) {
          continue;
        }
        int mask = 0;
        for (final int cell in board.openCells(unit)) {
          mask |= 1 << (byRow ? spec.rowOf(cell) : spec.columnOf(cell));
        }
        lineMask.add(mask);
        regionsInPlay.add(region);
      }
      final int count = regionsInPlay.length;
      // Try every subset of two or more regions; a subset whose lines number
      // exactly as many as the regions is a closed set.
      for (int subset = 1; subset < (1 << count); subset++) {
        final int size = _popCount(subset);
        if (size < 2 || size >= count) {
          continue;
        }
        int union = 0;
        for (int i = 0; i < count; i++) {
          if ((subset & (1 << i)) != 0) {
            union |= lineMask[i];
          }
        }
        if (_popCount(union) != size) {
          continue;
        }
        final Set<int> claimed = <int>{
          for (int i = 0; i < count; i++)
            if ((subset & (1 << i)) != 0) regionsInPlay[i],
        };
        bool changed = false;
        for (int line = 0; line < spec.size; line++) {
          if ((union & (1 << line)) == 0) {
            continue;
          }
          final List<int> cells = byRow
              ? board.rowCells(line)
              : board.columnCells(line);
          for (final int cell in cells) {
            if (board.isOpen(cell) && !claimed.contains(board.regionOf(cell))) {
              board.exclude(cell);
              changed = true;
            }
          }
        }
        if (changed) {
          return true;
        }
      }
    }
    return false;
  }

  static int _popCount(int mask) {
    int count = 0;
    int value = mask;
    while (value != 0) {
      value &= value - 1;
      count++;
    }
    return count;
  }
}

/// Star, excluded, or still open.
const int _open = 0;
const int _star = 1;
const int _excluded = 2;

/// The mutable board one solve runs against.
class _Board {
  _Board(this.spec, List<int> regions)
    : _regions = regions,
      _marks = List<int>.filled(spec.cellCount, _open),
      _neighbours = List<List<int>>.generate(
        spec.cellCount,
        (int cell) => spec.neighbours(cell),
      ) {
    final List<List<int>> units = <List<int>>[];
    _rowStart = 0;
    for (int row = 0; row < spec.size; row++) {
      units.add(<int>[
        for (int column = 0; column < spec.size; column++)
          spec.indexOf(row, column),
      ]);
    }
    _columnStart = units.length;
    for (int column = 0; column < spec.size; column++) {
      units.add(<int>[
        for (int row = 0; row < spec.size; row++) spec.indexOf(row, column),
      ]);
    }
    _regionStart = units.length;
    final List<List<int>> byRegion = List<List<int>>.generate(
      spec.regionCount,
      (int _) => <int>[],
    );
    for (int cell = 0; cell < spec.cellCount; cell++) {
      byRegion[regions[cell]].add(cell);
    }
    units.addAll(byRegion);

    _units = units;
    starsIn = List<int>.filled(units.length, 0);
    openIn = <int>[for (final List<int> unit in units) unit.length];
    _unitsOf = List<List<int>>.generate(spec.cellCount, (int _) => <int>[]);
    for (int unit = 0; unit < units.length; unit++) {
      for (final int cell in units[unit]) {
        _unitsOf[cell].add(unit);
      }
    }
    lineUnits = <int>[for (int i = 0; i < _regionStart; i++) i];
    regionUnits = <int>[
      for (int r = 0; r < spec.regionCount; r++) _regionStart + r,
    ];
  }

  final StarsSpec spec;
  final List<int> _regions;
  final List<int> _marks;
  final List<List<int>> _neighbours;

  late final List<List<int>> _units;
  late final List<List<int>> _unitsOf;
  late final int _rowStart;
  late final int _columnStart;
  late final int _regionStart;

  /// The unit indices of the rows and columns, then of the regions.
  late final List<int> lineUnits;
  late final List<int> regionUnits;

  late final List<int> starsIn;
  late final List<int> openIn;

  int _placed = 0;
  bool isBroken = false;

  /// The cells the last technique application placed a star in.
  final List<int> placedThisStep = <int>[];

  bool get isComplete => _placed == spec.starCount;

  List<int> cellsOf(int unit) => _units[unit];

  List<int> rowCells(int row) => _units[_rowStart + row];

  List<int> columnCells(int column) => _units[_columnStart + column];

  int regionOf(int cell) => _regions[cell];

  bool isOpen(int index) => _marks[index] == _open;

  /// The still-open cells of [unit].
  List<int> openCells(int unit) => <int>[
    for (final int cell in _units[unit])
      if (isOpen(cell)) cell,
  ];

  List<int> get stars {
    final List<int> found = <int>[
      for (int cell = 0; cell < _marks.length; cell++)
        if (_marks[cell] == _star) cell,
    ];
    return found..sort();
  }

  void placeStar(int index) {
    if (_marks[index] != _open) {
      return;
    }
    _marks[index] = _star;
    _placed++;
    placedThisStep.add(index);
    for (final int unit in _unitsOf[index]) {
      starsIn[unit]++;
      openIn[unit]--;
    }
    for (final int neighbour in _neighbours[index]) {
      if (_marks[neighbour] == _open) {
        exclude(neighbour);
      }
    }
    for (final int unit in _unitsOf[index]) {
      if (starsIn[unit] == spec.starsPerUnit) {
        for (final int cell in _units[unit]) {
          if (_marks[cell] == _open) {
            exclude(cell);
          }
        }
      }
    }
  }

  void exclude(int index) {
    if (_marks[index] != _open) {
      return;
    }
    _marks[index] = _excluded;
    for (final int unit in _unitsOf[index]) {
      openIn[unit]--;
      if (openIn[unit] < spec.starsPerUnit - starsIn[unit]) {
        isBroken = true;
      }
    }
  }
}
