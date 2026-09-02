import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/number_pad.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/sudoku/sudoku_controller.dart';
import 'package:nook/games/sudoku/sudoku_screen.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

/// Taps the board cell at [index].
Future<void> tapCell(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(SudokuBoard.cellKey(index)));
  await tester.pump();
}

/// Taps the number-pad key for [digit].
Future<void> tapDigit(WidgetTester tester, int digit) async {
  await tester.tap(find.byKey(NumberPad.keyFor(digit)));
  await tester.pump();
}

/// Taps the action-row control with the id [id].
///
/// Controls are found by id rather than by the word on them: the word is
/// translated, and a test that hunted for it would only pass in English.
Future<void> tapAction(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(BoardActionRow.keyFor(id)));
  await tester.pump();
}

/// The colour the action-row control with the id [id] is filled with.
Color actionBackground(WidgetTester tester, String id) {
  return tester.widget<Material>(find.byKey(BoardActionRow.keyFor(id))).color!;
}

/// Every digit on the board, with `null` for an empty cell.
List<String?> boardDigits(WidgetTester tester) {
  return <String?>[for (int i = 0; i < 16; i++) digitIn(tester, i)];
}

/// The digit currently drawn in the cell at [index], or `null` if it is empty.
String? digitIn(WidgetTester tester, int index) {
  final Finder text = find.byKey(SudokuBoard.valueKey(index));
  if (text.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<Text>(text).data;
}

/// The pencil marks drawn in the cell at [index], smallest first.
List<int> notesIn(WidgetTester tester, int index) {
  final Finder marks = find.descendant(
    of: find.byKey(SudokuBoard.notesKey(index)),
    matching: find.byType(Text),
  );
  return <int>[
    for (final Text mark in tester.widgetList<Text>(marks))
      int.parse(mark.data!),
  ];
}

/// The colour a pencil mark in the cell at [index] is drawn in.
Color noteColour(WidgetTester tester, int index) {
  return tester
      .widget<Text>(
        find
            .descendant(
              of: find.byKey(SudokuBoard.notesKey(index)),
              matching: find.byType(Text),
            )
            .first,
      )
      .style!
      .color!;
}

/// The colour the cell at [index] is filled with.
Color cellBackground(WidgetTester tester, int index) {
  final Container container = tester.widget<Container>(
    find.descendant(
      of: find.byKey(SudokuBoard.cellKey(index)),
      matching: find.byType(Container),
    ),
  );
  return (container.decoration! as BoxDecoration).color!;
}

/// The colour the large digit on the pad key for [digit] is drawn in.
Color padDigitColour(WidgetTester tester, int digit) {
  final Text text = tester.widget<Text>(
    find
        .descendant(
          of: find.byKey(NumberPad.keyFor(digit)),
          matching: find.byType(Text),
        )
        .first,
  );
  return text.style!.color!;
}

void main() {
  const NookColors colors = NookColors.softClay;

  group('playing a 4x4', () {
    testWidgets('shows the puzzle it was given', (WidgetTester tester) async {
      await pumpSudokuGame(tester);

      expect(find.text('Sudoku Mini'), findsOneWidget);
      // The header names the grid and the tier the player chose, so a puzzle
      // is never anonymous about how hard it was asked to be.
      expect(find.text('4x4 · Gentle'), findsOneWidget);
      // The six givens are on the board, and the ten empty cells are empty.
      expect(digitIn(tester, 6), '1');
      expect(digitIn(tester, 7), '2');
      expect(digitIn(tester, 0), isNull);
      expect(digitIn(tester, 15), isNull);
    });

    testWidgets('selecting a cell highlights it and its peers', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);

      expect(cellBackground(tester, 0), colors.cellSelected);
      expect(cellBackground(tester, 1), colors.cellPeer, reason: 'same box');
      expect(cellBackground(tester, 3), colors.cellPeer, reason: 'same row');
      expect(
        cellBackground(tester, 12),
        colors.cellPeer,
        reason: 'same column',
      );
      expect(
        cellBackground(tester, 15),
        colors.surface,
        reason: 'shares nothing with cell 0',
      );
    });

    testWidgets('cells holding the selected digit are picked out', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      // Cell 6 holds a 1; so does cell 9, which shares no unit with it.
      await tapCell(tester, 6);

      expect(cellBackground(tester, 6), colors.cellSelected);
      expect(cellBackground(tester, 9), colors.cellMatching);
    });

    testWidgets('entering a digit writes it into the selected cell', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapDigit(tester, 1);

      expect(digitIn(tester, 0), '1');
    });

    testWidgets('a wrong digit can be corrected by entering another', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapDigit(tester, 3); // Wrong: cell 0 is a 1.
      expect(digitIn(tester, 0), '3');

      await tapDigit(tester, 1);
      expect(digitIn(tester, 0), '1');
    });

    testWidgets('tapping the digit already in the cell clears it', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapDigit(tester, 2);
      expect(digitIn(tester, 0), '2');

      await tapDigit(tester, 2);
      expect(digitIn(tester, 0), isNull);
    });

    testWidgets('nothing is entered while no cell is selected', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapDigit(tester, 1);

      final SudokuPuzzle puzzle = fixedMiniPuzzle();
      for (int i = 0; i < puzzle.givens.length; i++) {
        final int given = puzzle.givens[i];
        expect(digitIn(tester, i), given == 0 ? isNull : '$given');
      }
    });

    testWidgets('a given cell can be selected but never changed', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 6); // A given 1.

      expect(
        cellBackground(tester, 6),
        colors.cellSelected,
        reason: 'selecting a given still highlights the board',
      );

      await tapDigit(tester, 4);
      expect(digitIn(tester, 6), '1', reason: 'the given did not move');

      await tapDigit(tester, 1);
      expect(digitIn(tester, 6), '1', reason: 'and it cannot be cleared');
    });

    testWidgets('the player\'s digits are drawn differently from the givens', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapDigit(tester, 1);

      Color colourOf(int index) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(SudokuBoard.cellKey(index)),
              matching: find.byType(Text),
            ),
          )
          .style!
          .color!;

      expect(colourOf(6), colors.ink, reason: 'a given');
      expect(colourOf(0), colors.clay, reason: 'the player');
    });
  });

  group('undo and erase', () {
    /// The board as it starts: the six givens and ten empty cells.
    List<String?> givenBoard() {
      final SudokuPuzzle puzzle = fixedMiniPuzzle();
      return <String?>[
        for (final int given in puzzle.givens) given == 0 ? null : '$given',
      ];
    }

    /// The starting board with [entries] written into it.
    List<String?> boardWith(Map<int, String> entries) {
      final List<String?> board = givenBoard();
      entries.forEach((int index, String digit) => board[index] = digit);
      return board;
    }

    testWidgets('three digits are taken back one at a time', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapDigit(tester, 1);
      await tapCell(tester, 4);
      await tapDigit(tester, 3);
      await tapCell(tester, 15);
      await tapDigit(tester, 1);
      expect(
        boardDigits(tester),
        boardWith(<int, String>{0: '1', 4: '3', 15: '1'}),
      );

      await tapAction(tester, 'undo');
      expect(boardDigits(tester), boardWith(<int, String>{0: '1', 4: '3'}));

      await tapAction(tester, 'undo');
      expect(boardDigits(tester), boardWith(<int, String>{0: '1'}));

      await tapAction(tester, 'undo');
      expect(
        boardDigits(tester),
        givenBoard(),
        reason: 'back where it started',
      );
    });

    testWidgets('undo puts the player back on the cell it changed', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapDigit(tester, 1);
      await tapCell(tester, 15);

      await tapAction(tester, 'undo');

      expect(digitIn(tester, 0), isNull);
      expect(
        cellBackground(tester, 0),
        colors.cellSelected,
        reason: 'the selection follows the move being taken back',
      );
    });

    testWidgets('a correction is one move, and undoing it restores the first '
        'digit', (WidgetTester tester) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapDigit(tester, 3); // Wrong.
      await tapDigit(tester, 1); // Corrected.

      await tapAction(tester, 'undo');

      expect(digitIn(tester, 0), '3');
    });

    testWidgets('undo reads as unavailable with nothing to take back', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      expect(actionBackground(tester, 'undo'), colors.disabledSurface);

      // Tapping it anyway is a no-op rather than an error.
      await tapAction(tester, 'undo');
      expect(boardDigits(tester), givenBoard());

      await tapCell(tester, 0);
      await tapDigit(tester, 1);
      expect(actionBackground(tester, 'undo'), colors.surface);

      await tapAction(tester, 'undo');
      expect(actionBackground(tester, 'undo'), colors.disabledSurface);
    });

    testWidgets('erase clears the player\'s digit', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapDigit(tester, 1);
      expect(digitIn(tester, 0), '1');

      await tapAction(tester, 'erase');

      expect(digitIn(tester, 0), isNull);
    });

    testWidgets('erase leaves a given alone', (WidgetTester tester) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 6); // A given 1.
      await tapAction(tester, 'erase');

      expect(digitIn(tester, 6), '1');
      expect(
        actionBackground(tester, 'undo'),
        colors.disabledSurface,
        reason: 'nothing happened, so there is nothing to undo',
      );
    });

    testWidgets('erase with nothing selected does nothing', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapAction(tester, 'erase');

      expect(boardDigits(tester), givenBoard());
    });

    testWidgets('an erase can itself be undone', (WidgetTester tester) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapDigit(tester, 1);
      await tapAction(tester, 'erase');
      expect(digitIn(tester, 0), isNull);

      await tapAction(tester, 'undo');

      expect(digitIn(tester, 0), '1');
    });

    testWidgets('both controls switch off once the puzzle is solved', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      final SudokuPuzzle puzzle = fixedMiniPuzzle();
      for (int i = 0; i < puzzle.givens.length; i++) {
        if (puzzle.givens[i] == 0) {
          await tapCell(tester, i);
          await tapDigit(tester, puzzle.solution[i]);
        }
      }
      await tester.pumpAndSettle();

      expect(find.text('Solved'), findsOneWidget);
      expect(actionBackground(tester, 'undo'), colors.disabledSurface);
      expect(actionBackground(tester, 'erase'), colors.disabledSurface);

      await tapAction(tester, 'undo');
      await tapAction(tester, 'erase');

      expect(find.text('Solved'), findsOneWidget, reason: 'still solved');
    });
  });

  group('pencil notes', () {
    testWidgets('the toggle says which mode the pad is in', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      expect(find.text('Notes off'), findsOneWidget);
      expect(actionBackground(tester, 'notes'), colors.surface);

      await tapAction(tester, 'notes');

      expect(find.text('Notes on'), findsOneWidget);
      expect(
        actionBackground(tester, 'notes'),
        colors.clay,
        reason:
            'notes mode changes what every later tap means, so it is the '
            'loudest thing in the row while it is on',
      );

      await tapAction(tester, 'notes');

      expect(find.text('Notes off'), findsOneWidget);
      expect(actionBackground(tester, 'notes'), colors.surface);
    });

    testWidgets('digits go in as marks and the same tap rubs them out', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapAction(tester, 'notes');
      await tapDigit(tester, 1);
      await tapDigit(tester, 4);

      expect(notesIn(tester, 0), <int>[1, 4]);
      expect(digitIn(tester, 0), isNull, reason: 'no answer went down');

      await tapDigit(tester, 1);

      expect(notesIn(tester, 0), <int>[4]);
    });

    testWidgets('marks are drawn apart from answers', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapAction(tester, 'notes');
      await tapDigit(tester, 2);

      expect(noteColour(tester, 0), colors.noteInk);
      expect(
        noteColour(tester, 0),
        isNot(colors.clay),
        reason: 'a mark must not read as an answer',
      );
    });

    testWidgets('marks stay where their digit belongs', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapAction(tester, 'notes');
      await tapDigit(tester, 4);
      final Offset four = tester.getCenter(find.text('4').last);

      await tapDigit(tester, 1);

      expect(
        tester.getCenter(find.text('4').last),
        four,
        reason: 'a later mark does not shuffle the ones already there',
      );
    });

    testWidgets('an answer clears the marks, and undo brings them back', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapAction(tester, 'notes');
      await tapDigit(tester, 1);
      await tapDigit(tester, 3);
      expect(notesIn(tester, 0), <int>[1, 3]);

      await tapAction(tester, 'notes');
      await tapDigit(tester, 1);
      expect(digitIn(tester, 0), '1');
      expect(
        find.byKey(SudokuBoard.notesKey(0)),
        findsNothing,
        reason: 'a cell shows an answer or its marks, never both',
      );

      await tapAction(tester, 'undo');

      expect(digitIn(tester, 0), isNull);
      expect(notesIn(tester, 0), <int>[1, 3]);
    });

    testWidgets('pencilling into a filled cell puts the answer back in doubt', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapDigit(tester, 3);
      await tapAction(tester, 'notes');
      await tapDigit(tester, 1);

      expect(digitIn(tester, 0), isNull);
      expect(notesIn(tester, 0), <int>[1]);

      await tapAction(tester, 'undo');

      expect(digitIn(tester, 0), '3');
      expect(find.byKey(SudokuBoard.notesKey(0)), findsNothing);
    });

    testWidgets('erase clears the marks', (WidgetTester tester) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapAction(tester, 'notes');
      await tapDigit(tester, 2);
      await tapDigit(tester, 3);

      await tapAction(tester, 'erase');

      expect(find.byKey(SudokuBoard.notesKey(0)), findsNothing);

      await tapAction(tester, 'undo');
      expect(notesIn(tester, 0), <int>[2, 3]);
    });

    testWidgets('a mark is taken back one at a time', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 0);
      await tapAction(tester, 'notes');
      await tapDigit(tester, 1);
      await tapDigit(tester, 2);
      await tapDigit(tester, 3);

      await tapAction(tester, 'undo');
      expect(notesIn(tester, 0), <int>[1, 2]);

      await tapAction(tester, 'undo');
      expect(notesIn(tester, 0), <int>[1]);

      await tapAction(tester, 'undo');
      expect(find.byKey(SudokuBoard.notesKey(0)), findsNothing);
      expect(
        actionBackground(tester, 'undo'),
        colors.disabledSurface,
        reason: 'the marks were the whole history',
      );
    });

    testWidgets('a given cell takes no marks', (WidgetTester tester) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 6); // A given 1.
      await tapAction(tester, 'notes');
      await tapDigit(tester, 3);

      expect(digitIn(tester, 6), '1');
      expect(find.byKey(SudokuBoard.notesKey(6)), findsNothing);
      expect(
        actionBackground(tester, 'undo'),
        colors.disabledSurface,
        reason: 'nothing happened, so there is nothing to undo',
      );
    });

    testWidgets('the mode stays on as the player moves around the board', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapAction(tester, 'notes');
      await tapCell(tester, 0);
      await tapDigit(tester, 2);
      await tapCell(tester, 15);
      await tapDigit(tester, 2);

      expect(notesIn(tester, 0), <int>[2]);
      expect(notesIn(tester, 15), <int>[2]);
      expect(find.text('Notes on'), findsOneWidget);
    });

    testWidgets('the toggle switches off with the rest once solved', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      final SudokuPuzzle puzzle = fixedMiniPuzzle();
      for (int i = 0; i < puzzle.givens.length; i++) {
        if (puzzle.givens[i] == 0) {
          await tapCell(tester, i);
          await tapDigit(tester, puzzle.solution[i]);
        }
      }
      await tester.pumpAndSettle();

      expect(actionBackground(tester, 'notes'), colors.disabledSurface);

      await tapAction(tester, 'notes');

      expect(find.text('Notes off'), findsOneWidget);
      expect(find.text('Solved'), findsOneWidget);
    });
  });

  group('the number pad', () {
    testWidgets('counts what is left of each digit', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      // Two 1s, 2s and 3s are given; no 4 is.
      expect(find.text('2 left'), findsNWidgets(3));
      expect(find.text('4 left'), findsOneWidget);
    });

    testWidgets('the count follows what the player enters', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      await tapCell(tester, 3);
      await tapDigit(tester, 4);

      expect(find.text('3 left'), findsOneWidget);
    });

    testWidgets('a fully placed digit greys out but stays usable', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      // Place the two missing 1s.
      await tapCell(tester, 0);
      await tapDigit(tester, 1);
      await tapCell(tester, 10); // Cell 10 wants a 4; a 1 here is wrong.
      await tapDigit(tester, 1);

      expect(find.text('done'), findsOneWidget);
      expect(padDigitColour(tester, 1), colors.disabledInk);
      expect(padDigitColour(tester, 4), colors.ink);

      // Still tappable: with a 1 in the wrong place and the count at zero,
      // tapping 1 again is the only way to take it back.
      await tapDigit(tester, 1);
      expect(digitIn(tester, 10), isNull);
      expect(find.text('1 left'), findsOneWidget);
    });
  });

  group('finishing', () {
    testWidgets('completing the grid reaches the solved state', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      expect(find.text('Solved'), findsNothing);
      expect(find.text('Tap a cell, then a number'), findsOneWidget);

      final SudokuPuzzle puzzle = fixedMiniPuzzle();
      for (int i = 0; i < puzzle.givens.length; i++) {
        if (puzzle.givens[i] != 0) {
          continue;
        }
        await tapCell(tester, i);
        await tapDigit(tester, puzzle.solution[i]);
      }
      await tester.pumpAndSettle();

      expect(find.text('Solved'), findsOneWidget);
      expect(find.text('Tap a cell, then a number'), findsNothing);
    });

    testWidgets('a grid that is full but wrong is not solved', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      final SudokuPuzzle puzzle = fixedMiniPuzzle();
      final List<int> empties = <int>[
        for (int i = 0; i < puzzle.givens.length; i++)
          if (puzzle.givens[i] == 0) i,
      ];
      // Fill everything but the last two cells correctly, then swap those two
      // so the board ends up full and wrong rather than full and right.
      final int a = empties[empties.length - 2];
      final int b = empties.last;
      for (final int i in empties) {
        final int digit = i == a
            ? puzzle.solution[b]
            : i == b
            ? puzzle.solution[a]
            : puzzle.solution[i];
        await tapCell(tester, i);
        await tapDigit(tester, digit);
      }
      await tester.pumpAndSettle();

      expect(
        puzzle.solution[a],
        isNot(puzzle.solution[b]),
        reason: 'the swap has to actually change something',
      );

      expect(find.text('Solved'), findsNothing);
    });

    testWidgets('a new puzzle can be started from the solved state', (
      WidgetTester tester,
    ) async {
      await pumpSudokuGame(tester);

      final SudokuPuzzle puzzle = fixedMiniPuzzle();
      for (int i = 0; i < puzzle.givens.length; i++) {
        if (puzzle.givens[i] == 0) {
          await tapCell(tester, i);
          await tapDigit(tester, puzzle.solution[i]);
        }
      }
      await tester.pumpAndSettle();

      await tester.tap(find.text('New puzzle'));
      await tester.pumpAndSettle();

      // The fixture is handed back, so the board resets to its givens.
      expect(find.text('Solved'), findsNothing);
      expect(digitIn(tester, 0), isNull);
      expect(digitIn(tester, 6), '1');
    });
  });

  group('generation', () {
    testWidgets('shows progress while the puzzle is being made', (
      WidgetTester tester,
    ) async {
      await setPhoneSurface(tester);
      final Completer<SudokuPuzzle> pending = Completer<SudokuPuzzle>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sudokuPuzzleSourceProvider.overrideWithValue(
              (SudokuSpec spec, SudokuDifficulty tier, int seed) =>
                  pending.future,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildNookTheme(NookColors.softClay),
            home: const SudokuGamePage(
              variant: SudokuVariant.mini,
              difficulty: SudokuDifficulty.gentle,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Making you a puzzle'), findsOneWidget);

      pending.complete(fixedMiniPuzzle());
      await tester.pumpAndSettle();

      expect(find.text('Making you a puzzle'), findsNothing);
      expect(digitIn(tester, 6), '1');
    });

    test('the shipped source really generates on another isolate', () async {
      // The fixture-based tests above never touch the engine, so this is the
      // one place the isolate hop and the generator are exercised together.
      final SudokuPuzzle puzzle = await generateSudokuOffThread(
        SudokuSpec.mini,
        SudokuDifficulty.gentle,
        4242,
      );

      expect(puzzle.seed, 4242);
      expect(puzzle.difficulty, SudokuDifficulty.gentle);
      expect(puzzle.givens, hasLength(16));
      expect(puzzle.givenCount, greaterThan(0));
      expect(puzzle.givenCount, lessThan(16));
      expect(
        SudokuSolver(SudokuSpec.mini).countSolutions(puzzle.givens, limit: 2),
        1,
      );
    });

    test('that is what the app uses unless a test says otherwise', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(sudokuPuzzleSourceProvider),
        same(generateSudokuOffThread),
      );
    });
  });
}
