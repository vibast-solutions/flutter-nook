import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../store/game_stats.dart';
import '../../store/nook_database.dart';
import 'sudoku_controller.dart';

/// The puzzle the player has just finished, or `null` while one is in play.
///
/// Scoped to the game screen through its dependencies, so a result belongs to
/// the puzzle that produced it and cannot outlive it: asking for another
/// puzzle empties this, and the finished screen goes away with it.
final NotifierProvider<SolveOutcomeNotifier, SolveOutcome?>
solveOutcomeProvider = NotifierProvider<SolveOutcomeNotifier, SolveOutcome?>(
  SolveOutcomeNotifier.new,
  name: 'solveOutcome',
  dependencies: [sudokuVariantProvider, sudokuDifficultyProvider],
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
  /// is still on the board: a revealed cell cannot be un-revealed by taking it
  /// back, so a puzzle that was hinted keeps its time and never sets a best.
  Future<void> record({required Duration time, required bool hinted}) async {
    final SolveOutcome outcome = await ref
        .read(gameStatsStoreProvider)
        .record(
          gameId: ref.read(sudokuVariantProvider).id,
          difficulty: ref.read(sudokuDifficultyProvider).name,
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
