import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/chrome/completion_view.dart';
import 'package:nook/chrome/continue_card.dart';
import 'package:nook/chrome/difficulty_page.dart';
import 'package:nook/chrome/discard_dialog.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/stars/stars_difficulty.dart';
import 'package:nook/games/stars/stars_state.dart';
import 'package:nook/games/stars/stars_variant.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/stars_fixture.dart';

/// Pumps the Stars difficulty screen straight onto its own page, with
/// generation stubbed so tapping a tier lands on a board at once.
Future<void> pumpStarsDifficulty(
  WidgetTester tester, {
  NookDatabase? database,
  TestClock? clock,
}) async {
  await setPhoneSurface(tester);
  await tester.pumpWidget(
    starsScope(
      puzzle: fixedStarsPuzzle(),
      database: database,
      clock: clock,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildNookTheme(NookColors.softClay),
        home: const StarsDifficultyPage(variant: StarsVariant.standard),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('choosing a Stars difficulty', () {
    testWidgets('offers all five tiers and starts the one tapped', (
      WidgetTester tester,
    ) async {
      await pumpStarsHome(tester);
      await tester.tap(find.text(en.starsTitle));
      await tester.pumpAndSettle();

      for (final PuzzleDifficulty tier in PuzzleDifficulty.values) {
        expect(
          find.byKey(DifficultyPage.tierKey(tier)),
          findsOneWidget,
          reason: 'Stars should offer ${tier.name}',
        );
      }

      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.medium)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StarsBoard), findsOneWidget);
      expect(
        find.text(en.gameSubtitle(en.gridSize(8), en.difficultyMedium)),
        findsOneWidget,
        reason: 'the puzzle should open at the tier that was tapped',
      );
    });

    testWidgets('nothing is locked — a new player can start on Fiendish', (
      WidgetTester tester,
    ) async {
      await pumpStarsHome(tester);
      await tester.tap(find.text(en.starsTitle));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.fiendish)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(StarsBoard), findsOneWidget);
    });

    testWidgets('shows the best time and count per tier for game id stars', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await pumpStarsHome(tester, database: database, clock: clock);

      await tester.tap(find.text(en.starsTitle));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.gentle)),
      );
      await tester.pumpAndSettle();

      clock.advance(const Duration(minutes: 2));
      await solveStars(tester, fixedStarsPuzzle());

      // Back out of the finished screen to this game's difficulties.
      await tester.tap(find.byKey(GameCompletionView.closeKey));
      await tester.pumpAndSettle();

      expect(
        find.text(
          en.difficultyTierBest(clockReading(const Duration(minutes: 2)), 1),
        ),
        findsOneWidget,
        reason: 'the Gentle row should show the time just set, and the count',
      );
    });
  });

  group('a Stars puzzle already in progress', () {
    /// The difficulty screen with [save] already on disk.
    Future<NookDatabase> pumpWithSave(WidgetTester tester) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database).save(partPlayedStarsSave());
      await pumpStarsDifficulty(tester, database: database);
      return database;
    }

    testWidgets('is offered before a new one', (WidgetTester tester) async {
      await pumpWithSave(tester);

      expect(find.text(en.difficultyInProgress), findsOneWidget);
      expect(find.byKey(ContinueCard.cardKey), findsOneWidget);
    });

    testWidgets('carries on exactly where it was', (WidgetTester tester) async {
      await pumpWithSave(tester);

      await tester.tap(find.byKey(ContinueCard.cardKey));
      await tester.pumpAndSettle();

      expect(find.byType(StarsBoard), findsOneWidget);
      expect(starMarkAt(tester, 0), StarsMark.star);
      expect(find.text('01:15'), findsOneWidget);
    });

    testWidgets('asks before a new puzzle throws it away', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = await pumpWithSave(tester);

      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.gentle)),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.discardTitle), findsOneWidget);
      expect(find.byType(StarsBoard), findsNothing);
      expect(
        await storedSave(tester, database, StarsVariant.starsId),
        isNotNull,
        reason: 'asking is not the same as doing',
      );
    });

    testWidgets('keeps it when the player says to keep playing', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = await pumpWithSave(tester);

      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.gentle)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DiscardDialog.keepKey));
      await tester.pumpAndSettle();

      expect(find.byType(StarsBoard), findsNothing);
      final SavedGame? kept = await storedSave(
        tester,
        database,
        StarsVariant.starsId,
      );
      expect(kept, isNotNull);
      expect(kept!.cells[0], StarsMark.star.index);
      expect(find.byKey(ContinueCard.cardKey), findsOneWidget);
    });

    testWidgets('throws it away only when the player confirms', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = await pumpWithSave(tester);

      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.gentle)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DiscardDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(find.byType(StarsBoard), findsOneWidget);
      // The new puzzle saves itself as soon as it exists, so what must be gone
      // is the old board rather than the row: a fresh board has no stars on it.
      final SavedGame? replacement = await storedSave(
        tester,
        database,
        StarsVariant.starsId,
      );
      expect(
        replacement?.cells.contains(StarsMark.star.index) ?? false,
        isFalse,
      );
      expect(replacement?.elapsed ?? Duration.zero, Duration.zero);
    });

    testWidgets('asks nothing when there is nothing to lose', (
      WidgetTester tester,
    ) async {
      await pumpStarsDifficulty(tester, database: memoryDatabase());

      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.gentle)),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.discardTitle), findsNothing);
      expect(find.byType(StarsBoard), findsOneWidget);
    });
  });
}
