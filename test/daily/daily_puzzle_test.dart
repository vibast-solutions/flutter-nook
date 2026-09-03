import 'package:flutter_test/flutter_test.dart';
import 'package:nook/daily/daily_puzzle.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

void main() {
  group('the daily identity', () {
    test('2026-09-03 is a medium Duo from seed 20260903', () {
      // The worked example the rules were written against: a Thursday, 245
      // whole days after the anchor.
      final DailyPuzzle daily = dailyPuzzleFor(DateTime(2026, 9, 3, 14, 30));
      expect(daily.game, DailyGame.duo);
      expect(daily.difficulty, PuzzleDifficulty.medium);
      expect(daily.seed, 20260903);
      expect(daily.date, DateTime.utc(2026, 9, 3));
    });

    test('the anchor date is day zero, a Sudoku Classic', () {
      final DailyPuzzle daily = dailyPuzzleFor(DateTime(2026, 1, 1));
      expect(daily.game, DailyGame.sudokuClassic);
      expect(daily.seed, 20260101);
    });

    test('three consecutive dates cycle Classic, Stars, Duo', () {
      expect(
        dailyPuzzleFor(DateTime(2026, 9, 1)).game,
        DailyGame.sudokuClassic,
      );
      expect(dailyPuzzleFor(DateTime(2026, 9, 2)).game, DailyGame.stars);
      expect(dailyPuzzleFor(DateTime(2026, 9, 3)).game, DailyGame.duo);
    });

    test('the week ramps from a gentle Monday to a fiendish Sunday', () {
      // The week of Monday 2026-08-31 through Sunday 2026-09-06.
      const List<PuzzleDifficulty> week = <PuzzleDifficulty>[
        PuzzleDifficulty.gentle,
        PuzzleDifficulty.easy,
        PuzzleDifficulty.easy,
        PuzzleDifficulty.medium,
        PuzzleDifficulty.medium,
        PuzzleDifficulty.hard,
        PuzzleDifficulty.fiendish,
      ];
      for (int day = 0; day < week.length; day++) {
        final DailyPuzzle daily = dailyPuzzleFor(DateTime(2026, 8, 31 + day));
        expect(daily.date.weekday, day + 1);
        expect(
          daily.difficulty,
          week[day],
          reason: 'weekday ${day + 1} should be ${week[day].name}',
        );
      }
    });

    test('the time of day never changes the identity', () {
      final DailyPuzzle midnight = dailyPuzzleFor(DateTime(2026, 9, 3));
      final DailyPuzzle lastThing = dailyPuzzleFor(
        DateTime(2026, 9, 3, 23, 59, 59),
      );
      expect(lastThing.game, midnight.game);
      expect(lastThing.difficulty, midnight.difficulty);
      expect(lastThing.seed, midnight.seed);
    });

    test('a date before the anchor still has a stable identity', () {
      // A clock set back past day zero is odd, not an exception.
      final DailyPuzzle daily = dailyPuzzleFor(DateTime(2025, 12, 31));
      expect(daily.seed, 20251231);
      expect(DailyGame.values, contains(daily.game));
    });
  });

  group('reading a seed back as a date', () {
    test('a daily seed names its own day again', () {
      final DailyPuzzle? daily = dailyPuzzleForSeed(20260903);
      expect(daily, isNotNull);
      expect(daily!.game, DailyGame.duo);
      expect(daily.difficulty, PuzzleDifficulty.medium);
      expect(daily.date, DateTime.utc(2026, 9, 3));
    });

    test('a seed that is not a date names nothing', () {
      expect(dailyPuzzleForSeed(0), isNull);
      expect(dailyPuzzleForSeed(20261301), isNull, reason: 'month 13');
      expect(dailyPuzzleForSeed(20260230), isNull, reason: 'February 30th');
      expect(dailyPuzzleForSeed(20260900), isNull, reason: 'day 0');
      // A random 32-bit seed, the kind an ordinary puzzle carries.
      expect(dailyPuzzleForSeed(3123456789), isNull);
    });
  });
}
