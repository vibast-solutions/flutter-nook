import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';

void main() {
  late NookDatabase database;
  late GameStatsStore store;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    database = NookDatabase.memory();
    store = GameStatsStore(database);
  });

  tearDown(() => database.close());

  /// Finishes a puzzle of [gameId] at [difficulty] in [seconds].
  Future<SolveOutcome> solve(
    int seconds, {
    bool hinted = false,
    String gameId = 'sudoku-mini',
    String difficulty = 'gentle',
  }) {
    return store.record(
      gameId: gameId,
      difficulty: difficulty,
      time: Duration(seconds: seconds),
      hinted: hinted,
    );
  }

  /// The figures held for one game and tier, or `null` if it has none.
  Future<GameStats?> figures({
    String gameId = 'sudoku-mini',
    String difficulty = 'gentle',
  }) async {
    return statsFor(
      await store.watchAll().first,
      gameId: gameId,
      difficulty: difficulty,
    );
  }

  group('a tier nobody has finished', () {
    test('has no figures at all', () async {
      expect(await store.watchAll().first, isEmpty);
      expect(await figures(), isNull);
    });
  });

  group('solving without help', () {
    test('counts the puzzle and sets the time to beat', () async {
      final SolveOutcome outcome = await solve(180);

      expect(outcome.solved, 1);
      expect(outcome.time, const Duration(minutes: 3));
      expect(outcome.previousBest, isNull);
      expect(outcome.isPersonalBest, isTrue, reason: 'a first time is a best');
      expect(outcome.wasHinted, isFalse);

      final GameStats stats = (await figures())!;
      expect(stats.solved, 1);
      expect(stats.bestTime, const Duration(minutes: 3));
    });

    test('takes the best time down when it is beaten', () async {
      await solve(180);

      final SolveOutcome outcome = await solve(120);

      expect(outcome.solved, 2);
      expect(outcome.previousBest, const Duration(minutes: 3));
      expect(outcome.isPersonalBest, isTrue);
      expect((await figures())!.bestTime, const Duration(minutes: 2));
    });

    test('leaves it alone when the puzzle took longer', () async {
      await solve(120);

      final SolveOutcome outcome = await solve(300);

      expect(outcome.solved, 2);
      expect(outcome.previousBest, const Duration(minutes: 2));
      expect(outcome.isPersonalBest, isFalse);
      expect((await figures())!.bestTime, const Duration(minutes: 2));
    });

    test('does not call an equal time a new best', () async {
      // Equalling is not beating. Saying otherwise would show the celebration
      // for standing still.
      await solve(120);

      final SolveOutcome outcome = await solve(120);

      expect(outcome.isPersonalBest, isFalse);
      expect(outcome.previousBest, const Duration(minutes: 2));
    });
  });

  group('solving with a hint', () {
    test('counts the puzzle but never sets the best time', () async {
      await solve(300);

      final SolveOutcome outcome = await solve(60, hinted: true);

      expect(outcome.solved, 2, reason: 'a hinted puzzle is still solved');
      expect(outcome.time, const Duration(minutes: 1));
      expect(outcome.wasHinted, isTrue);
      expect(outcome.isPersonalBest, isFalse);
      expect(
        (await figures())!.bestTime,
        const Duration(minutes: 5),
        reason: 'a hint set the time to beat',
      );
    });

    test('leaves a tier with a count and no best time at all', () async {
      final SolveOutcome outcome = await solve(90, hinted: true);

      expect(outcome.solved, 1);
      expect(outcome.isPersonalBest, isFalse);
      expect(outcome.previousBest, isNull);

      final GameStats stats = (await figures())!;
      expect(stats.solved, 1);
      expect(
        stats.bestTime,
        isNull,
        reason: 'the only solve was helped, so there is no best yet',
      );
    });
  });

  group('the figures are kept apart', () {
    test('by tier, and by game', () async {
      await solve(60);
      await solve(300, difficulty: 'hard');
      await solve(30, gameId: 'sudoku-light');

      expect((await figures())!.bestTime, const Duration(minutes: 1));
      expect(
        (await figures(difficulty: 'hard'))!.bestTime,
        const Duration(minutes: 5),
      );
      expect(
        (await figures(gameId: 'sudoku-light'))!.bestTime,
        const Duration(seconds: 30),
      );
      expect(await store.watchAll().first, hasLength(3));
    });

    test('so one tier cannot be beaten by another', () async {
      await solve(300, difficulty: 'hard');

      final SolveOutcome outcome = await solve(60);

      expect(
        outcome.previousBest,
        isNull,
        reason: 'a Hard time was offered as the Gentle one to beat',
      );
      expect(outcome.solved, 1);
    });
  });

  test('the figures are watched, not fetched once', () async {
    // A screen holds this stream open for as long as it is on screen, so a
    // puzzle finished while it is there has to reach it without being asked
    // for.
    final List<List<GameStats>> seen = <List<GameStats>>[];
    final StreamSubscription<List<GameStats>> subscription = store
        .watchAll()
        .listen(seen.add);
    addTearDown(subscription.cancel);
    await pumpEventQueue();

    expect(seen.single, isEmpty, reason: 'the first reading is what is there');

    await solve(60);
    await pumpEventQueue();

    expect(seen.last.single.solved, 1);
  });
}
