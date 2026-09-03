import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/stars/stars_state.dart';
import 'package:nook/games/stars/stars_variant.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/stars_fixture.dart';

/// The first star the fixture puzzle gives from an empty board.
///
/// Cell 6 is the star the technique solver reaches first — the one open cell of
/// its region — so it is the star a hint offers before the player has placed any
/// of their own. It is written out rather than asked of the solver, so a change
/// to which star a hint picks shows up here as a failing expectation instead of
/// passing quietly.
const int firstHintCell = 6;

/// The next star the solver reaches, once [firstHintCell] is down.
const int secondHintCell = 23;

/// The colour the star in the cell at [index] is drawn in.
Color starColour(WidgetTester tester, int index) {
  return tester.widget<Icon>(find.byKey(StarsBoard.markKey(index))).color!;
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

/// Places a star in the cell at [index]: two taps, empty → ruled out → star.
Future<void> placeStar(WidgetTester tester, int index) async {
  await tapStarsCell(tester, index);
  await tapStarsCell(tester, index);
}

/// The region a screen reader names for the cell at [index], counted from one.
int region1Of(int index) => fixedStarsPuzzle().regionOf(index) + 1;

void main() {
  group('a hint gives a star', () {
    testWidgets('one the player could have worked out', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      await tapAction(tester, 'hint');

      expect(starMarkAt(tester, firstHintCell), StarsMark.star);
      expect(
        fixedStarsPuzzle().solution,
        contains(firstHintCell),
        reason: 'a hint has to agree with the puzzle it came from',
      );
    });

    testWidgets('marked as given away, not worked out', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      await tapAction(tester, 'hint');

      const NookColors colors = NookColors.softClay;
      expect(starColour(tester, firstHintCell), colors.hintInk);
      expect(colors.hintInk, isNot(colors.ink));
    });

    testWidgets('and a star the player places is theirs, not a hint\'s', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      // A star the player puts down themselves reads in the plain ink, so the
      // hint mark means what it says.
      await placeStar(tester, 0);

      expect(starColour(tester, 0), NookColors.softClay.ink);
    });

    testWidgets('as many times as the player asks, right up to solved', (
      WidgetTester tester,
    ) async {
      // The point of the feature. There is no counter to run down and nothing
      // to buy: a player can hint their way through a whole board, and the
      // control only stops when the puzzle does.
      final StarsPuzzle puzzle = fixedStarsPuzzle();
      await pumpStarsGame(tester, puzzle: puzzle);

      for (int placed = 0; placed < puzzle.solution.length - 1; placed++) {
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

  group('a hint takes a wrong star away before it gives one', () {
    testWidgets('it clears the mistake and reveals nothing', (
      WidgetTester tester,
    ) async {
      // The next move on a board carrying a mistake is to be rid of the
      // mistake. Revealing onto a board that still holds one would drop a
      // correct star into a poisoned row, and the board would mark its own gift
      // as a breach a frame later.
      await pumpStarsGame(tester);

      // Cell 0 is not one of the puzzle's stars, so a star there is wrong.
      await placeStar(tester, 0);
      expect(starMarkAt(tester, 0), StarsMark.star);

      await tapAction(tester, 'hint');

      expect(starMarkAt(tester, 0), StarsMark.empty);
      expect(
        find.byKey(StarsBoard.markKey(firstHintCell)),
        findsNothing,
        reason:
            'a star was revealed on a press that should only have '
            'taken one away',
      );
    });

    testWidgets('the most recently placed one, one per press', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      // Two wrong stars, oldest first. The newer one is the one the player is
      // still thinking about, so it goes first; taking the older would undo
      // whatever they built on top of it.
      await placeStar(tester, 0);
      await placeStar(tester, 1);

      await tapHint(tester);

      expect(starMarkAt(tester, 1), StarsMark.empty);
      expect(
        starMarkAt(tester, 0),
        StarsMark.star,
        reason: 'both went on one press',
      );

      await tapAction(tester, 'hint');

      expect(starMarkAt(tester, 0), StarsMark.empty);
    });

    testWidgets('and reveals again once the board is clean', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      await placeStar(tester, 0);
      await tapHint(tester);
      expect(starMarkAt(tester, 0), StarsMark.empty);

      await tapAction(tester, 'hint');

      expect(starMarkAt(tester, firstHintCell), StarsMark.star);
    });

    testWidgets('the cell says what happened to a screen reader', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpStarsGame(tester);
        await placeStar(tester, 0);

        await tapAction(tester, 'hint');

        // Cell 0 is row 1, column 1.
        expect(
          find.bySemanticsLabel(en.cellStarsCleared(1, 1, region1Of(0))),
          findsOneWidget,
        );
        expect(find.byKey(StarsBoard.removalKey(0)), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('nothing is drawn over the gap under less motion', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpStarsGame(tester, disableAnimations: true);
        await placeStar(tester, 0);

        await tapAction(tester, 'hint');

        expect(starMarkAt(tester, 0), StarsMark.empty);
        expect(
          find.byKey(StarsBoard.removalKey(0)),
          findsNothing,
          reason: 'a cross faded over a board asked to hold still',
        );
        // The sentence is not motion, so it is said either way.
        expect(
          find.bySemanticsLabel(en.cellStarsCleared(1, 1, region1Of(0))),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('undo puts the star back', (WidgetTester tester) async {
      await pumpStarsGame(tester);
      await placeStar(tester, 0);

      await tapHint(tester);
      await tapAction(tester, 'undo');

      expect(starMarkAt(tester, 0), StarsMark.star);
    });

    testWidgets('and it still counts as having been helped', (
      WidgetTester tester,
    ) async {
      // Taking help is taking help, whichever direction it moved the board. A
      // removal marks nothing on the board — the cell is empty — but the puzzle
      // is a helped one from now on.
      final NookDatabase database = memoryDatabase();
      await pumpStarsGame(tester, database: database);
      await placeStar(tester, 0);

      await tapAction(tester, 'hint');

      final SavedGame save = (await storedSave(
        tester,
        database,
        StarsVariant.starsId,
      ))!;
      expect(save.wasHinted, isTrue);
      expect(
        save.hints,
        isEmpty,
        reason: 'an emptied cell was marked as holding a hinted star',
      );
    });
  });

  group('a hint is a move like any other', () {
    testWidgets('undo takes back the star it gave', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      await tapAction(tester, 'hint');
      expect(starMarkAt(tester, firstHintCell), StarsMark.star);

      await tapAction(tester, 'undo');

      expect(starMarkAt(tester, firstHintCell), StarsMark.empty);
      expect(actionEnabled(tester, 'undo'), isFalse);
    });

    testWidgets('and the cell stops being a hinted one', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpStarsGame(tester, database: database);

      await tapAction(tester, 'hint');

      SavedGame save = (await storedSave(
        tester,
        database,
        StarsVariant.starsId,
      ))!;
      expect(save.hints, <int>[firstHintCell]);
      expect(save.wasHinted, isTrue);

      await tapAction(tester, 'undo');

      save = (await storedSave(tester, database, StarsVariant.starsId))!;
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
      await pumpStarsGame(tester);

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

    testWidgets('after a hint that only took a star away, too', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);
      await placeStar(tester, 0);

      await tapAction(tester, 'hint');

      expect(actionEnabled(tester, 'hint'), isFalse);

      await settleHintPacing(tester);

      expect(actionEnabled(tester, 'hint'), isTrue);
    });

    testWidgets('and a second hint is possible after waiting', (
      WidgetTester tester,
    ) async {
      // The wait is not a budget: once it is out, the next hint is there, and
      // it gives the next star rather than nothing.
      await pumpStarsGame(tester);

      await tapHint(tester);
      expect(starMarkAt(tester, firstHintCell), StarsMark.star);

      await tapAction(tester, 'hint');

      expect(starMarkAt(tester, secondHintCell), StarsMark.star);
    });

    testWidgets('the wait holds without moving under less motion', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester, disableAnimations: true);

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
        await pumpStarsGame(tester);

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
      // A hint anywhere makes the whole puzzle a helped one: it still counts as
      // solved and keeps its time, but it never sets a best, because a best a
      // hint could set would mean nothing.
      final NookDatabase database = memoryDatabase();
      final StarsPuzzle puzzle = fixedStarsPuzzle();
      await pumpStarsGame(tester, puzzle: puzzle, database: database);

      // A wrong star, taken away by a hint, is enough to mark the puzzle helped.
      await placeStar(tester, nonSolutionCell(puzzle));
      await tapHint(tester);

      await solveStars(tester, puzzle);
      expect(find.text(en.gameSolved), findsOneWidget);

      final List<GameStats> stats = await storedStats(tester, database);
      final GameStats? row = statsFor(
        stats,
        gameId: StarsVariant.starsId,
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

/// The first cell that holds no star in [puzzle]'s solution — somewhere a wrong
/// star can go without standing on the answer.
int nonSolutionCell(StarsPuzzle puzzle) {
  for (int index = 0; index < puzzle.spec.cellCount; index++) {
    if (!puzzle.solution.contains(index)) {
      return index;
    }
  }
  throw StateError('every cell is a star, which no Stars board is');
}
