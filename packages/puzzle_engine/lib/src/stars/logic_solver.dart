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

/// Solves a Stars puzzle using only deductions a person could make.
///
/// The opposite of [StarsSolver], and both are deliberate: that one searches,
/// backtracks and answers "how many placements?"; this one never guesses,
/// never backtracks and never places a star it cannot justify — which is why
/// its verdict can be trusted as a measure of how hard a puzzle is for a human,
/// and why a puzzle it cannot finish is thrown away rather than sold to a
/// player.
///
/// **This story (VIB-85) carries the simple rung only** — a row, column or
/// region with exactly as many open cells as it has stars left to place, so
/// each of those cells is a star. Placing a star does the bookkeeping a person
/// does without thinking: it rules out the cells that touch it, and once a unit
/// has its full complement of stars it rules out the rest of that unit. On an
/// empty board only a region already down to its star count can start the
/// chain; from there those rule-outs cascade. The intermediate and advanced
/// rungs, and the rater that reads this report, are VIB-86.
class StarsLogicSolver {
  StarsLogicSolver(this.spec) {
    spec.validate();
  }

  /// The grid shape being solved.
  final StarsSpec spec;

  /// Solves [regions] as far as pure deduction reaches.
  ///
  /// [regions] is a flat, row-major list of region indices. A region map that
  /// already admits no legal placement comes back unsolved.
  StarsSolveReport solve(List<int> regions) {
    if (regions.length != spec.cellCount) {
      throw ArgumentError(
        'Expected ${spec.cellCount} region entries, got ${regions.length}.',
      );
    }
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
      case StarsTechnique.soleCandidate:
        return _soleCandidate(board);
    }
  }

  /// A unit with exactly as many open cells as stars still to place: every one
  /// of them is a star.
  bool _soleCandidate(_Board board) {
    for (int unit = 0; unit < board.unitCount; unit++) {
      final int needed = spec.starsPerUnit - board.starsIn[unit];
      if (needed <= 0 || board.openIn[unit] != needed) {
        continue;
      }
      final List<int> open = <int>[
        for (final int cell in board.cellsOf(unit))
          if (board.isOpen(cell)) cell,
      ];
      for (final int cell in open) {
        if (board.isOpen(cell)) {
          board.placeStar(cell);
        }
      }
      return true;
    }
    return false;
  }
}

/// Star, excluded, or still open.
const int _open = 0;
const int _star = 1;
const int _excluded = 2;

/// The mutable board one solve runs against: what is in each cell, and how many
/// stars and open cells each unit has left.
class _Board {
  _Board(this.spec, List<int> regions)
    : _marks = List<int>.filled(spec.cellCount, _open),
      _neighbours = List<List<int>>.generate(
        spec.cellCount,
        (int cell) => spec.neighbours(cell),
      ) {
    // Rows, then columns, then regions — every unit that must hold exactly
    // [StarsSpec.starsPerUnit] stars.
    final List<List<int>> units = <List<int>>[];
    for (int row = 0; row < spec.size; row++) {
      units.add(<int>[
        for (int column = 0; column < spec.size; column++)
          spec.indexOf(row, column),
      ]);
    }
    for (int column = 0; column < spec.size; column++) {
      units.add(<int>[
        for (int row = 0; row < spec.size; row++) spec.indexOf(row, column),
      ]);
    }
    final List<List<int>> byRegion = List<List<int>>.generate(
      spec.regionCount,
      (int _) => <int>[],
    );
    for (int cell = 0; cell < spec.cellCount; cell++) {
      byRegion[regions[cell]].add(cell);
    }
    units.addAll(byRegion);

    _units = units;
    unitCount = units.length;
    starsIn = List<int>.filled(unitCount, 0);
    openIn = <int>[for (final List<int> unit in units) unit.length];
    _unitsOf = List<List<int>>.generate(spec.cellCount, (int _) => <int>[]);
    for (int unit = 0; unit < unitCount; unit++) {
      for (final int cell in units[unit]) {
        _unitsOf[cell].add(unit);
      }
    }
  }

  final StarsSpec spec;
  final List<int> _marks;
  final List<List<int>> _neighbours;

  late final List<List<int>> _units;
  late final List<List<int>> _unitsOf;

  /// How many units there are: rows, columns and regions together.
  late final int unitCount;

  /// Stars already placed in each unit.
  late final List<int> starsIn;

  /// Cells still open in each unit.
  late final List<int> openIn;

  int _placed = 0;

  /// Whether the board contradicts itself. Only ever true for a region map that
  /// was impossible to begin with: the solver's own moves cannot create one.
  bool isBroken = false;

  /// Whether every star has been placed.
  bool get isComplete => _placed == spec.starCount;

  /// The cells of unit [unit].
  List<int> cellsOf(int unit) => _units[unit];

  /// Whether the cell at [index] is still undecided.
  bool isOpen(int index) => _marks[index] == _open;

  /// The star cells worked out so far, sorted.
  List<int> get stars {
    final List<int> found = <int>[
      for (int cell = 0; cell < _marks.length; cell++)
        if (_marks[cell] == _star) cell,
    ];
    return found..sort();
  }

  /// Puts a star in [index] and does the bookkeeping a person does with it:
  /// rules out every cell it touches, and rules out the rest of any unit it
  /// completes.
  void placeStar(int index) {
    if (_marks[index] != _open) {
      return;
    }
    _marks[index] = _star;
    _placed++;
    for (final int unit in _unitsOf[index]) {
      starsIn[unit]++;
      openIn[unit]--;
    }
    for (final int neighbour in _neighbours[index]) {
      if (_marks[neighbour] == _open) {
        _exclude(neighbour);
      }
    }
    for (final int unit in _unitsOf[index]) {
      if (starsIn[unit] == spec.starsPerUnit) {
        for (final int cell in _units[unit]) {
          if (_marks[cell] == _open) {
            _exclude(cell);
          }
        }
      }
    }
  }

  void _exclude(int index) {
    if (_marks[index] != _open) {
      return;
    }
    _marks[index] = _excluded;
    for (final int unit in _unitsOf[index]) {
      openIn[unit]--;
      if (openIn[unit] < spec.starsPerUnit - starsIn[unit]) {
        // A unit that can no longer reach its star count: the map is broken.
        isBroken = true;
      }
    }
  }
}
