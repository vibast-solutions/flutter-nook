import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/move_history.dart';
import '../../chrome/note_marks.dart';
import 'sudoku_variant.dart';

/// A Sudoku in progress: the puzzle, what the player has entered so far, and
/// which cell they are pointing at.
///
/// Immutable — every change produces a new instance. That is what makes undo
/// and save/resume (VIB-75) additions rather than rewrites.
@immutable
class SudokuGameState {
  SudokuGameState({
    required this.variant,
    required this.puzzle,
    required List<int> cells,
    List<int>? notes,
    this.selectedIndex,
    this.history = const MoveHistory.empty(),
    this.notesMode = false,
  }) : cells = List<int>.unmodifiable(cells),
       notes = List<int>.unmodifiable(
         notes ?? List<int>.filled(cells.length, 0),
       );

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

  /// The pencil marks in each cell, one [NoteMarks] bitmask per cell.
  ///
  /// A plain list of integers rather than a list of sets: it is the shape a
  /// saved game wants (VIB-75), and reading a cell's marks back out is a
  /// wrapper away.
  final List<int> notes;

  /// The cell the number pad will write to, or `null` if none is selected.
  final int? selectedIndex;

  /// Whether the number pad is writing pencil marks instead of answers.
  ///
  /// Part of the game rather than the screen: it decides what a tap does, and
  /// a player who put the pad in notes mode expects to find it there when they
  /// come back to the puzzle.
  final bool notesMode;

  /// The moves the player can still take back.
  ///
  /// Held in the shared type rather than a Sudoku-shaped one: every game keeps
  /// its history the same way, and this one is plain enough to be written to
  /// disk as it stands.
  final MoveHistory history;

  /// The shape of the grid.
  SudokuSpec get spec => puzzle.spec;

  /// The tier this puzzle was measured at.
  SudokuDifficulty? get difficulty => puzzle.difficulty;

  /// The side length of the grid, and its largest digit.
  int get size => spec.size;

  /// Whether the cell at [index] came with the puzzle and cannot be changed.
  bool isGiven(int index) => puzzle.isGiven(index);

  /// The pencil marks in the cell at [index].
  NoteMarks notesAt(int index) => NoteMarks(notes[index]);

  /// Whether the cell at [index] is showing pencil marks.
  ///
  /// A cell shows an answer or its marks, never both: an answer is what the
  /// player has settled on, and the marks that led there are noise once it is
  /// down.
  bool showsNotes(int index) => cells[index] == 0 && notes[index] != 0;

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

  /// Whether there is a move to take back.
  ///
  /// A solved grid is finished: taking a digit back out of it would only be a
  /// way to unsolve a puzzle by accident, so the control switches off with the
  /// rest of the board.
  bool get canUndo => history.canUndo && !isSolved;

  /// Whether the cell at [index] shares a row, column or box with [other].
  bool sharesUnit(int index, int other) =>
      spec.rowOf(index) == spec.rowOf(other) ||
      spec.columnOf(index) == spec.columnOf(other) ||
      spec.boxOf(index) == spec.boxOf(other);

  /// A copy with the given fields replaced.
  ///
  /// [selectedIndex] cannot be cleared through this; nothing needs to, and
  /// allowing it would mean an extra sentinel for no gain.
  SudokuGameState copyWith({
    List<int>? cells,
    List<int>? notes,
    int? selectedIndex,
    MoveHistory? history,
    bool? notesMode,
  }) {
    return SudokuGameState(
      variant: variant,
      puzzle: puzzle,
      cells: cells ?? this.cells,
      notes: notes ?? this.notes,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      history: history ?? this.history,
      notesMode: notesMode ?? this.notesMode,
    );
  }
}
