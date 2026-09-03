import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/move_history.dart';
import '../../chrome/note_marks.dart';
import 'sudoku_state.dart';
import 'sudoku_variant.dart';

/// Produces a puzzle of a given shape and difficulty from a seed.
///
/// A function rather than a direct call so tests can hand the controller a
/// fixed puzzle instead of waiting on a real generation, and so the isolate
/// hop stays in one place.
typedef SudokuPuzzleSource = Future<SudokuPuzzle> Function(
  SudokuSpec spec,
  PuzzleDifficulty difficulty,
  int seed,
);

/// Which Sudoku the screen below is playing.
///
/// Has no default on purpose: a screen must say which variant it is, and the
/// error you get for forgetting is better than a silently wrong grid.
final Provider<SudokuVariant> sudokuVariantProvider = Provider<SudokuVariant>(
  (Ref ref) => throw UnimplementedError(
    'sudokuVariantProvider must be overridden by the game screen.',
  ),
  name: 'sudokuVariant',
);

/// Which tier the screen below asked for.
///
/// Scoped like [sudokuVariantProvider] and for the same reason: a screen must
/// say what it is playing, and the puzzle a player gets has to be the one they
/// chose rather than whatever the generator happened to produce.
final Provider<PuzzleDifficulty> sudokuDifficultyProvider =
    Provider<PuzzleDifficulty>(
      (Ref ref) => throw UnimplementedError(
        'sudokuDifficultyProvider must be overridden by the game screen.',
      ),
      name: 'sudokuDifficulty',
    );

/// The game to open instead of generating one, or `null` for a new puzzle.
///
/// Scoped like the two above: resuming is a property of the way the screen was
/// opened, not of the app, and a player who taps a difficulty after resuming
/// must get a fresh puzzle rather than the same saved one again.
final Provider<SudokuGameState?> sudokuResumeProvider =
    Provider<SudokuGameState?>((Ref ref) => null, name: 'sudokuResume');

/// Where new puzzles come from. Overridden in tests.
final Provider<SudokuPuzzleSource> sudokuPuzzleSourceProvider =
    Provider<SudokuPuzzleSource>(
      (Ref ref) => generateSudokuOffThread,
      name: 'sudokuPuzzleSource',
    );

/// Where seeds come from. Overridden in tests to make a run reproducible.
///
/// The engine may not read the clock; the app may, and this is the one place
/// it does for a puzzle.
final Provider<int Function()> sudokuSeedSourceProvider =
    Provider<int Function()>(
      (Ref ref) =>
          () => DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFF,
      name: 'sudokuSeedSource',
    );

/// The current game.
final AsyncNotifierProvider<SudokuController, SudokuGameState>
sudokuControllerProvider =
    AsyncNotifierProvider<SudokuController, SudokuGameState>(
      SudokuController.new,
      name: 'sudokuController',
      // Declared so the controller is rebuilt inside the scope the game screen
      // opens, where the variant is overridden. Without it the controller resolves
      // in the root container and never sees which Sudoku it is playing.
      dependencies: [
        sudokuVariantProvider,
        sudokuDifficultyProvider,
        sudokuResumeProvider,
      ],
    );

/// Holds one Sudoku and applies the player's moves to it.
///
/// Everything here is a pure transformation of [SudokuGameState]; the widgets
/// only read and tap. That is what lets the rules be tested without pumping a
/// single frame.
class SudokuController extends AsyncNotifier<SudokuGameState> {
  @override
  Future<SudokuGameState> build() async {
    final SudokuGameState? resumed = ref.watch(sudokuResumeProvider);
    if (resumed != null) {
      // A saved puzzle is already a whole game; there is nothing to generate
      // and nothing to wait for, which is why resuming never shows a spinner.
      return resumed;
    }
    return _freshGame();
  }

  /// Points the number pad at the cell at [index].
  ///
  /// Given cells can be selected: the player still wants to see where that
  /// digit already appears. They just cannot be written to.
  void select(int index) {
    final SudokuGameState? game = state.value;
    if (game == null || index < 0 || index >= game.cells.length) {
      return;
    }
    if (game.selectedIndex == index) {
      return;
    }
    state = AsyncData<SudokuGameState>(game.copyWith(selectedIndex: index));
  }

  /// Writes [digit] into the selected cell, or pencils it in when the pad is
  /// in notes mode.
  ///
  /// Tapping the digit already in the cell clears it, which is the quickest
  /// way to take back a single mistake without reaching for erase; in notes
  /// mode the same tap rubs the mark out. Does nothing when there is no
  /// selection, the cell is a given, or the puzzle is already solved.
  void enter(int digit) {
    final SudokuGameState? game = state.value;
    if (game == null || digit < 1 || digit > game.size) {
      return;
    }
    final int? index = game.selectedIndex;
    if (index == null) {
      return;
    }
    if (game.notesMode) {
      // A mark and an answer never share a cell, so pencilling into a filled
      // cell puts the answer back in doubt rather than hiding under the marks.
      final NoteMarks marks = game.notesAt(index).toggled(digit);
      _write(game, index, value: 0, notes: marks.mask);
      return;
    }
    final int value = game.cells[index] == digit ? 0 : digit;
    // An answer settles the cell, so the working that led to it goes; clearing
    // one leaves the (already empty) marks alone.
    _write(
      game,
      index,
      value: value,
      notes: value == 0 ? game.notes[index] : 0,
    );
  }

  /// Empties the selected cell, marks and all.
  ///
  /// Does nothing on a given, on a cell that is already empty, or when nothing
  /// is selected — in each of those there is no move to make, so none is
  /// recorded and undo stays a list of things the player actually did.
  void erase() {
    final SudokuGameState? game = state.value;
    final int? index = game?.selectedIndex;
    if (game == null || index == null) {
      return;
    }
    _write(game, index, value: 0, notes: 0);
  }

  /// Switches the pad between writing answers and pencilling marks.
  ///
  /// Not a move: it changes what the next tap means, not the board, so there
  /// is nothing here for undo to take back.
  void toggleNotes() {
    final SudokuGameState? game = state.value;
    if (game == null || game.isSolved) {
      return;
    }
    state = AsyncData<SudokuGameState>(
      game.copyWith(notesMode: !game.notesMode),
    );
  }

  /// Takes back the last move, and puts the player back on the cell it
  /// changed.
  ///
  /// Undoing with nothing to undo is a no-op: a player who taps once too often
  /// should get nothing, not an error.
  void undo() {
    final SudokuGameState? game = state.value;
    if (game == null || !game.canUndo) {
      return;
    }
    final BoardMove move = game.history.last!;
    final List<int> cells = List<int>.of(game.cells)
      ..[move.index] = move.before;
    final List<int> notes = List<int>.of(game.notes)
      ..[move.index] = move.notesBefore;
    // Undo is the strict inverse of one move, so the marks it rubbed out of
    // its row, column and box come back with it — in the cells they came from
    // and only the bits it took, because a cell may have been pencilled in
    // again since.
    for (final MapEntry<int, int> cleared in move.clearedNotes.entries) {
      notes[cleared.key] |= cleared.value;
    }
    state = AsyncData<SudokuGameState>(
      game.copyWith(
        cells: cells,
        notes: notes,
        // Whatever the cell held is gone, so it is no longer showing a hint —
        // the puzzle stays marked as hinted, which is a fact about the game
        // rather than about the cell.
        hints: game.hints.difference(<int>{move.index}),
        selectedIndex: move.index,
        history: game.history.pop(),
        forgetHintRemoval: true,
      ),
    );
  }

  /// Shows the player their next move.
  ///
  /// Unlimited and free: there is no hint budget in Nook to spend, wait for or
  /// buy back. What a hint *is* is the whole of the design, and it is not
  /// simply a reveal — the next move on a board carrying a mistake is to be
  /// rid of the mistake, so:
  ///
  /// * with a wrong digit on the board, the most recently entered one is
  ///   taken away and nothing is revealed;
  /// * with none, [SudokuHinter] picks a cell the technique solver can
  ///   justify from the board as it stands, so the hint shows the player what
  ///   they were not seeing rather than taking a piece of the puzzle away.
  ///
  /// Removing first is what keeps the app from contradicting itself: a digit
  /// revealed into a row already poisoned by a mistake would be marked as a
  /// conflict the moment it landed, by the same board that had just given it.
  ///
  /// This is the only place Nook ever judges an entry against the solution,
  /// and it happens because the player asked. Either kind counts as help, so
  /// the puzzle sets no personal best afterwards.
  void hint() {
    final SudokuGameState? game = state.value;
    if (game == null || game.isSolved) {
      return;
    }
    final int? wrong = _wrongCellToClear(game);
    if (wrong != null) {
      _write(
        game,
        wrong,
        value: 0,
        notes: game.notes[wrong],
        writer: _Writer.hintClearing,
      );
      return;
    }
    final SudokuHint? found = SudokuHinter(game.puzzle).hintFor(game.cells);
    if (found == null) {
      return;
    }
    // The marks in the cell go with the answer, exactly as they would if the
    // player had settled it themselves.
    _write(
      game,
      found.index,
      value: found.digit,
      notes: 0,
      writer: _Writer.hintFilling,
    );
  }

  /// The wrong digit a hint should take away, or `null` if there is none.
  ///
  /// The most recently entered one, found by walking the history back: it is
  /// the one the player is still thinking about, and taking the oldest
  /// mistake away would undo work they have long since built on. A wrong cell
  /// whose move has fallen off the end of the history — a long game, or one
  /// resumed from a trimmed save — is taken in reading order instead, which is
  /// arbitrary but never nothing.
  int? _wrongCellToClear(SudokuGameState game) {
    final Set<int> wrong = <int>{};
    for (int index = 0; index < game.cells.length; index++) {
      final int value = game.cells[index];
      if (value != 0 &&
          !game.isGiven(index) &&
          value != game.puzzle.solution[index]) {
        wrong.add(index);
      }
    }
    if (wrong.isEmpty) {
      return null;
    }
    for (final BoardMove move in game.history.moves.reversed) {
      if (wrong.contains(move.index)) {
        return move.index;
      }
    }
    // Built by walking the grid, so the first of them is the first in reading
    // order.
    return wrong.first;
  }

  /// Puts [value] and [notes] in the cell at [index] and records the move.
  ///
  /// The one place the board is written to, so there is one place a move can
  /// be missed from the history rather than one per control. An answer and the
  /// marks around it change together and come back together — and so does
  /// whether the cell is showing a hint, which is why [writer] comes through
  /// here rather than being stamped on afterwards.
  ///
  /// Writing an answer also **tidies the marks it rules out**: the digit is
  /// rubbed out of the pencil marks of every cell in its row, column and box,
  /// because a player who has just settled a 3 for that row would otherwise
  /// have to go and rub the noted 3s out by hand. That reads the digit the
  /// player claimed and the shape of the grid, never the solution — a wrong
  /// digit tidies exactly as a right one does, because the app is applying the
  /// player's claim rather than the truth. The move carries what it took, so
  /// undo puts it all back.
  void _write(
    SudokuGameState game,
    int index, {
    required int value,
    required int notes,
    _Writer writer = _Writer.player,
  }) {
    final int before = game.cells[index];
    final int notesBefore = game.notes[index];
    if (game.isSolved ||
        game.isGiven(index) ||
        (value == before && notes == notesBefore)) {
      return;
    }
    final List<int> written = List<int>.of(game.notes)..[index] = notes;
    final Map<int, int> cleared = <int, int>{};
    if (value != 0) {
      final int bit = 1 << (value - 1);
      for (final int peer in game.peersOf(index)) {
        if (written[peer] & bit != 0) {
          written[peer] &= ~bit;
          cleared[peer] = bit;
        }
      }
    }
    final bool helped = writer != _Writer.player;
    state = AsyncData<SudokuGameState>(
      game.copyWith(
        cells: List<int>.of(game.cells)..[index] = value,
        notes: written,
        // A hint marks the cell it filled; anything else written into a hinted
        // cell — a hint clearing it included — makes it the player's again.
        hints: writer == _Writer.hintFilling
            ? <int>{...game.hints, index}
            : game.hints.difference(<int>{index}),
        wasHinted: game.wasHinted || helped,
        // A hint lands where the player was not looking, so the selection goes
        // to it — otherwise the one thing that changed is the one thing they
        // have to hunt for.
        selectedIndex: helped ? index : game.selectedIndex,
        history: game.history.push(
          BoardMove(
            index: index,
            before: before,
            after: value,
            notesBefore: notesBefore,
            notesAfter: notes,
            clearedNotes: Map<int, int>.unmodifiable(cleared),
          ),
        ),
        hintRemoval: writer == _Writer.hintClearing
            ? HintRemoval(index: index, digit: before)
            : null,
        forgetHintRemoval: writer != _Writer.hintClearing,
      ),
    );
  }

  /// Throws away the current puzzle and generates another.
  ///
  /// Generates rather than rebuilding: rebuilding would read the resume slot
  /// again and hand back the very puzzle the player just asked to leave.
  Future<void> startNewPuzzle() async {
    state = const AsyncLoading<SudokuGameState>();
    state = await AsyncValue.guard(_freshGame);
  }

  /// A newly generated puzzle of the shape and tier this screen asked for.
  ///
  /// Read rather than watched: the variant, the tier and the seed source are
  /// fixed for as long as the screen is open, and a controller that rebuilt
  /// itself would throw away the game the player is in the middle of.
  Future<SudokuGameState> _freshGame() async {
    final SudokuVariant variant = ref.read(sudokuVariantProvider);
    final PuzzleDifficulty difficulty = ref.read(sudokuDifficultyProvider);
    final SudokuPuzzleSource source = ref.read(sudokuPuzzleSourceProvider);
    final int seed = ref.read(sudokuSeedSourceProvider)();
    final SudokuPuzzle puzzle = await source(variant.spec, difficulty, seed);
    return SudokuGameState.fresh(variant: variant, puzzle: puzzle);
  }
}

/// Who is putting something in a cell.
///
/// Three voices rather than a boolean: a hint that fills a cell marks it and
/// counts as help, a hint that clears a wrong one counts as help but marks
/// nothing — the cell is empty — and the player's own tap does neither.
enum _Writer { player, hintFilling, hintClearing }

/// Generates a puzzle on a background isolate.
///
/// A 4x4 is instant, but a Fiendish 9x9 is not: it can carve and measure
/// dozens of grids before one lands on the tier that was asked for. The UI is
/// never allowed to stutter, so the hop exists from the first puzzle rather
/// than being added once someone notices a dropped frame.
Future<SudokuPuzzle> generateSudokuOffThread(
  SudokuSpec spec,
  PuzzleDifficulty difficulty,
  int seed,
) {
  return compute(_generate, _GenerateRequest(spec, difficulty, seed));
}

@immutable
class _GenerateRequest {
  const _GenerateRequest(this.spec, this.difficulty, this.seed);

  final SudokuSpec spec;
  final PuzzleDifficulty difficulty;
  final int seed;
}

SudokuPuzzle _generate(_GenerateRequest request) =>
    SudokuGenerator(request.spec).generateAt(request.difficulty, request.seed);
