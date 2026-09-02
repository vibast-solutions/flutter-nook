import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/games/sudoku/sudoku_save.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:nook/store/nook_database.dart';

import '../support/sudoku_fixture.dart';

/// Cells 0 and 4 share column 0 and nothing is written between them; cell 3
/// shares no row, column or box with either. Between them they say what a
/// placement reaches and what it leaves alone.
const int noted = 0;
const int placeAt = 4;
const int elsewhere = 3;

void main() {
  group('placing a digit tidies the notes it rules out', () {
    testWidgets('out of the cells that can see it, and nothing else', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);
      await pencilInto(tester, noted, <int>[3, 4]);
      await pencilInto(tester, elsewhere, <int>[3, 4]);

      // Cell 4 takes a 3, which is also what belongs there.
      await answer(tester, placeAt, 3);

      expect(notesIn(tester, noted), <int>[
        4,
      ], reason: 'the 3 was settled for that column and stayed noted');
      expect(notesIn(tester, elsewhere), <int>[
        3,
        4,
      ], reason: 'a cell that cannot see the 3 lost a note to it');
    });

    testWidgets('whether the digit was right or wrong', (
      WidgetTester tester,
    ) async {
      // The app is applying the player's own claim, not the truth. A wrong
      // digit rules a note out exactly as a right one does, and nothing here
      // reads the solution to tell them apart.
      await pumpSudokuGame(tester);
      await pencilInto(tester, noted, <int>[3, 4]);

      // Cell 4 takes a 3; a 4 in it is wrong, and tidies just the same.
      await answer(tester, placeAt, 4);

      expect(notesIn(tester, noted), <int>[3]);
    });

    testWidgets('and a board with somebody else\'s solution tidies alike', (
      WidgetTester tester,
    ) async {
      // The guard: the same taps on a puzzle whose solution is not its own.
      await pumpSudokuGame(tester, puzzle: miniWithAnotherSolution());
      await pencilInto(tester, noted, <int>[3, 4]);

      await answer(tester, placeAt, 3);

      expect(notesIn(tester, noted), <int>[4]);
    });

    testWidgets('a hint tidies the same way', (WidgetTester tester) async {
      await pumpSudokuGame(tester);
      // Cell 3 is where the first hint lands, with a 4. Cell 2 is in its row
      // and its box, so a 4 noted there is ruled out by the hint.
      await pencilInto(tester, 2, <int>[1, 4]);

      await tapAction(tester, 'hint');

      expect(digitIn(tester, 3), '4');
      expect(notesIn(tester, 2), <int>[1]);
    });
  });

  group('undo is the strict inverse of one move', () {
    testWidgets('it puts the digit and every note it took back', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);
      await pencilInto(tester, noted, <int>[3, 4]);
      await answer(tester, placeAt, 3);

      await tapAction(tester, 'undo');

      expect(digitIn(tester, placeAt), isNull);
      expect(notesIn(tester, noted), <int>[3, 4]);
    });

    testWidgets('two placements come back in the order they went down', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);
      // Cell 8 is in column 0 with both of them.
      await pencilInto(tester, 8, <int>[3, 4]);

      await answer(tester, placeAt, 3);
      expect(notesIn(tester, 8), <int>[4]);
      await answer(tester, 0, 4);
      expect(find.byKey(SudokuBoard.notesKey(8)), findsNothing);

      await tapAction(tester, 'undo');

      expect(digitIn(tester, 0), isNull);
      expect(notesIn(tester, 8), <int>[4], reason: 'it restored too much');

      await tapAction(tester, 'undo');

      expect(digitIn(tester, placeAt), isNull);
      expect(notesIn(tester, 8), <int>[3, 4]);
    });

    testWidgets('undoing a hint restores what the hint tidied', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);
      await pencilInto(tester, 2, <int>[1, 4]);
      await tapHint(tester);

      await tapAction(tester, 'undo');

      expect(digitIn(tester, 3), isNull);
      expect(notesIn(tester, 2), <int>[1, 4]);
    });
  });

  group('nothing else reverses a move it did not make', () {
    testWidgets('erase takes the digit out and leaves the notes tidied', (
      WidgetTester tester,
    ) async {
      // Erasing is a move forward, not a reversal: it does not know which
      // notes the placement took, and undo is the one way back. Keeping that
      // true of every control is what makes undo worth trusting.
      await pumpSudokuGame(tester);
      await pencilInto(tester, noted, <int>[3, 4]);
      await answer(tester, placeAt, 3);

      await tapAction(tester, 'erase');

      expect(digitIn(tester, placeAt), isNull);
      expect(notesIn(tester, noted), <int>[4]);
    });

    testWidgets('and neither does clearing a cell by tapping its digit', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);
      await pencilInto(tester, noted, <int>[3, 4]);
      await answer(tester, placeAt, 3);

      await tapDigit(tester, 3);

      expect(digitIn(tester, placeAt), isNull);
      expect(notesIn(tester, noted), <int>[4]);
    });

    testWidgets('but undoing the erase still restores what the erase took', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);
      await pencilInto(tester, noted, <int>[3, 4]);
      await answer(tester, placeAt, 3);
      await tapAction(tester, 'erase');

      await tapAction(tester, 'undo');

      expect(digitIn(tester, placeAt), '3');
      expect(notesIn(tester, noted), <int>[4]);
    });
  });

  testWidgets('a tidied board comes back tidied, and undoes the same', (
    WidgetTester tester,
  ) async {
    // Whatever a placement did to the board goes to disk with it: the marks it
    // left, and what it would have to put back. A puzzle resumed tomorrow has
    // to undo the way it would have undone last night.
    final NookDatabase database = memoryDatabase();
    await pumpSudokuGame(tester, database: database);
    await pencilInto(tester, noted, <int>[3, 4]);
    await answer(tester, placeAt, 3);

    final SudokuSave resumed = SudokuSave.read(
      (await storedSave(tester, database, SudokuVariant.miniId))!,
    )!;
    await pumpSudokuGame(tester, database: memoryDatabase(), resume: resumed);

    expect(digitIn(tester, placeAt), '3');
    expect(notesIn(tester, noted), <int>[4]);

    await tapAction(tester, 'undo');

    expect(digitIn(tester, placeAt), isNull);
    expect(notesIn(tester, noted), <int>[3, 4]);
  });
}
