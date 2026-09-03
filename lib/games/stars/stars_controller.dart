import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/move_history.dart';
import 'stars_state.dart';
import 'stars_variant.dart';

/// Produces a puzzle of a given shape and difficulty from a seed.
///
/// A function rather than a direct call so tests can hand the controller a
/// fixed puzzle instead of waiting on a real generation, and so the isolate hop
/// stays in one place. The difficulty is accepted for symmetry with Sudoku and
/// for VIB-86; this story generates one tier and ignores it.
typedef StarsPuzzleSource = Future<StarsPuzzle> Function(
  StarsSpec spec,
  PuzzleDifficulty difficulty,
  int seed,
);

/// Which Stars variant the screen below is playing.
///
/// No default on purpose: a screen must say which variant it is, and the error
/// for forgetting beats a silently wrong board.
final Provider<StarsVariant> starsVariantProvider = Provider<StarsVariant>(
  (Ref ref) => throw UnimplementedError(
    'starsVariantProvider must be overridden by the game screen.',
  ),
  name: 'starsVariant',
);

/// Which tier the screen below asked for.
final Provider<PuzzleDifficulty> starsDifficultyProvider =
    Provider<PuzzleDifficulty>(
      (Ref ref) => throw UnimplementedError(
        'starsDifficultyProvider must be overridden by the game screen.',
      ),
      name: 'starsDifficulty',
    );

/// The game to open instead of generating one, or `null` for a new puzzle.
///
/// Always `null` until resume lands in VIB-89; it is scoped now so that adding
/// it there is an override rather than a rewrite.
final Provider<StarsGameState?> starsResumeProvider = Provider<StarsGameState?>(
  (Ref ref) => null,
  name: 'starsResume',
);

/// Where new puzzles come from. Overridden in tests.
final Provider<StarsPuzzleSource> starsPuzzleSourceProvider =
    Provider<StarsPuzzleSource>(
      (Ref ref) => generateStarsOffThread,
      name: 'starsPuzzleSource',
    );

/// Where seeds come from. Overridden in tests to make a run reproducible.
final Provider<int Function()> starsSeedSourceProvider =
    Provider<int Function()>(
      (Ref ref) =>
          () => DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFF,
      name: 'starsSeedSource',
    );

/// The current game.
final AsyncNotifierProvider<StarsController, StarsGameState>
starsControllerProvider =
    AsyncNotifierProvider<StarsController, StarsGameState>(
      StarsController.new,
      name: 'starsController',
      dependencies: [
        starsVariantProvider,
        starsDifficultyProvider,
        starsResumeProvider,
      ],
    );

/// Holds one Stars puzzle and applies the player's moves to it.
///
/// Everything here is a pure transformation of [StarsGameState]; the board only
/// reads and taps. That is what lets the rules be tested without pumping a
/// frame.
class StarsController extends AsyncNotifier<StarsGameState> {
  @override
  Future<StarsGameState> build() async {
    final StarsGameState? resumed = ref.watch(starsResumeProvider);
    if (resumed != null) {
      return resumed;
    }
    return _freshGame();
  }

  /// Cycles the cell at [index] through empty → ruled out → star → empty, and
  /// points the board at it.
  ///
  /// The whole of Stars input: there is no number pad, so a tap on a cell is
  /// the move. A given puzzle has no fixed cells — every cell is the player's —
  /// so the only thing that stops a cycle is the puzzle already being solved.
  void cycle(int index) {
    final StarsGameState? game = state.value;
    if (game == null ||
        game.isSolved ||
        index < 0 ||
        index >= game.cells.length) {
      return;
    }
    final StarsMark current = game.cells[index];
    final StarsMark next = switch (current) {
      StarsMark.empty => StarsMark.ruledOut,
      StarsMark.ruledOut => StarsMark.star,
      StarsMark.star => StarsMark.empty,
    };
    final List<StarsMark> cells = List<StarsMark>.of(game.cells)
      ..[index] = next;
    state = AsyncData<StarsGameState>(
      game.copyWith(
        cells: cells,
        selectedIndex: index,
        // A ruled-out star is no longer a hint's doing; only a hint sets one,
        // which does not happen until VIB-90.
        hints: game.hints.difference(<int>{index}),
        history: game.history.push(
          BoardMove(index: index, before: current.index, after: next.index),
        ),
      ),
    );
  }

  /// Throws away the current puzzle and generates another.
  Future<void> startNewPuzzle() async {
    state = const AsyncLoading<StarsGameState>();
    state = await AsyncValue.guard(_freshGame);
  }

  /// A newly generated puzzle of the shape and tier this screen asked for.
  Future<StarsGameState> _freshGame() async {
    final StarsVariant variant = ref.read(starsVariantProvider);
    final PuzzleDifficulty difficulty = ref.read(starsDifficultyProvider);
    final StarsPuzzleSource source = ref.read(starsPuzzleSourceProvider);
    final int seed = ref.read(starsSeedSourceProvider)();
    final StarsPuzzle puzzle = await source(variant.spec, difficulty, seed);
    return StarsGameState.fresh(variant: variant, puzzle: puzzle);
  }
}

/// Generates a puzzle on a background isolate.
///
/// A Stars puzzle can carve and measure dozens of region maps before one lands
/// unique and guess-free, so the hop off the UI thread exists from the first
/// puzzle rather than being added once someone notices a dropped frame.
Future<StarsPuzzle> generateStarsOffThread(
  StarsSpec spec,
  PuzzleDifficulty difficulty,
  int seed,
) {
  return compute(_generate, _GenerateRequest(spec, difficulty, seed));
}

@immutable
class _GenerateRequest {
  const _GenerateRequest(this.spec, this.difficulty, this.seed);

  final StarsSpec spec;
  final PuzzleDifficulty difficulty;
  final int seed;
}

/// This story generates one tier, so the requested [_GenerateRequest.difficulty]
/// is carried for VIB-86 but not yet used to pick a target.
StarsPuzzle _generate(_GenerateRequest request) =>
    StarsGenerator(request.spec).generate(request.seed);
