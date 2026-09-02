import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/sudoku/sudoku_save.dart';
import 'package:nook/games/sudoku/sudoku_state.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

/// The first hint the fixture puzzle gives, worked out by hand.
///
/// Cell 3 is the top-right corner. Its column already holds a 2 and a 3, and
/// its box a 1 and a 2, so 4 is the only digit left in it — a naked single,
/// and the easiest thing on the board to see. The numbers are written out
/// rather than asked of the solver, so a change to which cell a hint picks
/// shows up here as a failing expectation instead of passing quietly.
const int firstHintIndex = 3;
const int firstHintDigit = 4;

/// The colour the answer in the cell at [index] is drawn in.
Color digitColour(WidgetTester tester, int index) {
  return tester
      .widget<Text>(find.byKey(SudokuBoard.valueKey(index)))
      .style!
      .color!;
}

/// Whether the action-row control with the id [id] can be used.
bool actionEnabled(WidgetTester tester, String id) {
  return tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(BoardActionRow.keyFor(id)),
              matching: find.byType(InkWell),
            ),
          )
          .onTap !=
      null;
}

void main() {
  group('a hint fills in a cell', () {
    testWidgets('one the player could have worked out at that moment', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapAction(tester, 'hint');

      expect(digitIn(tester, firstHintIndex), '$firstHintDigit');
      expect(
        firstHintDigit,
        fixedMiniPuzzle().solution[firstHintIndex],
        reason: 'a hint has to agree with the puzzle it came from',
      );
    });

    testWidgets('and puts the player on it, so it is not theirs to find', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapAction(tester, 'hint');

      // The selected cell is the one that changed: a hint that landed
      // somewhere on a 9x9 without saying where would be a puzzle of its own.
      expect(find.byKey(SudokuBoard.cellKey(firstHintIndex)), findsOneWidget);
      final Container cell = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(SudokuBoard.cellKey(firstHintIndex)),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (cell.decoration! as BoxDecoration).color,
        NookColors.softClay.cellSelected,
      );
    });

    testWidgets('written in neither the puzzle\'s hand nor the player\'s', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      // The player's own answer, for something to compare against.
      await tapCell(tester, 0);
      await tapDigit(tester, 1);
      await tapAction(tester, 'hint');

      const NookColors colors = NookColors.softClay;
      // Cell 6 is a given.
      expect(digitColour(tester, 6), colors.ink);
      expect(digitColour(tester, 0), colors.clay);
      expect(digitColour(tester, firstHintIndex), colors.hintInk);
      expect(colors.hintInk, isNot(colors.ink));
      expect(colors.hintInk, isNot(colors.clay));
    });

    testWidgets('and says as much to a screen reader', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpSudokuGame(tester);

        await tapAction(tester, 'hint');

        // Cell 3 is row 1, column 4.
        expect(
          find.bySemanticsLabel('Row 1, column 4, 4, from a hint'),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('as many times as the player asks', (
      WidgetTester tester,
    ) async {
      // The point of the feature. There is no counter to run down, no cooldown
      // to wait out and nothing to buy: a player can hint their way through a
      // whole puzzle, and the control only stops when the puzzle does.
      await pumpSudokuGame(tester);

      // Nine of the ten blanks, one hint at a time.
      for (int taps = 0; taps < 9; taps++) {
        expect(
          actionEnabled(tester, 'hint'),
          isTrue,
          reason: 'the hint ran out after $taps of them',
        );
        await tapAction(tester, 'hint');
      }

      final List<int> solution = fixedMiniPuzzle().solution;
      for (int index = 0; index < solution.length; index++) {
        final String? digit = digitIn(tester, index);
        if (digit != null) {
          expect(digit, '${solution[index]}', reason: 'cell $index is wrong');
        }
      }

      // And the tenth finishes it, which is what a player leaning on hints
      // alone has to be able to do.
      expect(actionEnabled(tester, 'hint'), isTrue);
      await tapAction(tester, 'hint');

      expect(find.text(en.gameSolved), findsOneWidget);
      expect(
        find.byKey(BoardActionRow.keyFor('hint')),
        findsNothing,
        reason: 'the control outlived the puzzle it belonged to',
      );
    });
  });

  group('a hint leaves the player\'s own work alone', () {
    testWidgets('it reasons around a wrong entry rather than correcting it', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      // Cell 3 takes a 4; put a 3 in it instead. That is the cell the hint
      // would otherwise have chosen, so the hint has to look elsewhere.
      await tapCell(tester, firstHintIndex);
      await tapDigit(tester, 3);
      await tapAction(tester, 'hint');

      expect(
        digitIn(tester, firstHintIndex),
        '3',
        reason: 'the mistake was silently corrected',
      );
      // Cell 1 takes a 2, which is what is left once the mistake is reasoned
      // around instead of reasoned from.
      expect(digitIn(tester, 1), '2');
      expect(fixedMiniPuzzle().solution[1], 2);
    });

    testWidgets('it never overwrites a digit the player put down', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      // Answer the first four blanks correctly, then ask four times: every
      // hint has to find somewhere the player has not already been.
      final List<int> solution = fixedMiniPuzzle().solution;
      for (final int index in <int>[0, 1, 2, 3]) {
        await tapCell(tester, index);
        await tapDigit(tester, solution[index]);
      }
      final List<String?> before = boardDigits(tester);

      await tapAction(tester, 'hint');

      final List<String?> after = boardDigits(tester);
      int changed = 0;
      for (int index = 0; index < before.length; index++) {
        if (before[index] != after[index]) {
          changed++;
          expect(before[index], isNull, reason: 'it wrote over a filled cell');
        }
      }
      expect(changed, 1);
    });
  });

  group('a hint is a move like any other', () {
    testWidgets('undo takes it back', (WidgetTester tester) async {
      await pumpSudokuGame(tester);

      await tapAction(tester, 'hint');
      expect(digitIn(tester, firstHintIndex), '$firstHintDigit');

      await tapAction(tester, 'undo');

      expect(digitIn(tester, firstHintIndex), isNull);
      expect(actionEnabled(tester, 'undo'), isFalse);
    });

    testWidgets('and the cell stops being a hinted one', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapAction(tester, 'hint');
      await tapAction(tester, 'undo');
      // The player answers the same cell themselves.
      await tapDigit(tester, firstHintDigit);

      expect(digitColour(tester, firstHintIndex), NookColors.softClay.clay);
    });

    testWidgets('answering over a hint makes the cell the player\'s', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapAction(tester, 'hint');
      // The hint selected its own cell, so the pad is already pointing at it.
      await tapDigit(tester, 2);

      expect(digitIn(tester, firstHintIndex), '2');
      expect(digitColour(tester, firstHintIndex), NookColors.softClay.clay);
    });
  });

  group('a saved game remembers it was hinted', () {
    testWidgets('the cell, so a resumed puzzle still says where it came from', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpSudokuGame(tester, database: database);

      await tapAction(tester, 'hint');

      final SavedGame save = (await storedSave(
        tester,
        database,
        SudokuVariant.miniId,
      ))!;
      expect(save.hints, <int>[firstHintIndex]);
      expect(save.wasHinted, isTrue);
      expect(save.cells[firstHintIndex], firstHintDigit);
    });

    testWidgets('and reads it back on a cold launch', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpSudokuGame(tester, database: database);
      await tapAction(tester, 'hint');
      final SudokuSave resume = SudokuSave.read(
        (await storedSave(tester, database, SudokuVariant.miniId))!,
      )!;

      await pumpSudokuGame(tester, database: memoryDatabase(), resume: resume);

      expect(digitIn(tester, firstHintIndex), '$firstHintDigit');
      expect(digitColour(tester, firstHintIndex), NookColors.softClay.hintInk);
      expect(resume.game.wasHinted, isTrue);
    });

    testWidgets('that a hint was taken back does not unsay it', (
      WidgetTester tester,
    ) async {
      // What statistics (VIB-77) will ask the save: not what is on the board
      // now, but whether this puzzle was ever helped along. Undoing a hint
      // clears the cell; it cannot unshow what was shown.
      final NookDatabase database = memoryDatabase();
      await pumpSudokuGame(tester, database: database);

      await tapAction(tester, 'hint');
      await tapAction(tester, 'undo');

      final SavedGame save = (await storedSave(
        tester,
        database,
        SudokuVariant.miniId,
      ))!;
      expect(save.hints, isEmpty);
      expect(save.wasHinted, isTrue);
    });

    testWidgets('a puzzle nobody was helped with says so too', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpSudokuGame(tester, database: database);

      await tapCell(tester, 0);
      await tapDigit(tester, 1);

      final SavedGame save = (await storedSave(
        tester,
        database,
        SudokuVariant.miniId,
      ))!;
      expect(save.hints, isEmpty);
      expect(save.wasHinted, isFalse);
    });
  });

  group('SudokuSave', () {
    test('a save written before hints existed reads as unhinted', () {
      // Version 1 of the database had no hint columns, so a row from it comes
      // back with the defaults. It has to read as a puzzle nobody helped
      // with rather than as an unreadable save.
      final SudokuGameState game = SudokuGameState.fresh(
        variant: SudokuVariant.mini,
        puzzle: fixedMiniPuzzle(),
      );
      final SavedGame old = SavedGame(
        gameId: SudokuVariant.miniId,
        difficulty: SudokuDifficulty.gentle.name,
        seed: game.puzzle.seed,
        givens: game.puzzle.givens,
        solution: game.puzzle.solution,
        cells: game.cells,
        notes: game.notes,
        history: game.history,
        elapsed: const Duration(minutes: 2),
        updatedAt: DateTime.utc(2026, 9, 2),
      );

      final SudokuSave? read = SudokuSave.read(old);

      expect(read, isNotNull);
      expect(read!.game.hints, isEmpty);
      expect(read.game.wasHinted, isFalse);
    });
  });
}
