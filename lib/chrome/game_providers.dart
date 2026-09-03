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
