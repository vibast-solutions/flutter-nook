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
/// in one place. The puzzle it returns is generated at the requested difficulty
/// (VIB-94).
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

/// The game to open instead of generating one, or `null` for a new puzzle.
///
/// `null` at the root; the game screen overrides it with a saved board when the
/// player resumes (VIB-96), and the controller reads it once on build.
final Provider<DuoGameState?> duoResumeProvider = Provider<DuoGameState?>(
  (Ref ref) => null,
  name: 'duoResume',
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
      dependencies: [
        duoVariantProvider,
        duoDifficultyProvider,
        duoResumeProvider,
      ],
    );

/// Holds one Duo puzzle and applies the player's moves to it.
///
/// Everything here is a pure transformation of [DuoGameState]; the board only
/// reads and taps. That is what lets the rules be tested without pumping a
/// frame.
class DuoController extends AsyncNotifier<DuoGameState> {
  @override
  Future<DuoGameState> build() async {
    final DuoGameState? resumed = ref.watch(duoResumeProvider);
    if (resumed != null) {
      return resumed;
    }
    return _freshGame();
  }

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
        // Any move but a hint removal ends the crossing-out, so a later removal
        // at the same cell reads as a change and animates again.
        forgetRemoval: true,
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
        forgetRemoval: true,
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
  /// * with a symbol the solution does not have on the board, the most recently
  ///   placed one is taken away and nothing is revealed;
  /// * with none, [DuoHinter] picks a symbol the technique solver can justify
  ///   from the givens and badges, so the hint shows the player one they were
  ///   not seeing rather than taking a piece of the puzzle away.
  ///
  /// Removing first is what keeps the app from contradicting itself: a correct
  /// symbol dropped into a line already poisoned by a mistake would be marked
  /// as a breach the moment it landed, by the same board that had just given it.
  ///
  /// This is the only place Nook ever judges the player's work against the
  /// solution, and it happens because the player asked. Either kind counts as
  /// help, so the puzzle sets no personal best afterwards.
  void hint() {
    final DuoGameState? game = state.value;
    if (game == null || game.isSolved) {
      return;
    }
    final int? wrong = _wrongSymbolToClear(game);
    if (wrong != null) {
      final DuoCell current = game.cells[wrong];
      final List<DuoCell> cells = List<DuoCell>.of(game.cells)
        ..[wrong] = DuoCell.empty;
      state = AsyncData<DuoGameState>(
        game.copyWith(
          cells: cells,
          // The cell is empty now, so it is nobody's hint; the puzzle stays
          // marked as hinted, which is a fact about the game rather than the
          // cell.
          hints: game.hints.difference(<int>{wrong}),
          wasHinted: true,
          selectedIndex: wrong,
          removal: DuoRemoval(index: wrong, cell: current),
          history: game.history.push(
            BoardMove(
              index: wrong,
              before: current.index,
              after: DuoCell.empty.index,
            ),
          ),
        ),
      );
      return;
    }
    final DuoHint? found = DuoHinter(
      game.puzzle,
    ).hintFor(<DuoSymbol?>[for (final DuoCell cell in game.cells) cell.symbol]);
    if (found == null) {
      return;
    }
    final DuoCell before = game.cells[found.index];
    final List<DuoCell> cells = List<DuoCell>.of(game.cells)
      ..[found.index] = DuoCell.of(found.symbol);
    state = AsyncData<DuoGameState>(
      game.copyWith(
        cells: cells,
        // A hint marks the symbol it gave, so a resumed board still says which
        // symbols were worked out and which were given away.
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
            after: DuoCell.of(found.symbol).index,
          ),
        ),
      ),
    );
  }

  /// The wrong symbol a hint should take away, or `null` if there is none.
  ///
  /// A "wrong" symbol is one that disagrees with the solution in its cell — the
  /// one place Nook ever reads the solution to judge the player, and only
  /// because they asked. A given can never be wrong; only the player's own
  /// cells are looked at. The most recently placed one is chosen by walking the
  /// history back: it is the one the player is still thinking about, and taking
  /// the oldest mistake away would undo work they have long since built on. A
  /// wrong symbol whose move has fallen off the end of the history — a long
  /// game, or one resumed from a trimmed save — is taken in reading order
  /// instead, which is arbitrary but never nothing.
  int? _wrongSymbolToClear(DuoGameState game) {
    final Set<int> wrong = <int>{
      for (int index = 0; index < game.cells.length; index++)
        if (!game.isGiven(index) &&
            game.cells[index] != DuoCell.empty &&
            game.cells[index].symbol != game.puzzle.solution[index])
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
    DuoGenerator(request.spec).generateAt(request.difficulty, request.seed);
