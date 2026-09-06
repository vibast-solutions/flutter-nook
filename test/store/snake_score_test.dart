import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/snake_score.dart';

/// A database in memory that goes away with the test.
NookDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final NookDatabase database = NookDatabase.memory();
  addTearDown(database.close);
  return database;
}

/// A stand-in instant; the store keeps a timestamp but v1 never reads it, so any
/// one will do.
DateTime at(int minute) => DateTime.utc(2026, 9, 6, 12, minute);

void main() {
  group('SnakeScoreStore', () {
    test('a level with no run has no best', () async {
      final SnakeScoreStore store = SnakeScoreStore(memoryDatabase());
      expect(await store.bestFor(3), isNull);
    });

    test('the first run at a level always sets a best', () async {
      final SnakeScoreStore store = SnakeScoreStore(memoryDatabase());

      final SnakeScoreOutcome outcome = await store.record(
        level: 2,
        score: 7,
        at: at(0),
      );

      // Any score beats no score at all.
      expect(outcome.isNewBest, isTrue);
      expect(outcome.previousBest, isNull);
      expect(outcome.best, 7);
      expect(await store.bestFor(2), 7);
    });

    test('a higher score beats the stored best and replaces it', () async {
      final SnakeScoreStore store = SnakeScoreStore(memoryDatabase());
      await store.record(level: 2, score: 7, at: at(0));

      final SnakeScoreOutcome outcome = await store.record(
        level: 2,
        score: 11,
        at: at(1),
      );

      expect(outcome.isNewBest, isTrue);
      expect(outcome.previousBest, 7);
      expect(outcome.best, 11);
      expect(await store.bestFor(2), 11);
    });

    test('a lower score leaves the best standing', () async {
      final SnakeScoreStore store = SnakeScoreStore(memoryDatabase());
      await store.record(level: 2, score: 11, at: at(0));

      final SnakeScoreOutcome outcome = await store.record(
        level: 2,
        score: 4,
        at: at(1),
      );

      expect(outcome.isNewBest, isFalse);
      expect(outcome.previousBest, 11);
      // The best the card reports is the one that still stands, not this run.
      expect(outcome.best, 11);
      expect(await store.bestFor(2), 11);
    });

    test('an equal score does not count as a new best', () async {
      final SnakeScoreStore store = SnakeScoreStore(memoryDatabase());
      await store.record(level: 2, score: 9, at: at(0));

      final SnakeScoreOutcome outcome = await store.record(
        level: 2,
        score: 9,
        at: at(1),
      );

      // Matching the record is not beating it.
      expect(outcome.isNewBest, isFalse);
      expect(outcome.best, 9);
    });

    test('each speed keeps its own best', () async {
      final SnakeScoreStore store = SnakeScoreStore(memoryDatabase());

      await store.record(level: 1, score: 5, at: at(0));
      await store.record(level: 5, score: 20, at: at(1));

      expect(await store.bestFor(1), 5);
      expect(await store.bestFor(5), 20);
      expect(await store.bestFor(3), isNull);
      expect(await store.watchBests().first, <int, int>{1: 5, 5: 20});
    });

    test('the best persists across a restart — a new store on the same database', () async {
      // A restart is a fresh store reading the same file. Recording through one
      // and reading back through another proves the best is on disk, not in the
      // store object.
      final NookDatabase database = memoryDatabase();
      await SnakeScoreStore(database).record(level: 4, score: 15, at: at(0));

      final SnakeScoreStore reopened = SnakeScoreStore(database);
      expect(await reopened.bestFor(4), 15);
    });
  });
}
