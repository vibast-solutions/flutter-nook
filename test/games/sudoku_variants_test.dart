import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/number_pad.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/sudoku/sudoku_naming.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

/// The first cell of [puzzle] the player has to fill, and what belongs there.
({int index, int digit}) firstBlank(SudokuPuzzle puzzle) {
  for (int i = 0; i < puzzle.givens.length; i++) {
    if (puzzle.givens[i] == 0) {
      return (index: i, digit: puzzle.solution[i]);
    }
  }
  throw StateError('the fixture has no cell left to fill');
}

void main() {
  group('every Sudoku is drawn from its own grid shape', () {
    for (final SudokuVariant variant in allVariants) {
      final int size = variant.spec.size;

      testWidgets('${variant.sizeLabel(en)}: the board has a cell per square', (
        WidgetTester tester,
      ) async {
        await pumpSudokuGame(tester, variant: variant);

        expect(find.byType(SudokuBoard), findsOneWidget);
        for (final int index in <int>[
          0,
          size - 1,
          variant.spec.cellCount - 1,
        ]) {
          expect(
            find.byKey(SudokuBoard.cellKey(index)),
            findsOneWidget,
            reason: 'cell $index is missing from a ${variant.sizeLabel(en)}',
          );
        }
        expect(
          find.byKey(SudokuBoard.cellKey(variant.spec.cellCount)),
          findsNothing,
          reason: 'a ${variant.sizeLabel(en)} drew a cell too many',
        );
      });

      testWidgets('${variant.sizeLabel(en)}: the pad has a key per digit', (
        WidgetTester tester,
      ) async {
        await pumpSudokuGame(tester, variant: variant);

        for (int digit = 1; digit <= size; digit++) {
          expect(find.byKey(NumberPad.keyFor(digit)), findsOneWidget);
        }
        expect(find.byKey(NumberPad.keyFor(size + 1)), findsNothing);
      });

      testWidgets(
        '${variant.sizeLabel(en)}: the board says its size out loud',
        (WidgetTester tester) async {
          final SemanticsHandle handle = tester.ensureSemantics();
          try {
            await pumpSudokuGame(tester, variant: variant);

            expect(
              find.bySemanticsLabel(en.boardLabel(variant.title(en), size)),
              findsOneWidget,
            );
          } finally {
            handle.dispose();
          }
        },
      );

      testWidgets('${variant.sizeLabel(en)}: an answer can be entered', (
        WidgetTester tester,
      ) async {
        final SudokuPuzzle puzzle = fixedPuzzle(variant);
        final ({int index, int digit}) blank = firstBlank(puzzle);
        await pumpSudokuGame(tester, variant: variant, puzzle: puzzle);

        await tester.tap(find.byKey(SudokuBoard.cellKey(blank.index)));
        await tester.pump();
        await tester.tap(find.byKey(NumberPad.keyFor(blank.digit)));
        await tester.pump();

        expect(
          tester
              .widget<Text>(find.byKey(SudokuBoard.valueKey(blank.index)))
              .data,
          '${blank.digit}',
        );
      });

      testWidgets('${variant.sizeLabel(en)}: the board fits the screen', (
        WidgetTester tester,
      ) async {
        await pumpSudokuGame(
          tester,
          variant: variant,
          width: kSmallestSupportedWidth,
        );

        final Size board = tester.getSize(find.byType(SudokuBoard));
        expect(board.width, lessThanOrEqualTo(kSmallestSupportedWidth));
        expect(board.height, closeTo(board.width, 0.01));
        // Cells share the board evenly, so a row of them is the board again.
        final double cell = tester
            .getSize(find.byKey(SudokuBoard.cellKey(0)))
            .width;
        expect(cell * size, closeTo(board.width, 0.01));
      });
    }
  });

  group('the tightest board Nook draws', () {
    testWidgets('every control stays at the minimum tap target', (
      WidgetTester tester,
    ) async {
      // A 9x9 puts nine pad keys and four action tiles on the narrowest screen
      // the app supports. Board cells are the stated exception: nine of them
      // across a phone cannot each be 44 wide.
      await pumpSudokuGame(
        tester,
        variant: SudokuVariant.classic,
        width: kSmallestSupportedWidth,
      );

      for (int digit = 1; digit <= 9; digit++) {
        final Size key = tester.getSize(find.byKey(NumberPad.keyFor(digit)));
        expect(
          key.width,
          greaterThanOrEqualTo(kMinTapTarget),
          reason: 'pad key $digit is too narrow to hit',
        );
        expect(key.height, greaterThanOrEqualTo(kMinTapTarget));
      }

      for (final String id in <String>['undo', 'erase', 'notes']) {
        final Size tile = tester.getSize(find.byKey(BoardActionRow.keyFor(id)));
        expect(
          tile.width,
          greaterThanOrEqualTo(kMinTapTarget),
          reason: '$id is too narrow to hit',
        );
        expect(tile.height, greaterThanOrEqualTo(kMinTapTarget));
      }
    });

    testWidgets('the pad splits nine keys the way the designs do', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(
        tester,
        variant: SudokuVariant.classic,
        width: kSmallestSupportedWidth,
      );

      // Five above four: the second row is short, and its keys line up with
      // the ones above rather than stretching to fill.
      expect(NumberPad.columnsFor(9), 5);
      final double first = tester
          .getSize(find.byKey(NumberPad.keyFor(1)))
          .width;
      final double last = tester.getSize(find.byKey(NumberPad.keyFor(9))).width;
      expect(last, closeTo(first, 0.01));
      expect(
        tester.getTopLeft(find.byKey(NumberPad.keyFor(6))).dx,
        closeTo(tester.getTopLeft(find.byKey(NumberPad.keyFor(1))).dx, 0.01),
      );
    });

    testWidgets('six keys go three and three, not five and one', (
      WidgetTester tester,
    ) async {
      expect(NumberPad.columnsFor(6), 3);
      expect(NumberPad.columnsFor(4), 4);

      await pumpSudokuGame(
        tester,
        variant: SudokuVariant.light,
        width: kSmallestSupportedWidth,
      );

      final double top = tester.getTopLeft(find.byKey(NumberPad.keyFor(1))).dy;
      expect(tester.getTopLeft(find.byKey(NumberPad.keyFor(3))).dy, top);
      expect(
        tester.getTopLeft(find.byKey(NumberPad.keyFor(4))).dy,
        greaterThan(top),
      );
    });

    testWidgets('the board does not scale its type twice', (
      WidgetTester tester,
    ) async {
      // The board sizes its own type from the cell, and the cell from the
      // screen, so the system text setting must not apply a second time — at
      // twice the size a 9x9's digits and pencil marks would be clipped by the
      // squares that hold them. Everything around the board still grows.
      final SudokuPuzzle puzzle = fixedPuzzle(SudokuVariant.classic);
      final ({int index, int digit}) blank = firstBlank(puzzle);
      await pumpSudokuGame(
        tester,
        variant: SudokuVariant.classic,
        puzzle: puzzle,
        width: kSmallestSupportedWidth,
        textScale: 2,
      );

      await tester.tap(find.byKey(SudokuBoard.cellKey(blank.index)));
      await tester.pump();
      await tester.tap(find.byKey(BoardActionRow.keyFor('notes')));
      await tester.pump();
      for (int digit = 1; digit <= 9; digit++) {
        await tester.tap(find.byKey(NumberPad.keyFor(digit)));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);

      final int given = puzzle.givens.indexWhere((int value) => value != 0);
      for (final Key key in <Key>[
        SudokuBoard.valueKey(given),
        SudokuBoard.notesKey(blank.index),
      ]) {
        expect(
          MediaQuery.textScalerOf(tester.element(find.byKey(key))).scale(15),
          15,
          reason: 'the board is scaling its own type a second time',
        );
      }

      expect(
        MediaQuery.textScalerOf(tester.element(find.text(en.gameInstruction)))
            .scale(15),
        30,
        reason: 'the setting should still reach everything else',
      );

      // And the marks still sit inside their cell.
      final Size cell = tester.getSize(
        find.byKey(SudokuBoard.cellKey(blank.index)),
      );
      final Size notes = tester.getSize(
        find.byKey(SudokuBoard.notesKey(blank.index)),
      );
      expect(notes.width, lessThanOrEqualTo(cell.width));
      expect(notes.height, lessThanOrEqualTo(cell.height));
    });
  });
}
