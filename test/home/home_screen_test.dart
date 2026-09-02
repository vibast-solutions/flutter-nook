import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/sudoku/sudoku_controller.dart';
import 'package:nook/games/sudoku/sudoku_naming.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/home/home_screen.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

Future<void> pumpHome(
  WidgetTester tester, {
  SudokuVariant variant = SudokuVariant.mini,
}) async {
  await setPhoneSurface(tester);
  final SudokuPuzzle fixed = fixedPuzzle(variant);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sudokuPuzzleSourceProvider.overrideWithValue(
          (SudokuSpec spec, SudokuDifficulty tier, int seed) async => fixed,
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
  group('the home screen', () {
    testWidgets('lists every game, playable or not', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      expect(find.text('Nook'), findsOneWidget);
      expect(find.text('Sudoku Classic'), findsOneWidget);
      expect(find.text('Sudoku Light'), findsOneWidget);
      expect(find.text('Sudoku Mini'), findsOneWidget);
      expect(find.text('Stars'), findsOneWidget);
      expect(find.text('Duo'), findsOneWidget);
    });

    testWidgets('says plainly what Nook does not do', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      expect(
        find.text('No ads. No tracking. No account. Ever.'),
        findsOneWidget,
      );
    });

    testWidgets('marks the games that are not built yet', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      // Every Sudoku is playable now; only Stars and Duo are still to come.
      expect(find.textContaining('coming soon'), findsNWidgets(2));
      expect(find.text('9x9 · the full grid'), findsOneWidget);
      expect(find.text('6x6 · a gentler grid'), findsOneWidget);
      expect(find.text('4x4 · a few quiet minutes'), findsOneWidget);
    });

    for (final SudokuVariant variant in allVariants) {
      testWidgets('opens the difficulties for ${variant.title(en)}', (
        WidgetTester tester,
      ) async {
        await pumpHome(tester, variant: variant);

        await tester.tap(find.text(variant.title(en)));
        await tester.pumpAndSettle();

        // A game leads to its difficulties, not straight onto a board: the
        // player says how hard they want to think before a puzzle is made.
        expect(find.byType(SudokuBoard), findsNothing);
        expect(find.text('START A NEW ONE'), findsOneWidget);
        for (final SudokuDifficulty tier in variant.tiers) {
          expect(find.text(tier.label(en)), findsOneWidget);
        }
      });

      testWidgets('reaches a ${variant.title(en)} board through a tier', (
        WidgetTester tester,
      ) async {
        await pumpHome(tester, variant: variant);

        await tester.tap(find.text(variant.title(en)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(SudokuDifficulty.gentle.label(en)));
        await tester.pumpAndSettle();

        expect(find.byType(SudokuBoard), findsOneWidget);
        expect(
          find.text(
            en.gameSubtitle(
              variant.sizeLabel(en),
              SudokuDifficulty.gentle.label(en),
            ),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('does nothing when a game that is not ready is tapped', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('Stars'));
      await tester.pumpAndSettle();

      expect(find.text('START A NEW ONE'), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('every screen can be backed out of', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('Sudoku Mini'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(SudokuDifficulty.gentle.label(en)));
      await tester.pumpAndSettle();
      expect(find.byType(SudokuBoard), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back to the game list'));
      await tester.pumpAndSettle();
      expect(find.byType(SudokuBoard), findsNothing);
      expect(find.text('START A NEW ONE'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back to the game list'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
