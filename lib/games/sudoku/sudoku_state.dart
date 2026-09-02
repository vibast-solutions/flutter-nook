import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/move_history.dart';
import '../../chrome/note_marks.dart';
import 'sudoku_variant.dart';

/// A digit a hint has just taken off the board.
///
/// Kept so the board can show the cell being emptied — the digit is already
/// gone from the grid by the time anything draws, and a cell that simply
/// blanked would look like a bug rather than like an answer being taken away.
/// Never written to disk: it describes a moment, not a game.
@immutable
class HintRemoval {
  const HintRemoval({required this.index, required this.digit});

  /// The cell that was emptied.
  final int index;

  /// The digit that was in it.
  final int digit;

  @override
  bool operator ==(Object other) =>
      other is HintRemoval && other.index == index && other.digit == digit;

  @override
  int get hashCode => Object.hash(index, digit);

  @override
  String toString() => 'HintRemoval($digit at $index)';
}

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
    Set<int>? hints,
    this.selectedIndex,
    this.history = const MoveHistory.empty(),
    this.notesMode = false,
    this.wasHinted = false,
    this.hintRemoval,
  }) : cells = List<int>.unmodifiable(cells),
       notes = List<int>.unmodifiable(
         notes ?? List<int>.filled(cells.length, 0),
       ),
       hints = Set<int>.unmodifiable(hints ?? const <int>{});

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

  /// The cells a hint filled in, so the board can keep saying which digits
  /// were given away rather than worked out.
  ///
  /// Only the cells still holding their hinted digit: writing over one, or
  /// taking it back, makes the cell the player's again. Whether the puzzle was
  /// ever hinted at all is [wasHinted], which no amount of undoing clears.
  final Set<int> hints;

  /// Whether this puzzle has ever been hinted.
  ///
  /// Sticky, unlike [hints]: a revealed cell cannot be un-revealed by taking
  /// it back, and this is what tells statistics (VIB-77) that the time still
  /// counts but the personal best does not.
  final bool wasHinted;

  /// The digit a hint has just taken off the board, or `null` if the last
  /// thing that happened was anything else.
  ///
  /// Transient, and the one piece of this state that a save does not carry: it
  /// exists for the length of an animation, and a puzzle resumed tomorrow
  /// should not replay a cell being crossed out.
  final HintRemoval? hintRemoval;

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

  /// Whether the digit in the cell at [index] came from a hint.
  bool isHinted(int index) => hints.contains(index);

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

  /// The cells holding a digit that is repeated in their row, column or box.
  ///
  /// Computed from the grid and the rules alone — [puzzle] is never consulted
  /// for the answer. A conflict is a rule being broken, which is something a
  /// player could find by scanning; a digit that merely disagrees with the
  /// solution breaks nothing and is left in peace, because a board that marked
  /// it would be an oracle to brute-force rather than a puzzle to solve.
  ///
  /// Both halves of a repeat are marked, givens included: the pair is the
  /// thing to look at, and deciding which of the two is the intruder would
  /// mean knowing the answer.
  late final Set<int> conflicts = _repeatedCells();

  /// The cells of every row, column and box that is full and free of repeats.
  ///
  /// Full and legal rather than correct, for the same reason: a unit of
  /// distinct digits can still belong to a grid that is wrong everywhere else,
  /// so celebrating one gives nothing away.
  late final Set<int> completedUnits = _completedUnitCells();

  /// Whether the digit in the cell at [index] is repeated in one of its units.
  bool isConflicting(int index) => conflicts.contains(index);

  /// Every cell sharing a row, column or box with [index], excluding it.
  ///
  /// The cells a digit written at [index] has anything to say about: the ones
  /// it can conflict with, and the ones whose pencil marks it rules out.
  List<int> peersOf(int index) {
    return <int>[
      for (int other = 0; other < cells.length; other++)
        if (other != index && sharesUnit(other, index)) other,
    ];
  }

  /// Whether the cell at [index] shares a row, column or box with [other].
  bool sharesUnit(int index, int other) =>
      spec.rowOf(index) == spec.rowOf(other) ||
      spec.columnOf(index) == spec.columnOf(other) ||
      spec.boxOf(index) == spec.boxOf(other);

  /// The cells whose digit appears twice in one of the units they belong to.
  ///
  /// One pass per kind of unit rather than one per unit: keying on the unit
  /// and the digit together sorts every row (then every column, then every
  /// box) in a single walk of the grid.
  Set<int> _repeatedCells() {
    final Set<int> found = <int>{};
    for (final int Function(int) unitOf in <int Function(int)>[
      spec.rowOf,
      spec.columnOf,
      spec.boxOf,
    ]) {
      final Map<int, List<int>> byUnitAndDigit = <int, List<int>>{};
      for (int index = 0; index < cells.length; index++) {
        final int value = cells[index];
        if (value == 0) {
          continue;
        }
        (byUnitAndDigit[unitOf(index) * (size + 1) + value] ??= <int>[]).add(
          index,
        );
      }
      for (final List<int> group in byUnitAndDigit.values) {
        if (group.length > 1) {
          found.addAll(group);
        }
      }
    }
    return Set<int>.unmodifiable(found);
  }

  /// The cells of every unit that is full and holds no digit twice.
  Set<int> _completedUnitCells() {
    final Set<int> found = <int>{};
    for (final int Function(int) unitOf in <int Function(int)>[
      spec.rowOf,
      spec.columnOf,
      spec.boxOf,
    ]) {
      final Map<int, List<int>> byUnit = <int, List<int>>{};
      for (int index = 0; index < cells.length; index++) {
        (byUnit[unitOf(index)] ??= <int>[]).add(index);
      }
      for (final List<int> unit in byUnit.values) {
        final Set<int> digits = <int>{
          for (final int index in unit) cells[index],
        };
        // A blank reads as the digit zero, so a unit with one in it can never
        // have as many distinct digits as it has cells.
        if (digits.length == unit.length && !digits.contains(0)) {
          found.addAll(unit);
        }
      }
    }
    return Set<int>.unmodifiable(found);
  }

  /// A copy with the given fields replaced.
  ///
  /// [selectedIndex] cannot be cleared through this; nothing needs to, and
  /// allowing it would mean an extra sentinel for no gain. [hintRemoval] can,
  /// through [forgetHintRemoval], because it has to be: it marks a moment, and
  /// every move after that moment has to be able to say the moment is over.
  SudokuGameState copyWith({
    List<int>? cells,
    List<int>? notes,
    Set<int>? hints,
    int? selectedIndex,
    MoveHistory? history,
    bool? notesMode,
    bool? wasHinted,
    HintRemoval? hintRemoval,
    bool forgetHintRemoval = false,
  }) {
    return SudokuGameState(
      variant: variant,
      puzzle: puzzle,
      cells: cells ?? this.cells,
      notes: notes ?? this.notes,
      hints: hints ?? this.hints,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      history: history ?? this.history,
      notesMode: notesMode ?? this.notesMode,
      wasHinted: wasHinted ?? this.wasHinted,
      hintRemoval: forgetHintRemoval ? null : (hintRemoval ?? this.hintRemoval),
    );
  }
}
