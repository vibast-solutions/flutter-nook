import 'package:flutter_test/flutter_test.dart';
import 'package:nook/chrome/difficulty_naming.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/chrome/continue_card.dart';
import 'package:nook/games/sudoku/sudoku_naming.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:nook/home/home_screen.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/chrome/move_history.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

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

    testWidgets('offers nothing to continue on a fresh install', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      expect(find.byKey(ContinueCard.cardKey), findsNothing);
      expect(find.text(en.homeContinue), findsNothing);
    });

    testWidgets('offers the puzzle that was left unfinished', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database).save(partPlayedMiniSave());

      await pumpHome(tester, database: database);

      expect(find.text(en.homeContinue), findsOneWidget);
      expect(find.byKey(ContinueCard.cardKey), findsOneWidget);
      // One of the ten blanks filled in, after a minute and a half.
      expect(
        find.text(
          en.continueDetails(PuzzleDifficulty.gentle.label(en), '01:30', 10),
        ),
        findsOneWidget,
      );
    });

    testWidgets('offers the most recently played of several', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final SavedGameStore store = SavedGameStore(database);
      await store.save(partPlayedMiniSave(at: DateTime.utc(2026, 9, 1)));
      await store.save(
        SavedGame(
          gameId: SudokuVariant.classicId,
          difficulty: PuzzleDifficulty.hard.name,
          seed: 7,
          givens: List<int>.filled(81, 0),
          solution: List<int>.filled(81, 1),
          cells: List<int>.filled(81, 0),
          notes: List<int>.filled(81, 0),
          history: const MoveHistory.empty(),
          elapsed: const Duration(minutes: 12),
          updatedAt: DateTime.utc(2026, 9, 2),
        ),
      );

      await pumpHome(tester, database: database);

      expect(
        find.descendant(
          of: find.byKey(ContinueCard.cardKey),
          matching: find.text(SudokuVariant.classic.title(en)),
        ),
        findsOneWidget,
      );
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

    testWidgets('every game in the list is playable', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      // Every game is built now — Duo landed with VIB-93 — so nothing in the
      // list is greyed with a "coming soon".
      expect(find.textContaining('coming soon'), findsNothing);
      expect(find.text('9x9 · the full grid'), findsOneWidget);
      expect(find.text('6x6 · a gentler grid'), findsOneWidget);
      expect(find.text('4x4 · a few quiet minutes'), findsOneWidget);
      expect(find.text(en.duoSubtitle), findsOneWidget);
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
        for (final PuzzleDifficulty tier in variant.tiers) {
          expect(find.text(tier.label(en)), findsOneWidget);
        }
      });

      testWidgets('reaches a ${variant.title(en)} board through a tier', (
        WidgetTester tester,
      ) async {
        await pumpHome(tester, variant: variant);

        await tester.tap(find.text(variant.title(en)));
        await tester.pumpAndSettle();
        await tester.tap(find.text(PuzzleDifficulty.gentle.label(en)));
        await tester.pumpAndSettle();

        expect(find.byType(SudokuBoard), findsOneWidget);
        expect(
          find.text(
            en.gameSubtitle(
              variant.sizeLabel(en),
              PuzzleDifficulty.gentle.label(en),
            ),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets('every screen can be backed out of', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('Sudoku Mini'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(PuzzleDifficulty.gentle.label(en)));
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
