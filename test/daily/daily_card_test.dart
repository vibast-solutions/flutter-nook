import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/duo_board.dart';
import 'package:nook/chrome/completion_view.dart';
import 'package:nook/chrome/continue_card.dart';
import 'package:nook/chrome/discard_dialog.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/daily/daily_card.dart';
import 'package:nook/daily/daily_launch.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/duo/duo_controller.dart';
import 'package:nook/games/duo/duo_naming.dart';
import 'package:nook/games/duo/duo_state.dart';
import 'package:nook/games/duo/duo_variant.dart';
import 'package:nook/home/home_screen.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/duo_fixture.dart';

/// The card on the home screen, exercised on 2026-09-03 — a Thursday whose
/// daily is a medium Duo from seed 20260903.
///
/// Two fixed puzzles stand in for the two sources: the daily's, generated at
/// the daily seed so its save reads back as today's, and a different one behind
/// the ordinary source, so a board can always be asked which source it came
/// from.
final DateTime duoDailyMorning = DateTime.utc(2026, 9, 3, 9);
final DateTime duoDailyDate = DateTime.utc(2026, 9, 3);

DuoPuzzle dailyDuoPuzzle() => DuoGenerator(DuoSpec.standard).generate(20260903);

DuoPuzzle ordinaryDuoPuzzle() => DuoGenerator(DuoSpec.standard).generate(2027);

/// The player cells of [puzzle], in reading order.
List<int> freeCellsOf(DuoPuzzle puzzle) => <int>[
  for (int index = 0; index < puzzle.spec.cellCount; index++)
    if (!puzzle.isGiven(index)) index,
];

/// The streak figure drawn on the daily card, or `null` if the card is absent.
String? streakOnCard(WidgetTester tester) {
  final Finder figure = find.byKey(dailyStreakKey);
  if (figure.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<Text>(figure).data;
}

/// The figure printed on a completion card [key].
String figureOn(WidgetTester tester, Key key) {
  return tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .last
      .data!;
}

/// Pumps the home screen on the Duo daily's day, with both sources fixed.
Future<void> pumpDailyHome(
  WidgetTester tester, {
  NookDatabase? database,
  TestClock? clock,
}) async {
  await setPhoneSurface(tester);
  final DuoPuzzle daily = dailyDuoPuzzle();
  final DuoPuzzle ordinary = ordinaryDuoPuzzle();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dailyDuoSourceProvider.overrideWithValue(
          (DuoSpec spec, PuzzleDifficulty tier, int seed) async => daily,
        ),
        duoPuzzleSourceProvider.overrideWithValue(
          (DuoSpec spec, PuzzleDifficulty tier, int seed) async => ordinary,
        ),
        nookDatabaseProvider.overrideWithValue(database ?? memoryDatabase()),
        nowProvider.overrideWithValue(
          (clock ?? TestClock(duoDailyMorning)).call,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildNookTheme(NookColors.softClay),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the daily card', () {
    testWidgets('shows today: the game, the date and the ramp tier', (
      WidgetTester tester,
    ) async {
      await pumpDailyHome(tester);

      expect(find.text(en.homeDaily), findsOneWidget);
      expect(find.byKey(dailyCardKey), findsOneWidget);
      // Twice: once on its own row, once as today's puzzle.
      expect(find.text(en.duoTitle), findsNWidgets(2));
      expect(
        find.text(en.dailyDetails(duoDailyDate, en.difficultyMedium)),
        findsOneWidget,
      );
    });

    testWidgets('starts today\'s puzzle from the daily source, at its tier', (
      WidgetTester tester,
    ) async {
      await pumpDailyHome(tester);

      await tester.tap(find.byKey(dailyCardKey));
      await tester.pumpAndSettle();

      // The board is the daily seed's, not the ordinary source's — which is
      // what proves the pack-first wiring is bypassed.
      final DuoBoard board = tester.widget(find.byType(DuoBoard));
      expect(board.game.puzzle.seed, 20260903);
      expect(
        find.text(
          en.gameSubtitle(
            DuoVariant.standard.sizeLabel(en),
            en.difficultyMedium,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps its save in the daily slot, not Duo\'s', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpDailyHome(tester, database: database);

      await tester.tap(find.byKey(dailyCardKey));
      await tester.pumpAndSettle();
      await tapDuoCell(tester, freeCellsOf(dailyDuoPuzzle()).first);
      await tester.pumpAndSettle();

      final SavedGame? daily = await storedSave(tester, database, dailySlotId);
      expect(daily, isNotNull);
      expect(daily!.seed, 20260903);
      expect(
        await storedSave(tester, database, DuoVariant.standard.id),
        isNull,
      );
    });

    testWidgets('is never offered by the Continue card', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database)
          .save(partPlayedDuoSave(puzzle: dailyDuoPuzzle(), slot: dailySlotId));

      await pumpDailyHome(tester, database: database);

      expect(find.byKey(ContinueCard.cardKey), findsNothing);
      expect(find.text(en.homeContinue), findsNothing);
    });

    testWidgets('leaves the Continue card to the ordinary game', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final SavedGameStore store = SavedGameStore(database);
      // An ordinary Duo left an hour before today's daily: the daily row is
      // the more recent, and the Continue card must skip over it.
      await store.save(partPlayedDuoSave(at: DateTime.utc(2026, 9, 3, 8)));
      await store.save(
        partPlayedDuoSave(puzzle: dailyDuoPuzzle(), slot: dailySlotId),
      );

      await pumpDailyHome(tester, database: database);

      expect(find.byKey(ContinueCard.cardKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(ContinueCard.cardKey),
          matching: find.text(en.duoTitle),
        ),
        findsOneWidget,
      );
    });

    testWidgets('says today\'s puzzle is under way, and resumes it exactly', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final SavedGame saved = partPlayedDuoSave(
        puzzle: dailyDuoPuzzle(),
        slot: dailySlotId,
      );
      await SavedGameStore(database).save(saved);

      await pumpDailyHome(tester, database: database);

      final int percent = (saved.progress * 100).round();
      expect(
        find.text(en.dailyDetailsProgress(duoDailyDate, '01:15', percent)),
        findsOneWidget,
      );

      await tester.tap(find.byKey(dailyCardKey));
      await tester.pumpAndSettle();

      // The symbols are back where they were left, and the clock carries on
      // from where it stopped.
      final List<int> free = freeCellsOf(dailyDuoPuzzle());
      expect(duoCellAt(tester, free[0]), DuoCell.circle);
      expect(duoCellAt(tester, free[1]), DuoCell.square);
      expect(find.text('01:15'), findsOneWidget);
    });

    testWidgets('asks before replacing an earlier day\'s unfinished daily', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      // Monday 2026-08-31 was also a Duo day; its daily was left half-done.
      await SavedGameStore(database).save(
        partPlayedDuoSave(
          puzzle: DuoGenerator(DuoSpec.standard).generate(20260831),
          slot: dailySlotId,
        ),
      );

      await pumpDailyHome(tester, database: database);

      // Today's card reads unstarted — the leftover is not today's puzzle.
      expect(
        find.text(en.dailyDetails(duoDailyDate, en.difficultyMedium)),
        findsOneWidget,
      );

      // Keeping it opens nothing and loses nothing.
      await tester.tap(find.byKey(dailyCardKey));
      await tester.pumpAndSettle();
      expect(find.byKey(DiscardDialog.keepKey), findsOneWidget);
      await tester.tap(find.byKey(DiscardDialog.keepKey));
      await tester.pumpAndSettle();
      expect(find.byType(DuoBoard), findsNothing);
      final SavedGame? kept = await storedSave(tester, database, dailySlotId);
      expect(kept!.seed, 20260831);

      // Letting it go starts today's, and today's board takes the slot.
      await tester.tap(find.byKey(dailyCardKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DiscardDialog.confirmKey));
      await tester.pumpAndSettle();
      expect(find.byType(DuoBoard), findsOneWidget);
      final SavedGame? replaced = await storedSave(
        tester,
        database,
        dailySlotId,
      );
      expect(replaced!.seed, 20260903);
    });

    testWidgets(
      'a solved daily counts in Duo\'s own statistics and can set a best',
      (WidgetTester tester) async {
        final NookDatabase database = memoryDatabase();
        await pumpDailyHome(tester, database: database);
        await tester.tap(find.byKey(dailyCardKey));
        await tester.pumpAndSettle();

        await solveDuo(tester, dailyDuoPuzzle());

        expect(find.text(en.gameSolved), findsOneWidget);
        // Hint-free, so the daily is allowed to be the personal best.
        expect(find.byKey(GameCompletionView.personalBestKey), findsOneWidget);
        final List<GameStats> stats = await storedStats(tester, database);
        expect(stats, hasLength(1));
        expect(stats.first.gameId, DuoVariant.standard.id);
        expect(stats.first.difficulty, PuzzleDifficulty.medium.name);
        expect(stats.first.solved, 1);
        expect(stats.first.bestTime, isNotNull);
        // Solving discards the daily save.
        expect(await storedSave(tester, database, dailySlotId), isNull);
      },
    );

    testWidgets('another puzzle after the daily is an ordinary one', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpDailyHome(tester, database: database);
      await tester.tap(find.byKey(dailyCardKey));
      await tester.pumpAndSettle();
      await solveDuo(tester, dailyDuoPuzzle());

      await tester.tap(find.byKey(GameCompletionView.anotherKey));
      await tester.pumpAndSettle();

      // The ordinary source's board, not today's again.
      final DuoBoard board = tester.widget(find.byType(DuoBoard));
      expect(board.game.puzzle.seed, 2027);

      // And it saves into Duo's own slot; the daily slot stays empty.
      await tapDuoCell(tester, freeCellsOf(ordinaryDuoPuzzle()).first);
      await tester.pumpAndSettle();
      expect(
        await storedSave(tester, database, DuoVariant.standard.id),
        isNotNull,
      );
      expect(await storedSave(tester, database, dailySlotId), isNull);
    });
  });

  group('the streak', () {
    /// A daily solved on its own day [d] in September 2026, to build up a run
    /// before the card is pumped.
    Future<void> solvedOn(NookDatabase database, int d) {
      return DailyStore(database).recordSolve(
        date: DateTime.utc(2026, 9, d),
        today: DateTime.utc(2026, 9, d),
        gameId: DuoVariant.duoId,
        difficulty: PuzzleDifficulty.medium.name,
      );
    }

    testWidgets('the daily\'s completion shows the streak it just set', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpDailyHome(tester, database: database);
      await tester.tap(find.byKey(dailyCardKey));
      await tester.pumpAndSettle();

      await solveDuo(tester, dailyDuoPuzzle());

      // The finished-puzzle screen's third card is the streak, and solving
      // today's daily has just made it one.
      expect(figureOn(tester, GameCompletionView.streakKey), '1');
    });

    testWidgets('shows the running streak before today is played', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      // A two-day run ending yesterday; today is not started.
      await solvedOn(database, 1);
      await solvedOn(database, 2);

      await pumpDailyHome(tester, database: database);

      // The card reads unstarted, and the streak stands at two.
      expect(
        find.text(en.dailyDetails(duoDailyDate, en.difficultyMedium)),
        findsOneWidget,
      );
      expect(streakOnCard(tester), '2');

      // Yesterday's run does not lock today's puzzle: the card still opens it.
      await tester.tap(find.byKey(dailyCardKey));
      await tester.pumpAndSettle();
      expect(find.byType(DuoBoard), findsOneWidget);
    });

    testWidgets('stays on the card while today is under way', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await solvedOn(database, 2);
      // Today's daily, left half-played.
      final SavedGame saved = partPlayedDuoSave(
        puzzle: dailyDuoPuzzle(),
        slot: dailySlotId,
      );
      await SavedGameStore(database).save(saved);

      await pumpDailyHome(tester, database: database);

      final int percent = (saved.progress * 100).round();
      expect(
        find.text(en.dailyDetailsProgress(duoDailyDate, '01:15', percent)),
        findsOneWidget,
      );
      expect(streakOnCard(tester), '1');
    });

    testWidgets('turns the card informational once today is solved', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpDailyHome(tester, database: database);
      await tester.tap(find.byKey(dailyCardKey));
      await tester.pumpAndSettle();
      await solveDuo(tester, dailyDuoPuzzle());

      await tester.tap(find.byKey(GameCompletionView.homeKey));
      await tester.pumpAndSettle();

      // Back home, the card reads solved and carries the streak the solve set.
      expect(find.text(en.dailySolvedDetails(duoDailyDate)), findsOneWidget);
      expect(streakOnCard(tester), '1');

      // It is no longer a button: there is nothing left to open, and tapping it
      // opens nothing.
      await tester.tap(find.byKey(dailyCardKey));
      await tester.pumpAndSettle();
      expect(find.byType(DuoBoard), findsNothing);
    });

    testWidgets('reads out the solved card and its streak', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final NookDatabase database = memoryDatabase();
        await pumpDailyHome(tester, database: database);
        await tester.tap(find.byKey(dailyCardKey));
        await tester.pumpAndSettle();
        await solveDuo(tester, dailyDuoPuzzle());

        await tester.tap(find.byKey(GameCompletionView.homeKey));
        await tester.pumpAndSettle();

        // The card's label reads as one sentence and carries the streak the
        // solve set.
        expect(
          find.bySemanticsLabel(
            en.dailyLabelSolved(en.duoTitle, duoDailyDate, 1),
          ),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });
  });
}
