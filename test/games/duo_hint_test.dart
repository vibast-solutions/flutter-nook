import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/duo_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/duo/duo_state.dart';
import 'package:nook/games/duo/duo_variant.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/duo_fixture.dart';

/// The first symbol the fixture puzzle gives from an untouched board.
///
/// Cell 15 takes a circle across a badge from a filled cell — the deduction the
/// technique solver reaches first — so it is the symbol a hint offers before
/// the player has placed any of their own. It is written out rather than asked
/// of the solver, so a change to which symbol a hint picks shows up here as a
/// failing expectation instead of passing quietly.
const int firstHintCell = 15;

/// The symbol [firstHintCell] takes.
const DuoCell firstHintSymbol = DuoCell.circle;

/// The next cell the solver reaches, once [firstHintCell] is down.
const int secondHintCell = 14;

/// A free cell of the fixture puzzle whose solution is a circle, so a square
/// there is a wrong entry — and its wrongness is invisible to the rules, which
/// is the point: only a hint ever judges it.
const int wrongCellA = 0;

/// A second free cell, whose solution is a square, so a circle there is wrong.
const int wrongCellB = 1;

/// The colour the symbol in the cell at [index] is drawn in.
Color symbolColour(WidgetTester tester, int index) {
  return tester.widget<Icon>(find.byKey(DuoBoard.markKey(index))).color!;
}

/// Taps the action-row control with this [id].
Future<void> tapAction(WidgetTester tester, String id) async {
  final Finder tile = find.byKey(BoardActionRow.keyFor(id));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pump();
}

/// Taps the hint control and waits out the pacing that follows it.
Future<void> tapHint(WidgetTester tester) async {
  await tapAction(tester, 'hint');
  await settleHintPacing(tester);
}

/// Cycles the cell at [index] until it shows [target].
Future<void> placeSymbol(WidgetTester tester, int index, DuoCell target) async {
  final DuoCell current = duoCellAt(tester, index);
  final int taps = (target.index - current.index) % DuoCell.values.length;
  for (int t = 0; t < taps; t++) {
    await tapDuoCell(tester, index);
  }
}

/// Puts the wrong symbol — the one the solution does not have — in the free
/// cell at [index].
Future<void> placeWrong(WidgetTester tester, int index) async {
  final DuoPuzzle puzzle = fixedDuoPuzzle();
  final DuoCell wrong = puzzle.solution[index] == DuoSymbol.circle
      ? DuoCell.square
      : DuoCell.circle;
  await placeSymbol(tester, index, wrong);
}

void main() {
  group('a hint gives a symbol', () {
    testWidgets('one the player could have worked out', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);

      await tapAction(tester, 'hint');

      expect(duoCellAt(tester, firstHintCell), firstHintSymbol);
      expect(
        DuoCell.of(fixedDuoPuzzle().solution[firstHintCell]),
        firstHintSymbol,
        reason: 'a hint has to agree with the puzzle it came from',
      );
    });

    testWidgets('marked as given away, not worked out', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);

      await tapAction(tester, 'hint');

      const NookColors colors = NookColors.softClay;
      expect(symbolColour(tester, firstHintCell), colors.hintInk);
      expect(colors.hintInk, isNot(colors.clay));
    });

    testWidgets('and a symbol the player places is theirs, not a hint\'s', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);

      // A symbol the player puts down themselves reads in the accent, so the
      // hint mark means what it says.
      await tapDuoCell(tester, wrongCellA);

      expect(symbolColour(tester, wrongCellA), NookColors.softClay.clay);
    });

    testWidgets('as many times as the player asks, right up to solved', (
      WidgetTester tester,
    ) async {
      // The point of the feature. There is no counter to run down and nothing
      // to buy: a player can hint their way through a whole board, and the
      // control only stops when the puzzle does.
      final DuoPuzzle puzzle = fixedDuoPuzzle();
      await pumpDuoGame(tester, puzzle: puzzle);
      final int empty = puzzle.spec.cellCount - puzzle.givenCount;

      for (int placed = 0; placed < empty - 1; placed++) {
        expect(
          actionEnabled(tester, 'hint'),
          isTrue,
          reason: 'the hint ran out after $placed of them',
        );
        await tapHint(tester);
      }

      // And the last one finishes it, which is what a player leaning on hints
      // alone has to be able to do.
      expect(actionEnabled(tester, 'hint'), isTrue);
      await tapAction(tester, 'hint');
      await tester.pumpAndSettle();

      expect(find.text(en.gameSolved), findsOneWidget);
      expect(
        find.byKey(BoardActionRow.keyFor('hint')),
        findsNothing,
        reason: 'the control outlived the puzzle it belonged to',
      );
    });
  });

  group('a hint takes a wrong symbol away before it gives one', () {
    testWidgets('it clears the mistake and reveals nothing', (
      WidgetTester tester,
    ) async {
      // The next move on a board carrying a mistake is to be rid of the
      // mistake. Revealing onto a board that still holds one would drop a
      // correct symbol into a poisoned line, and the board would mark its own
      // gift as a breach a frame later.
      await pumpDuoGame(tester);

      await placeWrong(tester, wrongCellA);
      expect(duoCellAt(tester, wrongCellA), isNot(DuoCell.empty));

      await tapAction(tester, 'hint');

      expect(duoCellAt(tester, wrongCellA), DuoCell.empty);
      expect(
        find.byKey(DuoBoard.markKey(firstHintCell)),
        findsNothing,
        reason:
            'a symbol was revealed on a press that should only have '
            'taken one away',
      );
    });

    testWidgets('the most recently placed one, one per press', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);

      // Two wrong symbols, oldest first. The newer one is the one the player
      // is still thinking about, so it goes first; taking the older would undo
      // whatever they built on top of it.
      await placeWrong(tester, wrongCellA);
      await placeWrong(tester, wrongCellB);

      await tapHint(tester);

      expect(duoCellAt(tester, wrongCellB), DuoCell.empty);
      expect(
        duoCellAt(tester, wrongCellA),
        isNot(DuoCell.empty),
        reason: 'both went on one press',
      );

      await tapAction(tester, 'hint');

      expect(duoCellAt(tester, wrongCellA), DuoCell.empty);
    });

    testWidgets('and reveals again once the board is clean', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);

      await placeWrong(tester, wrongCellA);
      await tapHint(tester);
      expect(duoCellAt(tester, wrongCellA), DuoCell.empty);

      await tapAction(tester, 'hint');

      expect(duoCellAt(tester, firstHintCell), firstHintSymbol);
    });

    testWidgets('the cell says what happened to a screen reader', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpDuoGame(tester);
        // Cell 0's solution is a circle, so the wrong symbol there is a
        // square, and a square is what the sentence has to name.
        await placeWrong(tester, wrongCellA);

        await tapAction(tester, 'hint');

        // Cell 0 is row 1, column 1.
        expect(
          find.bySemanticsLabel(en.cellDuoClearedSquare(1, 1)),
          findsOneWidget,
        );
        expect(find.byKey(DuoBoard.removalKey(wrongCellA)), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('nothing is drawn over the gap under less motion', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpDuoGame(tester, disableAnimations: true);
        await placeWrong(tester, wrongCellA);

        await tapAction(tester, 'hint');

        expect(duoCellAt(tester, wrongCellA), DuoCell.empty);
        expect(
          find.byKey(DuoBoard.removalKey(wrongCellA)),
          findsNothing,
          reason: 'a cross faded over a board asked to hold still',
        );
        // The sentence is not motion, so it is said either way.
        expect(
          find.bySemanticsLabel(en.cellDuoClearedSquare(1, 1)),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('undo puts the symbol back', (WidgetTester tester) async {
      await pumpDuoGame(tester);
      await placeWrong(tester, wrongCellA);

      await tapHint(tester);
      await tapAction(tester, 'undo');

      expect(duoCellAt(tester, wrongCellA), DuoCell.square);
    });

    testWidgets('and it still counts as having been helped', (
      WidgetTester tester,
    ) async {
      // Taking help is taking help, whichever direction it moved the board. A
      // removal marks nothing on the board — the cell is empty — but the
      // puzzle is a helped one from now on.
      final NookDatabase database = memoryDatabase();
      await pumpDuoGame(tester, database: database);
      await placeWrong(tester, wrongCellA);

      await tapAction(tester, 'hint');

      final SavedGame save = (await storedSave(
        tester,
        database,
        DuoVariant.duoId,
      ))!;
      expect(save.wasHinted, isTrue);
      expect(
        save.hints,
        isEmpty,
        reason: 'an emptied cell was marked as holding a hinted symbol',
      );
    });
  });

  group('a hint is a move like any other', () {
    testWidgets('undo takes back the symbol it gave', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);

      await tapAction(tester, 'hint');
      expect(duoCellAt(tester, firstHintCell), firstHintSymbol);

      await tapAction(tester, 'undo');

      expect(duoCellAt(tester, firstHintCell), DuoCell.empty);
      expect(actionEnabled(tester, 'undo'), isFalse);
    });

    testWidgets('and the cell stops being a hinted one', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpDuoGame(tester, database: database);

      await tapAction(tester, 'hint');

      SavedGame save = (await storedSave(tester, database, DuoVariant.duoId))!;
      expect(save.hints, <int>[firstHintCell]);
      expect(save.wasHinted, isTrue);

      await tapAction(tester, 'undo');

      save = (await storedSave(tester, database, DuoVariant.duoId))!;
      expect(
        save.hints,
        isEmpty,
        reason: 'a taken-back hint still marked a cell',
      );
      expect(
        save.wasHinted,
        isTrue,
        reason: 'undoing a hint cannot unshow what was shown',
      );
    });
  });

  group('a hint is paced', () {
    testWidgets('the control waits a few seconds, then comes back', (
      WidgetTester tester,
    ) async {
      // Pacing, not rationing. The wait is the room a hint needs to land, and
      // nothing anywhere is counting them.
      await pumpDuoGame(tester);

      await tapAction(tester, 'hint');

      expect(actionEnabled(tester, 'hint'), isFalse);
      expect(
        actionBackground(tester, 'hint'),
        NookColors.softClay.disabledSurface,
      );

      await tester.pump(kHintPacing ~/ 2);
      expect(actionEnabled(tester, 'hint'), isFalse);

      await settleHintPacing(tester);

      expect(actionEnabled(tester, 'hint'), isTrue);
      expect(actionBackground(tester, 'hint'), NookColors.softClay.surface);
    });

    testWidgets('after a hint that only took a symbol away, too', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);
      await placeWrong(tester, wrongCellA);

      await tapAction(tester, 'hint');

      expect(actionEnabled(tester, 'hint'), isFalse);

      await settleHintPacing(tester);

      expect(actionEnabled(tester, 'hint'), isTrue);
    });

    testWidgets('and a second hint is possible after waiting', (
      WidgetTester tester,
    ) async {
      // The wait is not a budget: once it is out, the next hint is there, and
      // it gives the next symbol rather than nothing.
      await pumpDuoGame(tester);

      await tapHint(tester);
      expect(duoCellAt(tester, firstHintCell), firstHintSymbol);

      await tapAction(tester, 'hint');

      expect(duoCellAt(tester, secondHintCell), isNot(DuoCell.empty));
    });

    testWidgets('the wait holds without moving under less motion', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester, disableAnimations: true);

      await tapAction(tester, 'hint');

      expect(actionEnabled(tester, 'hint'), isFalse);
      expect(
        find.byKey(BoardActionRow.paceKey('hint')),
        findsNothing,
        reason: 'a bar filled across a control asked to hold still',
      );

      await settleHintPacing(tester);

      expect(actionEnabled(tester, 'hint'), isTrue);
    });

    testWidgets('and a screen reader is told why it cannot be used', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpDuoGame(tester);

        await tapAction(tester, 'hint');

        expect(
          find.bySemanticsLabel(
            en.actionUnavailableLabel(en.actionHint, en.reasonHintJustGiven),
          ),
          findsOneWidget,
        );

        await settleHintPacing(tester);

        expect(find.bySemanticsLabel(en.actionHint), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });
  });

  group('a helped solve', () {
    testWidgets('records a time but no personal best', (
      WidgetTester tester,
    ) async {
      // A hint anywhere makes the whole puzzle a helped one: it still counts
      // as solved and keeps its time, but it never sets a best, because a best
      // a hint could set would mean nothing.
      final NookDatabase database = memoryDatabase();
      final DuoPuzzle puzzle = fixedDuoPuzzle();
      await pumpDuoGame(tester, puzzle: puzzle, database: database);

      // A wrong symbol, taken away by a hint, is enough to mark the puzzle
      // helped.
      await placeWrong(tester, wrongCellA);
      await tapHint(tester);

      await solveDuo(tester, puzzle);
      expect(find.text(en.gameSolved), findsOneWidget);

      final List<GameStats> stats = await storedStats(tester, database);
      final GameStats? row = statsFor(
        stats,
        gameId: DuoVariant.duoId,
        difficulty: PuzzleDifficulty.gentle.name,
      );
      expect(row, isNotNull);
      expect(row!.solved, 1);
      expect(
        row.bestTime,
        isNull,
        reason: 'a hinted solve set a personal best',
      );
    });
  });
}
