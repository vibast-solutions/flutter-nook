import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/sudoku/sudoku_controller.dart';
import 'package:nook/home/home_screen.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

Future<void> pumpHome(WidgetTester tester) async {
  await setPhoneSurface(tester);
  final SudokuPuzzle fixed = fixedMiniPuzzle();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sudokuPuzzleSourceProvider.overrideWithValue(
          (SudokuSpec spec, int seed) async => fixed,
        ),
      ],
      child: MaterialApp(
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

      // Four of the five are still to come; Sudoku Mini is not among them.
      expect(find.textContaining('coming soon'), findsNWidgets(4));
      expect(find.text('4x4 · a few quiet minutes'), findsOneWidget);
    });

    testWidgets('opens Sudoku Mini', (WidgetTester tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Sudoku Mini'));
      await tester.pumpAndSettle();

      expect(find.byType(SudokuBoard), findsOneWidget);
      expect(find.text('4x4'), findsOneWidget);
    });

    testWidgets('does nothing when a game that is not ready is tapped', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('Stars'));
      await tester.pumpAndSettle();

      expect(find.byType(SudokuBoard), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the board can be left again', (WidgetTester tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Sudoku Mini'));
      await tester.pumpAndSettle();
      expect(find.byType(SudokuBoard), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Back to the game list'));
      await tester.pumpAndSettle();

      expect(find.byType(SudokuBoard), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
