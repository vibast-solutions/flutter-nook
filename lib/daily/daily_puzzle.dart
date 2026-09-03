import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// Which game a day's puzzle is, out of the three the daily rotates through.
///
/// Sudoku Mini and Light stay out on purpose: neither offers the whole ladder
/// (`tiersFor` measures it), and a daily that cannot ramp on Sundays is not the
/// same daily everywhere.
enum DailyGame { sudokuClassic, stars, duo }

/// Everything below is a promise, not a preference. The daily puzzle is
/// "identical worldwide with no server", and that only holds because every copy
/// of the app computes the same identity from the same date. The anchor date,
/// the rotation order, the weekday ramp and the seed formula may therefore only
/// change at an app-update boundary — a player on the old version and one on
/// the new will disagree about today, and that is the accepted cost of an
/// update, never of a config value.
///
/// Day 0. The rotation is counted in whole calendar days from here, so it lands
/// on Sudoku Classic.
final DateTime _anchor = DateTime.utc(2026, 1, 1);

/// The rotation, applied as `dayNumber % 3`.
const List<DailyGame> _rotation = <DailyGame>[
  DailyGame.sudokuClassic,
  DailyGame.stars,
  DailyGame.duo,
];

/// The weekday ramp, Monday first: the week starts gently and climbs to a
/// fiendish Sunday. Indexed by `DateTime.weekday - 1`.
const List<PuzzleDifficulty> _ramp = <PuzzleDifficulty>[
  PuzzleDifficulty.gentle,
  PuzzleDifficulty.easy,
  PuzzleDifficulty.easy,
  PuzzleDifficulty.medium,
  PuzzleDifficulty.medium,
  PuzzleDifficulty.hard,
  PuzzleDifficulty.fiendish,
];

/// The identity of one day's puzzle: which game, how hard, and from what seed.
///
/// A pure function of the calendar date — see [dailyPuzzleFor] — and nothing
/// else, which is the whole of how one puzzle a day reaches every player with
/// no server behind it.
@immutable
class DailyPuzzle {
  const DailyPuzzle._({
    required this.date,
    required this.game,
    required this.difficulty,
    required this.seed,
  });

  /// The calendar date this is the puzzle of, held as a UTC midnight so two
  /// dates compare by calendar day and never by clock.
  final DateTime date;

  /// Which of the three rotation games the day landed on.
  final DailyGame game;

  /// The tier the weekday ramp sets for it.
  final PuzzleDifficulty difficulty;

  /// The seed the puzzle is generated from: the date written as one number,
  /// `year * 10000 + month * 100 + day`. It doubles as the save's date — a
  /// daily save is recognised as today's by carrying today's seed.
  final int seed;
}

/// The daily puzzle for the calendar date of [now].
///
/// [now] is read for its date fields only — the device's local calendar date,
/// the way a person answers "what day is it". A date-line traveller may see a
/// repeat or a skip and a changed clock changes the daily; both are accepted,
/// because there is no server and nothing to cheat.
DailyPuzzle dailyPuzzleFor(DateTime now) {
  // Rebuilt in UTC so the day count is a count of calendar days: subtracting
  // local midnights would come up a daylight-saving hour short twice a year.
  final DateTime date = DateTime.utc(now.year, now.month, now.day);
  // Dart's % is never negative, so a clock set before the anchor still lands
  // on a stable identity rather than an exception.
  final int dayNumber = date.difference(_anchor).inDays;
  return DailyPuzzle._(
    date: date,
    game: _rotation[dayNumber % _rotation.length],
    difficulty: _ramp[date.weekday - 1],
    seed: date.year * 10000 + date.month * 100 + date.day,
  );
}

/// The daily puzzle whose seed is [seed], or `null` if the seed is not a date.
///
/// How a leftover daily save from an earlier day gets its name back: the save
/// keeps its date in its seed, and the game it was follows from the rotation.
/// Anything that does not read back as a real calendar date — a foreign seed in
/// the daily slot, a rolled-over 30th of February — is `null`, and a save
/// nobody can name is not worth asking about.
DailyPuzzle? dailyPuzzleForSeed(int seed) {
  final int year = seed ~/ 10000;
  final int month = (seed ~/ 100) % 100;
  final int day = seed % 100;
  if (year < 1 || year > 9999 || month < 1 || month > 12 || day < 1) {
    return null;
  }
  final DateTime date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return dailyPuzzleFor(date);
}
