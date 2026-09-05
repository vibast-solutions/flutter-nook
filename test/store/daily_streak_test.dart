import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/store/daily_streak.dart';
import 'package:nook/store/nook_database.dart';

void main() {
  late NookDatabase database;
  late DailyStore store;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    database = NookDatabase.memory();
    store = DailyStore(database);
  });

  tearDown(() => database.close());

  /// A day in September 2026, held as a UTC midnight the way the daily's own
  /// date is.
  DateTime day(int d) => DateTime.utc(2026, 9, d);

  /// Records the daily for day [d] finished on its own day — the ordinary case,
  /// where solving counts towards the streak.
  Future<void> solveOn(
    int d, {
    String gameId = 'sudoku-classic',
    String difficulty = 'gentle',
  }) {
    return store.recordSolve(
      date: day(d),
      today: day(d),
      gameId: gameId,
      difficulty: difficulty,
    );
  }

  /// The streak as it reads when the clock says day [d].
  Future<DailyStreakStatus> readOn(int d) => store.watch(() => day(d)).first;

  /// Every solved-day date the store holds, as its `yyyy-MM-dd` keys.
  Future<Set<String>> solvedDates() async {
    final List<DailySolveRow> rows = await database
        .select(database.dailySolves)
        .get();
    return rows.map((DailySolveRow row) => row.date).toSet();
  }

  group('a player who has solved no daily', () {
    test('has a streak of zero, and today unsolved', () async {
      final DailyStreakStatus status = await readOn(1);
      expect(status.streak, 0);
      expect(status.solvedToday, isFalse);
    });
  });

  group('advancing the streak', () {
    test('a first solve makes it one', () async {
      await solveOn(1);

      final DailyStreakStatus status = await readOn(1);
      expect(status.streak, 1);
      expect(status.solvedToday, isTrue);
    });

    test('a consecutive day adds one', () async {
      await solveOn(1);
      await solveOn(2);

      expect((await readOn(2)).streak, 2);
    });

    test('solving the same day again changes nothing', () async {
      await solveOn(1);
      await solveOn(1);

      expect((await readOn(1)).streak, 1);
      expect(await solvedDates(), <String>{'2026-09-01'});
    });

    test('a skipped day starts the run over at one', () async {
      await solveOn(1);
      // Day 2 goes unsolved.
      await solveOn(3);

      expect((await readOn(3)).streak, 1);
    });
  });

  group('reading the streak against the clock', () {
    test('keeps its full count while the last solve was yesterday', () async {
      await solveOn(1);
      await solveOn(2);

      // Nothing solved on day 3 yet: the run is not broken, because the day is
      // not over. Yesterday still counts.
      final DailyStreakStatus status = await readOn(3);
      expect(status.streak, 2);
      expect(status.solvedToday, isFalse);
    });

    test('falls to zero once a whole day has passed unsolved', () async {
      await solveOn(1);

      // Read on day 3: the last solve was day 1, which is neither today nor
      // yesterday, so the streak has been broken — with nothing having run to
      // break it.
      expect((await readOn(3)).streak, 0);
    });
  });

  group('a stale daily — one finished after its own day', () {
    test('records its day but leaves the streak untouched', () async {
      // Day 2's daily was solved on its day: streak of one, last day is day 2.
      await solveOn(2, gameId: 'sudoku-classic');
      // Day 1's daily, opened before midnight and finished on day 3. It is a
      // solved day for the calendar, but it is not today's, so it neither
      // advances nor repairs the run.
      await store.recordSolve(
        date: day(1),
        today: day(3),
        gameId: 'stars',
        difficulty: 'easy',
      );

      // The streak is exactly what day 2's solve left it: read on day 3, day 2
      // is yesterday, so it still shows its full one.
      final DailyStreakStatus status = await readOn(3);
      expect(status.streak, 1);
      expect(status.solvedToday, isFalse);

      // Both days are on record for a future calendar to light up.
      expect(await solvedDates(), <String>{'2026-09-01', '2026-09-02'});
    });
  });

  test('a solved day keeps the game and tier it was played at', () async {
    await store.recordSolve(
      date: day(1),
      today: day(1),
      gameId: 'duo',
      difficulty: 'medium',
    );

    final DailySolveRow row =
        (await database.select(database.dailySolves).get()).single;
    expect(row.date, '2026-09-01');
    expect(row.gameId, 'duo');
    expect(row.difficulty, 'medium');
  });
}
