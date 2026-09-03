import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/move_history.dart';
import 'duo_state.dart';
import 'duo_variant.dart';

/// Produces a puzzle of a given shape and difficulty from a seed.
///
/// A function rather than a direct call so tests can hand the controller a fixed
/// puzzle instead of waiting on a real generation, and so the isolate hop stays
/// in one place. The difficulty is accepted for symmetry with the other games
/// and for VIB-94; this story generates one tier and ignores it.
typedef DuoPuzzleSource = Future<DuoPuzzle> Function(
  DuoSpec spec,
  PuzzleDifficulty difficulty,
  int seed,
);

/// Which Duo variant the screen below is playing.
///
/// No default on purpose: a screen must say which variant it is, and the error
/// for forgetting beats a silently wrong board.
final Provider<DuoVariant> duoVariantProvider = Provider<DuoVariant>(
  (Ref ref) => throw UnimplementedError(
    'duoVariantProvider must be overridden by the game screen.',
  ),
  name: 'duoVariant',
);

/// Which tier the screen below asked for.
final Provider<PuzzleDifficulty> duoDifficultyProvider =
    Provider<PuzzleDifficulty>(
      (Ref ref) => throw UnimplementedError(
        'duoDifficultyProvider must be overridden by the game screen.',
      ),
      name: 'duoDifficulty',
    );

/// Where new puzzles come from. Overridden in tests.
final Provider<DuoPuzzleSource> duoPuzzleSourceProvider =
    Provider<DuoPuzzleSource>(
      (Ref ref) => generateDuoOffThread,
      name: 'duoPuzzleSource',
    );

/// Where seeds come from. Overridden in tests to make a run reproducible.
final Provider<int Function()> duoSeedSourceProvider = Provider<int Function()>(
  (Ref ref) =>
      () => DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFF,
  name: 'duoSeedSource',
);

/// The current game.
final AsyncNotifierProvider<DuoController, DuoGameState> duoControllerProvider =
    AsyncNotifierProvider<DuoController, DuoGameState>(
      DuoController.new,
      name: 'duoController',
      dependencies: [duoVariantProvider, duoDifficultyProvider],
    );

/// Holds one Duo puzzle and applies the player's moves to it.
///
/// Everything here is a pure transformation of [DuoGameState]; the board only
/// reads and taps. That is what lets the rules be tested without pumping a
/// frame.
class DuoController extends AsyncNotifier<DuoGameState> {
  @override
  Future<DuoGameState> build() => _freshGame();

  /// Cycles the player's cell at [index] through empty → circle → square →
  /// empty, and points the board at it.
  ///
  /// The whole of Duo input: there is no number pad, so a tap on a cell is the
  /// move. A given cell does not respond — it is fixed — and neither does any
  /// cell once the puzzle is solved.
  void cycle(int index) {
    final DuoGameState? game = state.value;
    if (game == null ||
        game.isSolved ||
        index < 0 ||
        index >= game.cells.length ||
        game.isGiven(index)) {
      return;
    }
    final DuoCell current = game.cells[index];
    final DuoCell next = switch (current) {
      DuoCell.empty => DuoCell.circle,
      DuoCell.circle => DuoCell.square,
      DuoCell.square => DuoCell.empty,
    };
    final List<DuoCell> cells = List<DuoCell>.of(game.cells)..[index] = next;
    state = AsyncData<DuoGameState>(
      game.copyWith(
        cells: cells,
        selectedIndex: index,
        // Writing over a hinted cell hands it back to the player, as it does in
        // the other games.
        hints: game.hints.difference(<int>{index}),
        history: game.history.push(
          BoardMove(index: index, before: current.index, after: next.index),
        ),
      ),
    );
  }

  /// Empties the selected cell.
  ///
  /// A move forward like any other, not a reversal: it records itself so undo
  /// can put back exactly what was emptied. Does nothing when there is no
  /// selection, when the selected cell is a given or already empty, or when the
  /// puzzle is solved — in each of those there is nothing to erase.
  void erase() {
    final DuoGameState? game = state.value;
    if (game == null || !game.canErase) {
      return;
    }
    final int index = game.selectedIndex!;
    final DuoCell current = game.cells[index];
    final List<DuoCell> cells = List<DuoCell>.of(game.cells)
      ..[index] = DuoCell.empty;
    state = AsyncData<DuoGameState>(
      game.copyWith(
        cells: cells,
        selectedIndex: index,
        hints: game.hints.difference(<int>{index}),
        history: game.history.push(
          BoardMove(
            index: index,
            before: current.index,
            after: DuoCell.empty.index,
          ),
        ),
      ),
    );
  }

  /// Takes back the last move, and puts the player back on the cell it changed.
  ///
  /// The strict inverse of one move and nothing more: a Duo move only ever
  /// changes its own cell, so undoing it puts that cell back to what it held.
  /// Undoing with nothing to undo, or on a solved board, is a no-op.
  void undo() {
    final DuoGameState? game = state.value;
    if (game == null || !game.canUndo) {
      return;
    }
    final BoardMove move = game.history.last!;
    final List<DuoCell> cells = List<DuoCell>.of(game.cells)
      ..[move.index] = DuoCell.values[move.before];
    state = AsyncData<DuoGameState>(
      game.copyWith(
        cells: cells,
        hints: game.hints.difference(<int>{move.index}),
        selectedIndex: move.index,
        history: game.history.pop(),
      ),
    );
  }

  /// Throws away the current puzzle and generates another.
  Future<void> startNewPuzzle() async {
    state = const AsyncLoading<DuoGameState>();
    state = await AsyncValue.guard(_freshGame);
  }

  /// A newly generated puzzle of the shape and tier this screen asked for.
  Future<DuoGameState> _freshGame() async {
    final DuoVariant variant = ref.read(duoVariantProvider);
    final PuzzleDifficulty difficulty = ref.read(duoDifficultyProvider);
    final DuoPuzzleSource source = ref.read(duoPuzzleSourceProvider);
    final int seed = ref.read(duoSeedSourceProvider)();
    final DuoPuzzle puzzle = await source(variant.spec, difficulty, seed);
    return DuoGameState.fresh(variant: variant, puzzle: puzzle);
  }
}

/// Generates a puzzle on a background isolate.
///
/// A Duo puzzle carves and re-checks a grid many times before one lands unique
/// and guess-free, so the hop off the UI thread exists from the first puzzle
/// rather than being added once someone notices a dropped frame.
Future<DuoPuzzle> generateDuoOffThread(
  DuoSpec spec,
  PuzzleDifficulty difficulty,
  int seed,
) {
  return compute(_generate, _GenerateRequest(spec, difficulty, seed));
}

@immutable
class _GenerateRequest {
  const _GenerateRequest(this.spec, this.difficulty, this.seed);

  final DuoSpec spec;
  final PuzzleDifficulty difficulty;
  final int seed;
}

DuoPuzzle _generate(_GenerateRequest request) =>
    DuoGenerator(request.spec).generate(request.seed);
