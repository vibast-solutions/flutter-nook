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
/// The ladder in this story is the **simple** tier only, the three deductions a
/// person reads straight off the board:
///
/// * **badge** — a cell beside a filled one across an `=` or `x` badge is
///   forced to match or differ.
/// * **noTriple** — a cell where one symbol would make three of that symbol in
///   a row must be the other.
/// * **lineFull** — a row or column already holding all three of one symbol
///   fills its remaining cells with the other.
///
/// The intermediate and advanced rungs, and the rater that turns a solve into a
/// tier, are VIB-94. A puzzle this solver cannot finish rates as unsolvable,
/// which is a rejection: the generator restores givens rather than offering a
/// puzzle that would need a guess.
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

  /// A cell where one symbol would make a run one too long is forced to the
  /// other symbol.
  bool _noTriple(_Board board) {
    for (int index = 0; index < spec.cellCount; index++) {
      if (!board.isEmpty(index)) {
        continue;
      }
      final bool circleBanned = board.wouldOverrun(index, DuoSymbol.circle);
      final bool squareBanned = board.wouldOverrun(index, DuoSymbol.square);
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
