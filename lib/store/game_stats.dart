import 'package:flutter/foundation.dart';

/// What Nook remembers about one game at one difficulty.
///
/// Two numbers, and deliberately only two. There is no failure statistic
/// anywhere in Nook: a puzzle the player walked away from is not recorded at
/// all, so nothing here can count against them. Nor is there anything to
/// compare with — no leaderboard, no percentile, no other players. The only
/// thing a player is measured against is themselves, last time.
///
/// Game-agnostic like a saved game and for the same reason: [gameId] and
/// [difficulty] are the identifiers the app layer maps back to its own types,
/// so one row shape describes a solved Sudoku, Stars and Duo alike.
@immutable
class GameStats {
  const GameStats({
    required this.gameId,
    required this.difficulty,
    required this.solved,
    this.bestTime,
  });

  /// Which game these figures are for.
  final String gameId;

  /// Which tier of it, as an identifier rather than a name a player reads.
  final String difficulty;

  /// How many puzzles have been finished here, hinted or not.
  final int solved;

  /// The fastest hint-free solve, or `null` if there has not been one.
  ///
  /// A hinted puzzle counts as solved and shows its time, but never sets this
  /// — a personal best has to mean the player did it themselves. So a tier can
  /// perfectly well have a solved count and no best time, and the screens have
  /// to say so rather than showing a zero.
  final Duration? bestTime;
}

/// What finishing a puzzle did to the figures behind it.
///
/// Produced by the write rather than read back afterwards, because
/// [previousBest] stops existing the moment the new best is stored: the only
/// place that knows what the player had to beat is the code that beat it.
@immutable
class SolveOutcome {
  const SolveOutcome({
    required this.time,
    required this.solved,
    required this.wasHinted,
    this.previousBest,
    this.isPersonalBest = false,
  });

  /// How long this puzzle took.
  final Duration time;

  /// The best time before this one, or `null` if there was none.
  final Duration? previousBest;

  /// How many puzzles have now been solved here, this one included.
  final int solved;

  /// Whether the player was helped along the way.
  final bool wasHinted;

  /// Whether this solve set a new best time.
  ///
  /// Never true for a hinted puzzle, however fast it was.
  final bool isPersonalBest;
}

/// The figures for one game and tier out of [all], or `null` if it has none.
///
/// `null` rather than an empty [GameStats]: "never solved one of these" and
/// "solved none of these" are the same thing, and the screens want to say
/// something different for it than a zero.
GameStats? statsFor(
  Iterable<GameStats> all, {
  required String gameId,
  required String difficulty,
}) {
  for (final GameStats stats in all) {
    if (stats.gameId == gameId && stats.difficulty == difficulty) {
      return stats;
    }
  }
  return null;
}
