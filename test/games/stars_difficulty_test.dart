import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/chrome/completion_view.dart';
import 'package:nook/chrome/difficulty_page.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/store/nook_database.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/stars_fixture.dart';

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
}
