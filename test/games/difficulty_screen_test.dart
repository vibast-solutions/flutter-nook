import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/chrome/continue_card.dart';
import 'package:nook/chrome/discard_dialog.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/sudoku/difficulty_screen.dart';
import 'package:nook/games/sudoku/sudoku_naming.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

/// Pumps the difficulty screen for [variant], with generation stubbed out so
/// tapping a tier lands on a board immediately.
Future<void> pumpDifficulty(
  WidgetTester tester, {
  SudokuVariant variant = SudokuVariant.classic,
  NookDatabase? database,
  TestClock? clock,
  double width = 400,
}) async {
  await setPhoneSurface(tester, width: width);
  final SudokuPuzzle fixed = fixedPuzzle(variant);
  await tester.pumpWidget(
    nookScope(
      puzzle: fixed,
      database: database,
      clock: clock,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
      testWidgets('${variant.title(en)} lists exactly its own tiers', (
        WidgetTester tester,
      ) async {
        await pumpDifficulty(tester, variant: variant);

        expect(find.text(variant.title(en)), findsOneWidget);
        for (final SudokuDifficulty tier in SudokuDifficulty.values) {
          final bool offered = variant.tiers.contains(tier);
          expect(
            find.byKey(SudokuDifficultyPage.tierKey(tier)),
            offered ? findsOneWidget : findsNothing,
            reason: offered
                ? '${tier.label(en)} should be offered on ${variant.title(en)}'
                : '${tier.label(en)} cannot be generated for ${variant.title(en)}, '
                      'so offering it would be a button that lies',
          );
        }
      });

      testWidgets('${variant.title(en)} locks nothing', (
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
            reason: '${tier.label(en)} was not tappable',
          );
        }
      });

      testWidgets('${variant.title(en)} keeps its rows tappable at 320', (
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
            reason: '${tier.label(en)} is too short to hit comfortably',
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
        nookScope(
          puzzle: fixedPuzzle(SudokuVariant.classic),
          source: (SudokuSpec spec, SudokuDifficulty tier, int seed) async {
            asked.add(tier);
            return fixedPuzzle(SudokuVariant.classic);
          },
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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

  group('a game with a puzzle already in progress', () {
    /// The difficulty screen for Sudoku Mini, with [save] already on disk.
    Future<NookDatabase> pumpWithSave(
      WidgetTester tester, {
      SavedGame? save,
    }) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database).save(save ?? partPlayedMiniSave());
      await pumpDifficulty(
        tester,
        variant: SudokuVariant.mini,
        database: database,
      );
      return database;
    }

    testWidgets('offers it before offering a new one', (
      WidgetTester tester,
    ) async {
      await pumpWithSave(tester);

      expect(find.text(en.difficultyInProgress), findsOneWidget);
      expect(find.byKey(ContinueCard.cardKey), findsOneWidget);
      expect(find.text(en.continueProgress('01:30', 10)), findsOneWidget);
    });

    testWidgets('carries on with it exactly where it was', (
      WidgetTester tester,
    ) async {
      await pumpWithSave(tester);

      await tester.tap(find.byKey(ContinueCard.cardKey));
      await tester.pumpAndSettle();

      expect(find.byType(SudokuBoard), findsOneWidget);
      expect(digitIn(tester, 0), '1');
      expect(find.text('01:30'), findsOneWidget);
    });

    testWidgets('asks before a new puzzle throws it away', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = await pumpWithSave(tester);

      await tester.tap(
        find.byKey(SudokuDifficultyPage.tierKey(SudokuDifficulty.gentle)),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.discardTitle), findsOneWidget);
      expect(find.byType(SudokuBoard), findsNothing);
      expect(
        await storedSave(tester, database, SudokuVariant.miniId),
        isNotNull,
        reason: 'asking is not the same as doing',
      );
    });

    testWidgets('keeps it when the player says to keep playing', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = await pumpWithSave(tester);

      await tester.tap(
        find.byKey(SudokuDifficultyPage.tierKey(SudokuDifficulty.gentle)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DiscardDialog.keepKey));
      await tester.pumpAndSettle();

      expect(find.text(en.discardTitle), findsNothing);
      expect(find.byType(SudokuBoard), findsNothing);
      final SavedGame? kept = await storedSave(
        tester,
        database,
        SudokuVariant.miniId,
      );
      expect(kept, isNotNull);
      expect(kept!.cells[0], 1, reason: 'the board was changed by cancelling');
      expect(kept.elapsed, const Duration(minutes: 1, seconds: 30));
      expect(find.byKey(ContinueCard.cardKey), findsOneWidget);
    });

    testWidgets('throws it away only when the player says so', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = await pumpWithSave(tester);

      await tester.tap(
        find.byKey(SudokuDifficultyPage.tierKey(SudokuDifficulty.gentle)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DiscardDialog.confirmKey));
      await tester.pumpAndSettle();

      expect(find.byType(SudokuBoard), findsOneWidget);
      final SavedGame? replacement = await storedSave(
        tester,
        database,
        SudokuVariant.miniId,
      );
      // The new puzzle saves itself as soon as it exists, so what must be gone
      // is the old board rather than the row.
      expect(replacement?.cells[0] ?? 0, isNot(1));
      expect(replacement?.elapsed ?? Duration.zero, Duration.zero);
    });

    testWidgets('asks nothing when there is nothing to lose', (
      WidgetTester tester,
    ) async {
      await pumpDifficulty(tester, variant: SudokuVariant.mini);

      await tester.tap(
        find.byKey(SudokuDifficultyPage.tierKey(SudokuDifficulty.gentle)),
      );
      await tester.pumpAndSettle();

      expect(find.text(en.discardTitle), findsNothing);
      expect(find.byType(SudokuBoard), findsOneWidget);
    });
  });

  group('what a tier says about itself', () {
    /// Writes [solved] finished puzzles at [tier] into [database], the fastest
    /// of them taking [best] unless there is no best time to have.
    Future<void> record(
      NookDatabase database, {
      required SudokuDifficulty tier,
      int solved = 1,
      Duration? best = const Duration(minutes: 1),
      String gameId = SudokuVariant.classicId,
    }) async {
      final GameStatsStore store = GameStatsStore(database);
      for (int puzzle = 0; puzzle < solved; puzzle++) {
        await store.record(
          gameId: gameId,
          difficulty: tier.name,
          // A helped puzzle counts and sets no best, which is the only way to
          // arrive at a tier with a count and no time.
          time: best ?? const Duration(minutes: 9),
          hinted: best == null,
        );
      }
    }

    /// The line under [tier]'s name.
    String lineUnder(WidgetTester tester, SudokuDifficulty tier) {
      final Iterable<Text> lines = tester.widgetList<Text>(
        find.descendant(
          of: find.byKey(SudokuDifficultyPage.tierKey(tier)),
          matching: find.byType(Text),
        ),
      );
      return lines.elementAt(1).data!;
    }

    testWidgets('a tier nobody has finished describes the puzzle', (
      WidgetTester tester,
    ) async {
      // Rather than "not solved yet", which is true and tells a player
      // choosing a tier for the first time nothing at all.
      await pumpDifficulty(tester);

      expect(
        lineUnder(tester, SudokuDifficulty.medium),
        SudokuDifficulty.medium.blurb(en),
      );
    });

    testWidgets('a tier with a best time shows it, and the count', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await record(database, tier: SudokuDifficulty.medium, solved: 3);

      await pumpDifficulty(tester, database: database);

      expect(
        lineUnder(tester, SudokuDifficulty.medium),
        en.difficultyTierBest('01:00', 3),
      );
      expect(find.text('best 01:00 · 3 solved'), findsOneWidget);
    });

    testWidgets('a tier only ever finished with help shows just the count', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await record(database, tier: SudokuDifficulty.hard, best: null);

      await pumpDifficulty(tester, database: database);

      expect(
        lineUnder(tester, SudokuDifficulty.hard),
        en.difficultyTierSolved(1),
      );
      expect(find.text('1 solved'), findsOneWidget);
    });

    testWidgets('and the figures belong to one tier of one game', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await record(database, tier: SudokuDifficulty.gentle);
      await record(
        database,
        tier: SudokuDifficulty.easy,
        gameId: SudokuVariant.miniId,
      );

      await pumpDifficulty(tester, database: database);

      expect(
        lineUnder(tester, SudokuDifficulty.gentle),
        en.difficultyTierBest('01:00', 1),
      );
      expect(
        lineUnder(tester, SudokuDifficulty.easy),
        SudokuDifficulty.easy.blurb(en),
        reason: 'a Sudoku Mini time was shown on Sudoku Classic',
      );
    });

    testWidgets('and a screen reader hears them too', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final NookDatabase database = memoryDatabase();
        await record(database, tier: SudokuDifficulty.gentle, solved: 2);

        await pumpDifficulty(tester, database: database);

        expect(
          find.bySemanticsLabel(
            en.difficultyTierLabel(
              en.difficultyGentle,
              en.difficultyTierBest('01:00', 2),
            ),
          ),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });
  });
}
