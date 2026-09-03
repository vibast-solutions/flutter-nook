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
        // The daily route pins these two in its own scope — the plain
        // generator at the date's seed. Undeclared they would resolve in the
        // root container and silently serve a pack puzzle instead.
        starsPuzzleSourceProvider,
        starsSeedSourceProvider,
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
        // Writing over a hinted cell hands it back to the player, exactly as it
        // does in Sudoku.
        hints: game.hints.difference(<int>{index}),
        // Any move but a hint removal ends the crossing-out, so a later removal
        // at the same cell reads as a change and animates again.
        forgetRemoval: true,
        history: game.history.push(
          BoardMove(index: index, before: current.index, after: next.index),
        ),
      ),
    );
  }

  /// Empties the selected cell, whether it holds a star or a ruled-out dot.
  ///
  /// A move forward like any other, not a reversal: it records itself so undo
  /// can put back exactly what was emptied. Does nothing when there is no
  /// selection, when the selected cell is already empty, or when the puzzle is
  /// solved — in each of those there is nothing to erase, so no move is made.
  void erase() {
    final StarsGameState? game = state.value;
    if (game == null || !game.canErase) {
      return;
    }
    final int index = game.selectedIndex!;
    final StarsMark current = game.cells[index];
    final List<StarsMark> cells = List<StarsMark>.of(game.cells)
      ..[index] = StarsMark.empty;
    state = AsyncData<StarsGameState>(
      game.copyWith(
        cells: cells,
        selectedIndex: index,
        hints: game.hints.difference(<int>{index}),
        forgetRemoval: true,
        history: game.history.push(
          BoardMove(
            index: index,
            before: current.index,
            after: StarsMark.empty.index,
          ),
        ),
      ),
    );
  }

  /// Wipes every ruled-out dot on the board, leaving the stars where they are.
  ///
  /// The whole sweep is one move, so a single undo brings every dot back where
  /// it was: the first dot rides in the move's own cell and the rest in
  /// [BoardMove.clearedMarks], the same shape a Sudoku placement uses to carry
  /// the notes it tidied. Does nothing when there is no dot to clear or the
  /// puzzle is solved.
  void clearMarks() {
    final StarsGameState? game = state.value;
    if (game == null || !game.canClearMarks) {
      return;
    }
    final List<int> dotted = <int>[
      for (int index = 0; index < game.cells.length; index++)
        if (game.cells[index] == StarsMark.ruledOut) index,
    ];
    final List<StarsMark> cells = List<StarsMark>.of(game.cells);
    for (final int index in dotted) {
      cells[index] = StarsMark.empty;
    }
    final int primary = dotted.first;
    state = AsyncData<StarsGameState>(
      game.copyWith(
        cells: cells,
        forgetRemoval: true,
        history: game.history.push(
          BoardMove(
            index: primary,
            before: StarsMark.ruledOut.index,
            after: StarsMark.empty.index,
            clearedMarks: <int, int>{
              for (final int index in dotted.skip(1))
                index: StarsMark.ruledOut.index,
            },
          ),
        ),
      ),
    );
  }

  /// Takes back the last move, and puts the player back on the cell it
  /// changed.
  ///
  /// The strict inverse of one move and nothing more: the cell the move named
  /// goes back to what it held, and any cells the move swept clear alongside it
  /// — the dots a "clear marks" took — come back exactly where they were.
  /// Undoing with nothing to undo, or on a solved board, is a no-op.
  void undo() {
    final StarsGameState? game = state.value;
    if (game == null || !game.canUndo) {
      return;
    }
    final BoardMove move = game.history.last!;
    final List<StarsMark> cells = List<StarsMark>.of(game.cells)
      ..[move.index] = StarsMark.values[move.before];
    for (final MapEntry<int, int> cleared in move.clearedMarks.entries) {
      cells[cleared.key] = StarsMark.values[cleared.value];
    }
    state = AsyncData<StarsGameState>(
      game.copyWith(
        cells: cells,
        hints: game.hints.difference(<int>{
          move.index,
          ...move.clearedMarks.keys,
        }),
        selectedIndex: move.index,
        history: game.history.pop(),
        forgetRemoval: true,
      ),
    );
  }

  /// Shows the player their next move.
  ///
  /// Unlimited and free: there is no hint budget in Nook to spend, wait for or
  /// buy back. What a hint *is* is the whole of the design, and it is not simply
  /// a reveal — the next move on a board carrying a mistake is to be rid of the
  /// mistake, so:
  ///
  /// * with a star the solution does not have on the board, the most recently
  ///   placed one is taken away and nothing is revealed;
  /// * with none, [StarsHinter] picks a star the technique solver can justify
  ///   from the region map, so the hint shows the player one they were not
  ///   seeing rather than taking a piece of the puzzle away.
  ///
  /// Removing first is what keeps the app from contradicting itself: a correct
  /// star dropped into a row already poisoned by a mistake would be marked as a
  /// breach the moment it landed, by the same board that had just given it.
  ///
  /// This is the only place Nook ever judges the player's work against the
  /// solution, and it happens because the player asked. Either kind counts as
  /// help, so the puzzle sets no personal best afterwards.
  void hint() {
    final StarsGameState? game = state.value;
    if (game == null || game.isSolved) {
      return;
    }
    final int? wrong = _wrongStarToClear(game);
    if (wrong != null) {
      final List<StarsMark> cells = List<StarsMark>.of(game.cells)
        ..[wrong] = StarsMark.empty;
      state = AsyncData<StarsGameState>(
        game.copyWith(
          cells: cells,
          // The cell is empty now, so it is nobody's hint; the puzzle stays
          // marked as hinted, which is a fact about the game rather than the
          // cell.
          hints: game.hints.difference(<int>{wrong}),
          wasHinted: true,
          selectedIndex: wrong,
          starRemoval: StarRemoval(index: wrong),
          history: game.history.push(
            BoardMove(
              index: wrong,
              before: StarsMark.star.index,
              after: StarsMark.empty.index,
            ),
          ),
        ),
      );
      return;
    }
    final StarsHint? found = StarsHinter(game.puzzle).hintFor(game.starCells);
    if (found == null) {
      return;
    }
    final StarsMark before = game.cells[found.index];
    final List<StarsMark> cells = List<StarsMark>.of(game.cells)
      ..[found.index] = StarsMark.star;
    state = AsyncData<StarsGameState>(
      game.copyWith(
        cells: cells,
        // A hint marks the star it gave, so a resumed board still says which
        // stars were worked out and which were given away.
        hints: <int>{...game.hints, found.index},
        wasHinted: true,
        // A hint lands where the player was not looking, so the selection goes
        // to it — otherwise the one thing that changed is the one thing they
        // have to hunt for.
        selectedIndex: found.index,
        forgetRemoval: true,
        history: game.history.push(
          BoardMove(
            index: found.index,
            before: before.index,
            after: StarsMark.star.index,
          ),
        ),
      ),
    );
  }

  /// The wrong star a hint should take away, or `null` if there is none.
  ///
  /// A "wrong" star is one in a cell the solution leaves empty — the one place
  /// Nook ever reads the solution to judge the player, and only because they
  /// asked. The most recently placed one is chosen by walking the history back:
  /// it is the one the player is still thinking about, and taking the oldest
  /// mistake away would undo work they have long since built on. A wrong star
  /// whose move has fallen off the end of the history — a long game, or one
  /// resumed from a trimmed save — is taken in reading order instead, which is
  /// arbitrary but never nothing.
  int? _wrongStarToClear(StarsGameState game) {
    final Set<int> solution = game.puzzle.solution.toSet();
    final Set<int> wrong = <int>{
      for (int index = 0; index < game.cells.length; index++)
        if (game.cells[index] == StarsMark.star && !solution.contains(index))
          index,
    };
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

StarsPuzzle _generate(_GenerateRequest request) =>
    StarsGenerator(request.spec).generateAt(request.difficulty, request.seed);
