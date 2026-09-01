import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import 'sudoku_variant.dart';

/// A Sudoku in progress: the puzzle, what the player has entered so far, and
/// which cell they are pointing at.
///
/// Immutable — every change produces a new instance. That is what makes undo
/// (VIB-71) and save/resume (VIB-75) additions rather than rewrites.
@immutable
class SudokuGameState {
  SudokuGameState({
    required this.variant,
    required this.puzzle,
    required List<int> cells,
    this.selectedIndex,
  }) : cells = List<int>.unmodifiable(cells);

  /// Starts a fresh game from a generated [puzzle], with nothing selected.
  factory SudokuGameState.fresh({
    required SudokuVariant variant,
    required SudokuPuzzle puzzle,
  }) {
    return SudokuGameState(
      variant: variant,
      puzzle: puzzle,
      cells: List<int>.of(puzzle.givens),
    );
  }

  /// Which Sudoku this is.
  final SudokuVariant variant;

  /// The generated puzzle, including its givens and its one solution.
  final SudokuPuzzle puzzle;

  /// The current grid: givens plus whatever the player has entered.
  /// `0` means empty.
  final List<int> cells;

  /// The cell the number pad will write to, or `null` if none is selected.
  final int? selectedIndex;

  /// The shape of the grid.
  SudokuSpec get spec => puzzle.spec;

  /// The side length of the grid, and its largest digit.
  int get size => spec.size;

  /// Whether the cell at [index] came with the puzzle and cannot be changed.
  bool isGiven(int index) => puzzle.isGiven(index);

  /// The digit in the selected cell, or `0` if it is empty or nothing is
  /// selected.
  int get selectedDigit {
    final int? index = selectedIndex;
    return index == null ? 0 : cells[index];
  }

  /// How many more times [digit] must be placed to fill the grid.
  ///
  /// Never negative: a digit placed too often reads as zero remaining, which
  /// is what the number pad wants to show.
  int remaining(int digit) {
    int placed = 0;
    for (final int value in cells) {
      if (value == digit) {
        placed++;
      }
    }
    final int left = size - placed;
    return left < 0 ? 0 : left;
  }

  /// Whether [digit] has been placed as often as the grid can hold it.
  bool isExhausted(int digit) => remaining(digit) == 0;

  /// Whether the grid is complete and correct.
  ///
  /// The puzzle has exactly one solution, so matching it is the same thing as
  /// being complete and breaking no rule — there is nothing else it could be.
  bool get isSolved {
    for (int i = 0; i < cells.length; i++) {
      if (cells[i] != puzzle.solution[i]) {
        return false;
      }
    }
    return true;
  }

  /// Whether the cell at [index] shares a row, column or box with [other].
  bool sharesUnit(int index, int other) =>
      spec.rowOf(index) == spec.rowOf(other) ||
      spec.columnOf(index) == spec.columnOf(other) ||
      spec.boxOf(index) == spec.boxOf(other);

  /// A copy with the given fields replaced.
  ///
  /// [selectedIndex] cannot be cleared through this; nothing needs to, and
  /// allowing it would mean an extra sentinel for no gain.
  SudokuGameState copyWith({List<int>? cells, int? selectedIndex}) {
    return SudokuGameState(
      variant: variant,
      puzzle: puzzle,
      cells: cells ?? this.cells,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}
