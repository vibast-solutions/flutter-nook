import 'package:flutter/foundation.dart';

/// What finishing a Snake run did to the best score kept for its speed.
///
/// Snake's counterpart to a puzzle's [SolveOutcome], and deliberately its own
/// small type rather than a reuse: a puzzle's "best" is the *fastest* hint-free
/// time and lives in the statistics table, where a Snake run has no clock, no
/// difficulty and no notion of a hint. Its best is the *highest* score, kept per
/// speed level, and it is a genuinely different thing measured in the opposite
/// direction — so it is stored apart and described apart (VIB-110).
///
/// Produced by the write rather than read back afterwards, because
/// [previousBest] stops existing the moment a new best is stored: the only place
/// that knows what the run had to beat is the code that beat it.
@immutable
class SnakeScoreOutcome {
  const SnakeScoreOutcome({
    required this.score,
    required this.best,
    required this.isNewBest,
    this.previousBest,
  });

  /// The score this run reached.
  final int score;

  /// The best score at this speed now, this run included — [score] when the run
  /// beat what stood, otherwise the stored best it did not.
  final int best;

  /// The best before this run, or `null` if this speed had never been played.
  final int? previousBest;

  /// Whether this run set a new best. True the first time a speed is played,
  /// because any score beats no score at all.
  final bool isNewBest;
}
