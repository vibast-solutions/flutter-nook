import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/move_history.dart';
import 'sudoku_state.dart';
import 'sudoku_variant.dart';

/// Produces a puzzle for a grid shape and a seed.
///
/// A function rather than a direct call so tests can hand the controller a
/// fixed puzzle instead of waiting on a real generation, and so the isolate
/// hop stays in one place.
typedef SudokuPuzzleSource = Future<SudokuPuzzle> Function(
  SudokuSpec spec,
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
      dependencies: [sudokuVariantProvider],
    );

/// Holds one Sudoku and applies the player's moves to it.
///
/// Everything here is a pure transformation of [SudokuGameState]; the widgets
/// only read and tap. That is what lets the rules be tested without pumping a
/// single frame.
class SudokuController extends AsyncNotifier<SudokuGameState> {
  @override
  Future<SudokuGameState> build() async {
    final SudokuVariant variant = ref.watch(sudokuVariantProvider);
    final SudokuPuzzleSource source = ref.watch(sudokuPuzzleSourceProvider);
    final int seed = ref.watch(sudokuSeedSourceProvider)();
    final SudokuPuzzle puzzle = await source(variant.spec, seed);
    return SudokuGameState.fresh(variant: variant, puzzle: puzzle);
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

  /// Writes [digit] into the selected cell.
  ///
  /// Tapping the digit already in the cell clears it, which is the quickest
  /// way to take back a single mistake without reaching for erase.
  /// Does nothing when there is no selection, the cell is a given, or the
  /// puzzle is already solved.
  void enter(int digit) {
    final SudokuGameState? game = state.value;
    if (game == null || digit < 1 || digit > game.size) {
      return;
    }
    final int? index = game.selectedIndex;
    if (index == null) {
      return;
    }
    _write(game, index, game.cells[index] == digit ? 0 : digit);
  }

  /// Empties the selected cell.
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
    _write(game, index, 0);
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
    state = AsyncData<SudokuGameState>(
      game.copyWith(
        cells: cells,
        selectedIndex: move.index,
        history: game.history.pop(),
      ),
    );
  }

  /// Puts [value] in the cell at [index] and records the move.
  ///
  /// The one place the board is written to, so there is one place a move can
  /// be missed from the history rather than one per control.
  void _write(SudokuGameState game, int index, int value) {
    final int before = game.cells[index];
    if (game.isSolved || game.isGiven(index) || value == before) {
      return;
    }
    final List<int> cells = List<int>.of(game.cells)..[index] = value;
    state = AsyncData<SudokuGameState>(
      game.copyWith(
        cells: cells,
        history: game.history.push(
          BoardMove(index: index, before: before, after: value),
        ),
      ),
    );
  }

  /// Throws away the current puzzle and generates another.
  Future<void> startNewPuzzle() async {
    state = const AsyncLoading<SudokuGameState>();
    ref.invalidateSelf();
    await future;
  }
}

/// Generates a puzzle on a background isolate.
///
/// A 4x4 is instant, but a Fiendish 9x9 is not, and the UI is never allowed to
/// stutter — so the hop exists from the first puzzle rather than being added
/// once someone notices a dropped frame.
Future<SudokuPuzzle> generateSudokuOffThread(SudokuSpec spec, int seed) {
  return compute(_generate, _GenerateRequest(spec, seed));
}

@immutable
class _GenerateRequest {
  const _GenerateRequest(this.spec, this.seed);

  final SudokuSpec spec;
  final int seed;
}

SudokuPuzzle _generate(_GenerateRequest request) =>
    SudokuGenerator(request.spec).generate(request.seed);
