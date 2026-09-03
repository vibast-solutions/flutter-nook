import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/move_history.dart';
import 'duo_variant.dart';

/// What one Duo cell holds.
///
/// Three states, cycled by a tap: nothing, a circle, a square. The order the
/// values are declared in is the order a tap moves through them, and [index] is
/// what a saved move records, so it must stay stable. A given cell holds a
/// [circle] or a [square] and never changes; only the player's own cells cycle.
enum DuoCell {
  /// Untouched.
  empty,

  /// The player (or the puzzle) has put a circle here.
  circle,

  /// The player (or the puzzle) has put a square here.
  square;

  /// The engine symbol this cell holds, or `null` while it is empty.
  DuoSymbol? get symbol => switch (this) {
    DuoCell.empty => null,
    DuoCell.circle => DuoSymbol.circle,
    DuoCell.square => DuoSymbol.square,
  };

  /// The cell that holds [symbol].
  static DuoCell of(DuoSymbol symbol) =>
      symbol == DuoSymbol.circle ? DuoCell.circle : DuoCell.square;
}

/// A Duo puzzle in progress: the puzzle, what the player has entered so far, and
/// which cell they last touched.
///
/// Immutable — every change produces a new instance — which is what will make
/// resume (VIB-96) an addition rather than a rewrite. It mirrors
/// `StarsGameState`: the cells stand in for the marks, and there is no number
/// pad because a tap on the board is the whole of the input.
@immutable
class DuoGameState {
  DuoGameState({
    required this.variant,
    required this.puzzle,
    required List<DuoCell> cells,
    Set<int>? hints,
    this.selectedIndex,
    this.history = const MoveHistory.empty(),
    this.wasHinted = false,
  }) : cells = List<DuoCell>.unmodifiable(cells),
       hints = Set<int>.unmodifiable(hints ?? const <int>{});

  /// Starts a fresh game from a generated [puzzle], the givens in place and
  /// every other cell empty.
  factory DuoGameState.fresh({
    required DuoVariant variant,
    required DuoPuzzle puzzle,
  }) {
    return DuoGameState(
      variant: variant,
      puzzle: puzzle,
      cells: <DuoCell>[
        for (int index = 0; index < puzzle.spec.cellCount; index++)
          puzzle.givens[index] == null
              ? DuoCell.empty
              : DuoCell.of(puzzle.givens[index]!),
      ],
    );
  }

  /// Which Duo game this is.
  final DuoVariant variant;

  /// The generated puzzle: its givens, badges and one solution.
  final DuoPuzzle puzzle;

  /// What each cell holds, row-major.
  final List<DuoCell> cells;

  /// The cells a hint filled in, so the board can keep saying which were given
  /// away rather than worked out (VIB-97). Empty until then.
  final Set<int> hints;

  /// Whether this puzzle was ever helped along by a hint.
  ///
  /// Nothing sets it until VIB-97; it is here now so statistics count a hinted
  /// puzzle the way they do in the other games.
  final bool wasHinted;

  /// The cell the player last touched, or `null` if none.
  final int? selectedIndex;

  /// The moves the player can still take back.
  ///
  /// Held in the shared type every game uses, plain enough to be written to disk
  /// as it stands. A Duo move changes one cell, so nothing new was needed here.
  final MoveHistory history;

  /// The shape of the grid.
  DuoSpec get spec => puzzle.spec;

  /// The tier this puzzle was measured at.
  PuzzleDifficulty? get difficulty => puzzle.difficulty;

  /// What the cell at [index] holds.
  DuoCell cellAt(int index) => cells[index];

  /// Whether the cell at [index] came with the puzzle and cannot be changed.
  bool isGiven(int index) => puzzle.isGiven(index);

  /// Whether the symbol in the cell at [index] came from a hint.
  bool isHinted(int index) => hints.contains(index);

  /// Whether the board obeys every rule of the game and is therefore finished.
  ///
  /// Read straight off the cells and the rules — the solution is **never**
  /// consulted. A board is finished when no cell is empty, every row and column
  /// holds its share of each symbol, no line runs one symbol past the limit, and
  /// every badge is satisfied. There is nothing else a full, legal grid could be
  /// but the one solution, and checking the rules rather than the answer is what
  /// keeps the board from being an oracle to brute-force rather than a puzzle to
  /// solve.
  bool get isSolved {
    final List<DuoSymbol> grid = <DuoSymbol>[];
    for (final DuoCell cell in cells) {
      final DuoSymbol? symbol = cell.symbol;
      if (symbol == null) {
        return false;
      }
      grid.add(symbol);
    }

    // Balance: [perSymbol] circles (and so [perSymbol] squares) in each line.
    for (int line = 0; line < spec.size; line++) {
      int rowCircles = 0;
      int columnCircles = 0;
      for (int i = 0; i < spec.size; i++) {
        if (grid[spec.indexOf(line, i)] == DuoSymbol.circle) {
          rowCircles++;
        }
        if (grid[spec.indexOf(i, line)] == DuoSymbol.circle) {
          columnCircles++;
        }
      }
      if (rowCircles != spec.perSymbol || columnCircles != spec.perSymbol) {
        return false;
      }
    }

    // No run of one symbol past the limit, in any row or column.
    for (int row = 0; row < spec.size; row++) {
      for (int column = 0; column < spec.size; column++) {
        if (_runsTooFar(grid, row, column, 0, 1) ||
            _runsTooFar(grid, row, column, 1, 0)) {
          return false;
        }
      }
    }

    // Every badge honoured.
    for (final DuoBadge badge in puzzle.badges) {
      if (!badge.relation.holds(grid[badge.a], grid[badge.b])) {
        return false;
      }
    }
    return true;
  }

  /// Whether a run of `runLimit + 1` identical symbols starts at [row], [column]
  /// stepping `(dRow, dColumn)`.
  bool _runsTooFar(
    List<DuoSymbol> grid,
    int row,
    int column,
    int dRow,
    int dColumn,
  ) {
    final int endRow = row + dRow * spec.runLimit;
    final int endColumn = column + dColumn * spec.runLimit;
    if (endRow >= spec.size || endColumn >= spec.size) {
      return false;
    }
    final DuoSymbol first = grid[spec.indexOf(row, column)];
    for (int k = 1; k <= spec.runLimit; k++) {
      if (grid[spec.indexOf(row + dRow * k, column + dColumn * k)] != first) {
        return false;
      }
    }
    return true;
  }

  /// Whether there is a move to take back.
  ///
  /// A solved grid is finished, so the control switches off with the rest of the
  /// board — undoing out of a solved board would only be a way to unsolve it by
  /// accident.
  bool get canUndo => history.canUndo && !isSolved;

  /// Whether erase has a cell to empty: one is selected, it is the player's
  /// (not a given), it is not already empty, and the puzzle is still being
  /// played.
  bool get canErase =>
      !isSolved &&
      selectedIndex != null &&
      !isGiven(selectedIndex!) &&
      cells[selectedIndex!] != DuoCell.empty;

  /// A copy with the given fields replaced.
  ///
  /// [selectedIndex] cannot be cleared through this; nothing needs to.
  DuoGameState copyWith({
    List<DuoCell>? cells,
    Set<int>? hints,
    int? selectedIndex,
    MoveHistory? history,
    bool? wasHinted,
  }) {
    return DuoGameState(
      variant: variant,
      puzzle: puzzle,
      cells: cells ?? this.cells,
      hints: hints ?? this.hints,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      history: history ?? this.history,
      wasHinted: wasHinted ?? this.wasHinted,
    );
  }
}
