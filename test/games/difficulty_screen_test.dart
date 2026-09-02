import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/sudoku/difficulty_screen.dart';
import 'package:nook/games/sudoku/sudoku_controller.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

/// Pumps the difficulty screen for [variant], with generation stubbed out so
/// tapping a tier lands on a board immediately.
Future<void> pumpDifficulty(
  WidgetTester tester, {
  SudokuVariant variant = SudokuVariant.classic,
  double width = 400,
}) async {
  await setPhoneSurface(tester, width: width);
  final SudokuPuzzle fixed = fixedPuzzle(variant);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sudokuPuzzleSourceProvider.overrideWithValue(
          (SudokuSpec spec, SudokuDifficulty tier, int seed) async => fixed,
        ),
      ],
      child: MaterialApp(
        theme: buildNookTheme(NookColors.softClay),
        home: SudokuDifficultyPage(variant: variant),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// How many bars of [difficulty]'s meter are lit.
int filledRungs(WidgetTester tester, SudokuDifficulty difficulty) {
  final Iterable<Container> bars = tester.widgetList<Container>(
    find.descendant(
      of: find.byKey(SudokuDifficultyPage.tierKey(difficulty)),
      matching: find.byType(Container),
    ),
  );
  return bars
      .where(
        (Container bar) =>
            (bar.decoration as BoxDecoration?)?.color ==
            NookColors.softClay.clay,
      )
      .length;
}

void main() {
  group('the difficulty screen offers what the grid can make', () {
    for (final SudokuVariant variant in allVariants) {
      testWidgets('${variant.title} lists exactly its own tiers', (
        WidgetTester tester,
      ) async {
        await pumpDifficulty(tester, variant: variant);

        expect(find.text(variant.title), findsOneWidget);
        for (final SudokuDifficulty tier in SudokuDifficulty.values) {
          final bool offered = variant.tiers.contains(tier);
          expect(
            find.byKey(SudokuDifficultyPage.tierKey(tier)),
            offered ? findsOneWidget : findsNothing,
            reason: offered
                ? '${tier.label} should be offered on ${variant.title}'
                : '${tier.label} cannot be generated for ${variant.title}, '
                      'so offering it would be a button that lies',
          );
        }
      });

      testWidgets('${variant.title} locks nothing', (
        WidgetTester tester,
      ) async {
        // Tiers are never gated — not behind progress, not behind payment. A
        // brand-new player can start on the hardest thing the grid makes.
        await pumpDifficulty(tester, variant: variant);

        for (final SudokuDifficulty tier in variant.tiers) {
          final InkWell way = tester.widget<InkWell>(
            find.descendant(
              of: find.byKey(SudokuDifficultyPage.tierKey(tier)),
              matching: find.byType(InkWell),
            ),
          );
          expect(
            way.onTap,
            isNotNull,
            reason: '${tier.label} was not tappable',
          );
        }
      });

      testWidgets('${variant.title} keeps its rows tappable at 320', (
        WidgetTester tester,
      ) async {
        await pumpDifficulty(
          tester,
          variant: variant,
          width: kSmallestSupportedWidth,
        );

        for (final SudokuDifficulty tier in variant.tiers) {
          final Size row = tester.getSize(
            find.byKey(SudokuDifficultyPage.tierKey(tier)),
          );
          expect(
            row.height,
            greaterThanOrEqualTo(kMinTapTarget),
            reason: '${tier.label} is too short to hit comfortably',
          );
        }
        final Size back = tester.getSize(
          find.bySemanticsLabel('Back to the game list'),
        );
        expect(back.height, greaterThanOrEqualTo(kMinTapTarget));
        expect(back.width, greaterThanOrEqualTo(kMinTapTarget));
      });
    }

    testWidgets('a grid with a short ladder says why', (
      WidgetTester tester,
    ) async {
      await pumpDifficulty(tester, variant: SudokuVariant.mini);
      expect(find.textContaining('read on its own'), findsOneWidget);

      await pumpDifficulty(tester, variant: SudokuVariant.light);
      expect(find.textContaining('middle of the ladder'), findsOneWidget);
    });

    testWidgets('a grid with the whole ladder explains nothing', (
      WidgetTester tester,
    ) async {
      await pumpDifficulty(tester, variant: SudokuVariant.classic);

      expect(find.textContaining('read on its own'), findsNothing);
      expect(find.textContaining('middle of the ladder'), findsNothing);
    });
  });

  group('the difficulty screen reads the way the designs do', () {
    testWidgets('the meter climbs a rung per tier', (
      WidgetTester tester,
    ) async {
      await pumpDifficulty(tester);

      expect(filledRungs(tester, SudokuDifficulty.gentle), 1);
      expect(filledRungs(tester, SudokuDifficulty.easy), 2);
      expect(filledRungs(tester, SudokuDifficulty.medium), 3);
      expect(filledRungs(tester, SudokuDifficulty.hard), 4);
    });

    testWidgets('Fiendish says what it needs instead of showing a meter', (
      WidgetTester tester,
    ) async {
      await pumpDifficulty(tester);

      expect(
        find.descendant(
          of: find.byKey(
            SudokuDifficultyPage.tierKey(SudokuDifficulty.fiendish),
          ),
          matching: find.text('needs notes'),
        ),
        findsOneWidget,
      );
      expect(filledRungs(tester, SudokuDifficulty.fiendish), 0);
    });

    testWidgets('every tier says what it feels like to play', (
      WidgetTester tester,
    ) async {
      await pumpDifficulty(tester);

      expect(find.text('One cell at a time'), findsOneWidget);
      expect(find.text('Chains across the grid'), findsOneWidget);
    });

    testWidgets('the promise is stated on the way in', (
      WidgetTester tester,
    ) async {
      await pumpDifficulty(tester);

      expect(find.textContaining('exactly one solution'), findsOneWidget);
      expect(find.textContaining('never need to guess'), findsOneWidget);
    });

    testWidgets('a screen reader gets the tier and what it asks of you', (
      WidgetTester tester,
    ) async {
      await pumpDifficulty(tester);

      expect(
        find.bySemanticsLabel('Gentle. One cell at a time'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Fiendish. Chains across the grid. Needs notes'),
        findsOneWidget,
      );
    });
  });

  group('picking a tier', () {
    testWidgets('starts a game at the tier that was tapped', (
      WidgetTester tester,
    ) async {
      await pumpDifficulty(tester);

      await tester.tap(
        find.byKey(SudokuDifficultyPage.tierKey(SudokuDifficulty.hard)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SudokuBoard), findsOneWidget);
      expect(find.text('9x9 · Hard'), findsOneWidget);
    });

    testWidgets('the tier reaches the generator, not just the header', (
      WidgetTester tester,
    ) async {
      // The header could read the tier straight off the route and look right
      // while the puzzle underneath was generated at some other difficulty.
      // This watches what the generator was actually asked for.
      final List<SudokuDifficulty> asked = <SudokuDifficulty>[];
      await setPhoneSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sudokuPuzzleSourceProvider.overrideWithValue((
              SudokuSpec spec,
              SudokuDifficulty tier,
              int seed,
            ) async {
              asked.add(tier);
              return fixedPuzzle(SudokuVariant.classic);
            }),
          ],
          child: MaterialApp(
            theme: buildNookTheme(NookColors.softClay),
            home: const SudokuDifficultyPage(variant: SudokuVariant.classic),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(SudokuDifficultyPage.tierKey(SudokuDifficulty.fiendish)),
      );
      await tester.pumpAndSettle();

      expect(asked, <SudokuDifficulty>[SudokuDifficulty.fiendish]);
    });
  });
}
