import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/games/sudoku/sudoku_state.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

/// The fixture 4x4 with [entries] written into it, cell index to digit.
///
/// Built straight rather than tapped: what is under test here is a reading of
/// the grid, and a board is the shortest way to say which grid.
SudokuGameState miniHolding(Map<int, int> entries, {SudokuPuzzle? puzzle}) {
  final SudokuPuzzle sudoku = puzzle ?? fixedMiniPuzzle();
  final List<int> cells = List<int>.of(sudoku.givens);
  entries.forEach((int index, int digit) => cells[index] = digit);
  return SudokuGameState(
    variant: SudokuVariant.mini,
    puzzle: sudoku,
    cells: cells,
  );
}

void main() {
  group('a conflict is a repeated digit', () {
    test('in a row, and both halves of it are marked', () {
      // Cell 6 is a given 1; a second 1 in the same row makes the pair.
      expect(miniHolding(<int, int>{4: 1}).conflicts, <int>{4, 6});
    });

    test('in a column', () {
      // Column 2 is cells 2, 6, 10 and 14. Two 4s in it, in different rows and
      // different boxes, so nothing but the column can be doing this.
      expect(miniHolding(<int, int>{2: 4, 10: 4}).conflicts, <int>{2, 10});
    });

    test('and in a box', () {
      // Cells 0 and 5 share the top-left box and nothing else.
      expect(miniHolding(<int, int>{0: 4, 5: 4}).conflicts, <int>{0, 5});
    });

    test('a given conflicts like anything else', () {
      // Blame is not the point: which of the two is the intruder is a question
      // only the answer could settle, and the board does not have it.
      final SudokuGameState game = miniHolding(<int, int>{4: 1});
      expect(game.isConflicting(6), isTrue);
      expect(game.isGiven(6), isTrue);
    });

    test('and an empty grid has none', () {
      expect(miniHolding(const <int, int>{}).conflicts, isEmpty);
    });
  });

  group('a conflict is never a judgement', () {
    test('a digit that is wrong but repeats nothing is left alone', () {
      // Cell 0 takes a 1. A 4 there is wrong, and breaks no rule: no row,
      // column or box it belongs to holds another 4. The board says nothing,
      // because a board that marked this would be an oracle to brute-force
      // rather than a puzzle to solve.
      final SudokuGameState game = miniHolding(<int, int>{0: 4});
      expect(game.cells[0], isNot(fixedMiniPuzzle().solution[0]));
      expect(game.conflicts, isEmpty);
    });

    test('and swapping the solution changes nothing at all', () {
      // The guard on the rule. If any reading of the solution ever creeps into
      // the marking, this is where it shows up.
      const Map<int, int> entries = <int, int>{0: 4, 4: 1, 5: 4, 10: 4};
      expect(
        miniHolding(entries, puzzle: miniWithAnotherSolution()).conflicts,
        miniHolding(entries).conflicts,
      );
      expect(miniHolding(entries).conflicts, isNotEmpty);
    });
  });

  group('the board shows a conflict', () {
    testWidgets('with a texture as well as a colour', (
      WidgetTester tester,
    ) async {
      // Colour alone would be silent for the players most likely to need it.
      await pumpSudokuGame(tester);

      expect(find.byKey(SudokuBoard.conflictKey(4)), findsNothing);

      await answer(tester, 4, 1);

      expect(find.byKey(SudokuBoard.conflictKey(4)), findsOneWidget);
      expect(
        find.byKey(SudokuBoard.conflictKey(6)),
        findsOneWidget,
        reason: 'only one half of the pair was marked',
      );
    });

    testWidgets('and says so to a screen reader', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpSudokuGame(tester);

        await answer(tester, 4, 1);

        // Cell 4 is row 2, column 1; cell 6 is the given 1 in row 2, column 3.
        expect(
          find.bySemanticsLabel(
            'Row 2, column 1, 1, your answer, repeated in its row, column or '
            'box',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            'Row 2, column 3, 1, given, repeated in its row, column or box',
          ),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('until one of the pair is cleared', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);
      await answer(tester, 4, 1);

      await tapAction(tester, 'erase');

      expect(find.byKey(SudokuBoard.conflictKey(4)), findsNothing);
      expect(find.byKey(SudokuBoard.conflictKey(6)), findsNothing);
    });
  });

  group('a completed unit is nodded at', () {
    testWidgets('a row and the box it finishes pulse together, once', (
      WidgetTester tester,
    ) async {
      // Filling cell 3 completes both the top row and the top-right box. Two
      // washes over the cells they share would read as a mistake rather than
      // as two pieces of good news, so it is one pulse over the union.
      await pumpSudokuGame(tester);

      await answer(tester, 0, 1);
      await answer(tester, 1, 2);
      await answer(tester, 2, 3);
      expect(
        find.byKey(SudokuBoard.pulseKey(0)),
        findsNothing,
        reason: 'a half-filled row was celebrated',
      );

      await answer(tester, 3, 4);
      await tester.pump(SudokuBoard.pulseDuration ~/ 2);

      for (final int index in <int>[0, 1, 2, 3, 6, 7]) {
        expect(
          find.byKey(SudokuBoard.pulseKey(index)),
          findsOneWidget,
          reason: 'cell $index is in a unit that just completed',
        );
      }
      expect(find.byKey(SudokuBoard.pulseKey(4)), findsNothing);

      await tester.pumpAndSettle();

      expect(
        find.byKey(SudokuBoard.pulseKey(0)),
        findsNothing,
        reason: 'the wash stayed up after the pulse was over',
      );
    });

    testWidgets('a column too', (WidgetTester tester) async {
      await pumpSudokuGame(tester);

      // Column 0 is cells 0, 4, 8 and 12, and nothing else finishes with it.
      await answer(tester, 0, 1);
      await answer(tester, 4, 3);
      await answer(tester, 8, 2);
      await answer(tester, 12, 4);
      await tester.pump(SudokuBoard.pulseDuration ~/ 2);

      for (final int index in <int>[0, 4, 8, 12]) {
        expect(find.byKey(SudokuBoard.pulseKey(index)), findsOneWidget);
      }
    });

    testWidgets('but a full unit holding a repeat is not', (
      WidgetTester tester,
    ) async {
      // Full and legal, never correct — and never full alone either. The row
      // below is as filled in as a row gets and has two 3s in it.
      await pumpSudokuGame(tester);

      await answer(tester, 0, 1);
      await answer(tester, 1, 2);
      await answer(tester, 2, 3);
      await answer(tester, 3, 3);
      await tester.pump(SudokuBoard.pulseDuration ~/ 2);

      for (int index = 0; index < 16; index++) {
        expect(
          find.byKey(SudokuBoard.pulseKey(index)),
          findsNothing,
          reason: 'cell $index was celebrated on a row with a repeat in it',
        );
      }
    });

    testWidgets('and nothing moves when the player asked for less motion', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester, disableAnimations: true);

      await answer(tester, 0, 1);
      await answer(tester, 1, 2);
      await answer(tester, 2, 3);
      await answer(tester, 3, 4);
      await tester.pump(SudokuBoard.pulseDuration ~/ 2);

      for (int index = 0; index < 16; index++) {
        expect(find.byKey(SudokuBoard.pulseKey(index)), findsNothing);
      }
      expect(
        digitIn(tester, 3),
        '4',
        reason: 'the board stopped working rather than stopped moving',
      );
    });
  });
}
