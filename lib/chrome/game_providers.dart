import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// Which game the screen below is playing, as its stable id.
///
/// The id a save and a statistic are keyed on — `sudoku-classic`, `stars` —
/// never a name a player reads. Shared across games so the chrome that records
/// and celebrates a solve (the completion screen, [solveOutcomeProvider]) can
/// be written once: it asks this rather than knowing which game it is under.
///
/// Has no default on purpose: a game screen must say which game it is, and the
/// error for forgetting beats a solve filed under the wrong id.
final Provider<String> gameIdProvider = Provider<String>(
  (Ref ref) => throw UnimplementedError(
    'gameIdProvider must be overridden by the game screen.',
  ),
  name: 'gameId',
);

/// Which tier the screen below is playing.
///
/// Scoped like [gameIdProvider]: the shared chrome records a solve against the
/// tier it was played at, and the puzzle a player gets has to be the one they
/// chose. Each game keeps its own variant/difficulty providers for its
/// controller; this is the game-agnostic pair the shared chrome reads.
final Provider<PuzzleDifficulty> gameDifficultyProvider =
    Provider<PuzzleDifficulty>(
      (Ref ref) => throw UnimplementedError(
        'gameDifficultyProvider must be overridden by the game screen.',
      ),
      name: 'gameDifficulty',
    );

/// Which saved-game slot the session below writes into, or `null` for the
/// game's own — the variant id, which is the default everywhere but the daily.
///
/// The daily puzzle saves under its own id so it can never collide with — or
/// silently discard — an ordinary puzzle of the same game the player has under
/// way. The daily route overrides this; a game page reads it and falls back to
/// its variant id.
final Provider<String?> saveSlotProvider = Provider<String?>(
  (Ref ref) => null,
  name: 'saveSlot',
);

/// What the session runs once the puzzle it is watching is solved, after the
/// save has been discarded, or `null` for nothing.
///
/// Nothing is the right default: an ordinary solve counts towards its game's
/// statistics and nothing else. The daily is the exception — it counts towards
/// the streak — so its route overrides this with a call into the daily store,
/// and the discard-the-save seam every game already has is where it runs. A game
/// screen reads it and calls it beside discarding, so no game grows a branch of
/// its own for the daily.
final Provider<Future<void> Function()?> onSolvedProvider =
    Provider<Future<void> Function()?>((Ref ref) => null, name: 'onSolved');

/// What the completion screen's "another puzzle" button does instead of
/// regenerating in place, or `null` for the default.
///
/// The default — the controller's own `startNewPuzzle` — is right for an
/// ordinary game, where the seed source hands out a fresh seed. The daily
/// route pins its seed, so regenerating would hand the player today's puzzle
/// again; it overrides this with a jump into an ordinary game instead.
final Provider<void Function()?> completionAnotherProvider =
    Provider<void Function()?>((Ref ref) => null, name: 'completionAnother');
