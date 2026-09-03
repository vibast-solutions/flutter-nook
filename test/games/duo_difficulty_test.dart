import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/duo_board.dart';
import 'package:nook/chrome/completion_view.dart';
import 'package:nook/chrome/difficulty_page.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/duo/duo_difficulty.dart';
import 'package:nook/games/duo/duo_variant.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/nook_database.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/duo_fixture.dart';

/// Pumps the Duo difficulty screen straight onto its own page, with generation
/// stubbed so tapping a tier lands on a board at once.
Future<void> pumpDuoDifficulty(
  WidgetTester tester, {
  NookDatabase? database,
  TestClock? clock,
}) async {
  await setPhoneSurface(tester);
  await tester.pumpWidget(
    duoScope(
      puzzle: fixedDuoPuzzle(),
      database: database,
      clock: clock,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildNookTheme(NookColors.softClay),
        home: const DuoDifficultyPage(variant: DuoVariant.standard),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('choosing a Duo difficulty', () {
    testWidgets('offers all five tiers and starts the one tapped', (
      WidgetTester tester,
    ) async {
      await pumpDuoHome(tester);
      await tester.tap(find.text(en.duoTitle));
      await tester.pumpAndSettle();

      for (final PuzzleDifficulty tier in PuzzleDifficulty.values) {
        expect(
          find.byKey(DifficultyPage.tierKey(tier)),
          findsOneWidget,
          reason: 'Duo should offer ${tier.name}',
        );
      }

      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.medium)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DuoBoard), findsOneWidget);
      expect(
        find.text(en.gameSubtitle(en.gridSize(6), en.difficultyMedium)),
        findsOneWidget,
        reason: 'the puzzle should open at the tier that was tapped',
      );
    });

    testWidgets('nothing is locked — a new player can start on Fiendish', (
      WidgetTester tester,
    ) async {
      await pumpDuoHome(tester);
      await tester.tap(find.text(en.duoTitle));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.fiendish)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DuoBoard), findsOneWidget);
    });

    testWidgets('shows the best time and count per tier for game id duo', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await pumpDuoHome(tester, database: database, clock: clock);

      await tester.tap(find.text(en.duoTitle));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.gentle)),
      );
      await tester.pumpAndSettle();

      clock.advance(const Duration(minutes: 2));
      await solveDuo(tester, fixedDuoPuzzle());

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

    testWidgets(
      'opened directly, every tier is tappable and the board is not',
      (WidgetTester tester) async {
        await pumpDuoDifficulty(tester);

        expect(find.byType(DuoBoard), findsNothing);
        for (final PuzzleDifficulty tier in DuoVariant.standard.tiers) {
          final InkWell way = tester.widget<InkWell>(
            find.descendant(
              of: find.byKey(DifficultyPage.tierKey(tier)),
              matching: find.byType(InkWell),
            ),
          );
          expect(way.onTap, isNotNull, reason: '${tier.name} was not tappable');
        }
      },
    );
  });
}
