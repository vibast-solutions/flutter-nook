import 'package:flutter/foundation.dart';

/// The daily streak as a screen needs it: the number to show, and whether
/// today's daily has already been solved.
///
/// A value type the app passes around, kept apart from the row the database
/// stores for the same reason [GameStats] is: `lib/store/` hands the rest of
/// the app plain values, not Drift rows, and the reset rule — a run whose last
/// day has passed reads as zero — has already been applied by the time one of
/// these exists.
@immutable
class DailyStreakStatus {
  const DailyStreakStatus({required this.streak, required this.solvedToday});

  /// The current run of consecutive solved days, already reset to zero if the
  /// last solved day is older than yesterday.
  final int streak;

  /// Whether today's daily has been solved.
  ///
  /// What turns the home card informational: once today's row exists there is
  /// nothing left to open, so the card says "Solved" and stops being a button.
  final bool solvedToday;

  @override
  bool operator ==(Object other) =>
      other is DailyStreakStatus &&
      other.streak == streak &&
      other.solvedToday == solvedToday;

  @override
  int get hashCode => Object.hash(streak, solvedToday);
}
