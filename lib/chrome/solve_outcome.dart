import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../store/game_stats.dart';
import '../store/nook_database.dart';
import 'game_providers.dart';

/// The puzzle the player has just finished, or `null` while one is in play.
///
/// Scoped to the game screen through its dependencies, so a result belongs to
/// the puzzle that produced it and cannot outlive it: asking for another puzzle
/// empties this, and the finished screen goes away with it.
///
/// Game-agnostic: it reads [gameIdProvider] and [gameDifficultyProvider] rather
/// than any one game's, so the same notifier records a solved Sudoku, Stars or
/// Duo. Each game screen overrides those two.
final NotifierProvider<SolveOutcomeNotifier, SolveOutcome?>
solveOutcomeProvider = NotifierProvider<SolveOutcomeNotifier, SolveOutcome?>(
  SolveOutcomeNotifier.new,
  name: 'solveOutcome',
  dependencies: [gameIdProvider, gameDifficultyProvider],
);

/// Writes a finished puzzle down, and holds what that did to the figures.
///
/// The screen is told its numbers by the write rather than reading them back
/// afterwards, because one of them — the time the player has just beaten —
/// stops existing the moment the new best is stored.
class SolveOutcomeNotifier extends Notifier<SolveOutcome?> {
  @override
  SolveOutcome? build() => null;

  /// Counts a puzzle finished in [time], and publishes the result.
  ///
  /// [hinted] is whether the puzzle was ever helped along, not whether a hint
  /// is still on the board: help is help, so a puzzle that was hinted keeps its
  /// time and never sets a best.
  Future<void> record({required Duration time, required bool hinted}) async {
    final SolveOutcome outcome = await ref
        .read(gameStatsStoreProvider)
        .record(
          gameId: ref.read(gameIdProvider),
          difficulty: ref.read(gameDifficultyProvider).name,
          time: time,
          hinted: hinted,
        );
    // The player may have asked for another puzzle while the write was in
    // flight, and the result of the one before it is not theirs to see.
    if (ref.mounted) {
      state = outcome;
    }
  }

  /// Forgets the last result, because there is a new puzzle on the board.
  void clear() => state = null;
}
