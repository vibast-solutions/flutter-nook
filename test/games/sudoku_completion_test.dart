import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/number_pad.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/games/sudoku/completion_view.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

/// The figure printed on the card [key].
String figureOn(WidgetTester tester, Key key) {
  final List<Text> lines = tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .toList();
  return lines.last.data!;
}

/// Finishes the fixture 4x4 after [after] of play.
Future<void> playAndSolve(
  WidgetTester tester,
  TestClock clock, {
  Duration after = const Duration(minutes: 1),
  bool withHint = false,
}) async {
  clock.advance(after);
  if (withHint) {
    await tapAction(tester, 'hint');
  }
  await solvePuzzle(tester, fixedMiniPuzzle());
}

void main() {
  group('finishing a puzzle', () {
    testWidgets('replaces the board with what the player did', (
      WidgetTester tester,
    ) async {
      final TestClock clock = TestClock();
      await pumpSudokuGame(tester, database: memoryDatabase(), clock: clock);

      await playAndSolve(tester, clock, after: const Duration(seconds: 92));

      expect(find.text(en.gameSolved), findsOneWidget);
      expect(
        find.text(
          en.completionSubtitle(en.sudokuMiniTitle, en.difficultyGentle),
        ),
        findsOneWidget,
      );
      expect(figureOn(tester, SudokuCompletionView.timeKey), '01:32');
      expect(find.byType(SudokuBoard), findsNothing);
      expect(find.byType(NumberPad), findsNothing);
    });

    testWidgets('counts it, and says so', (WidgetTester tester) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await pumpSudokuGame(tester, database: database, clock: clock);

      await playAndSolve(tester, clock);

      expect(figureOn(tester, SudokuCompletionView.solvedKey), '1');
      final GameStats stats = (await storedStats(tester, database)).single;
      expect(stats.gameId, SudokuVariant.miniId);
      expect(stats.difficulty, SudokuDifficulty.gentle.name);
      expect(stats.solved, 1);
      expect(stats.bestTime, const Duration(minutes: 1));
    });

    testWidgets('and counts the next one too', (WidgetTester tester) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await pumpSudokuGame(tester, database: database, clock: clock);
      await playAndSolve(tester, clock);

      await tester.tap(find.byKey(SudokuCompletionView.anotherKey));
      await tester.pumpAndSettle();
      // The screen goes back to a board: the result belonged to the puzzle
      // that produced it, not to the game.
      expect(find.byType(SudokuBoard), findsOneWidget);
      expect(find.text(en.gameSolved), findsNothing);

      await playAndSolve(tester, clock);

      expect(figureOn(tester, SudokuCompletionView.solvedKey), '2');
      expect((await storedStats(tester, database)).single.solved, 2);
    });
  });

  group('the best time', () {
    testWidgets('a first solve is a personal best, with nothing before it', (
      WidgetTester tester,
    ) async {
      final TestClock clock = TestClock();
      await pumpSudokuGame(tester, database: memoryDatabase(), clock: clock);

      await playAndSolve(tester, clock);

      expect(find.byKey(SudokuCompletionView.personalBestKey), findsOneWidget);
      expect(find.text(en.completionPersonalBest), findsOneWidget);
      expect(
        figureOn(tester, SudokuCompletionView.previousKey),
        en.completionNoTime,
        reason: 'there was no previous time, and a zero would read as one',
      );
    });

    testWidgets('a slower puzzle is not one, and says what to beat', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await pumpSudokuGame(tester, database: database, clock: clock);
      await playAndSolve(tester, clock, after: const Duration(minutes: 1));

      await tester.tap(find.byKey(SudokuCompletionView.anotherKey));
      await tester.pumpAndSettle();
      await playAndSolve(tester, clock, after: const Duration(minutes: 5));

      expect(
        find.byKey(SudokuCompletionView.personalBestKey),
        findsNothing,
        reason: 'a slower puzzle was called a personal best',
      );
      expect(figureOn(tester, SudokuCompletionView.timeKey), '05:00');
      expect(figureOn(tester, SudokuCompletionView.previousKey), '01:00');
      expect(
        (await storedStats(tester, database)).single.bestTime,
        const Duration(minutes: 1),
        reason: 'the slower time was written down as the best',
      );
    });

    testWidgets('and a faster one is', (WidgetTester tester) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await pumpSudokuGame(tester, database: database, clock: clock);
      await playAndSolve(tester, clock, after: const Duration(minutes: 5));

      await tester.tap(find.byKey(SudokuCompletionView.anotherKey));
      await tester.pumpAndSettle();
      await playAndSolve(tester, clock, after: const Duration(minutes: 1));

      expect(find.byKey(SudokuCompletionView.personalBestKey), findsOneWidget);
      expect(figureOn(tester, SudokuCompletionView.previousKey), '05:00');
      expect(
        (await storedStats(tester, database)).single.bestTime,
        const Duration(minutes: 1),
      );
    });

    testWidgets('a hinted puzzle counts, times, and sets no best', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await pumpSudokuGame(tester, database: database, clock: clock);

      await playAndSolve(
        tester,
        clock,
        after: const Duration(seconds: 30),
        withHint: true,
      );

      expect(figureOn(tester, SudokuCompletionView.timeKey), '00:30');
      expect(figureOn(tester, SudokuCompletionView.solvedKey), '1');
      expect(
        find.byKey(SudokuCompletionView.personalBestKey),
        findsNothing,
        reason: 'a hint set a personal best',
      );

      final GameStats stats = (await storedStats(tester, database)).single;
      expect(stats.solved, 1, reason: 'a hinted puzzle is still solved');
      expect(stats.bestTime, isNull);
    });

    testWidgets('and cannot take a best time the player already has', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await pumpSudokuGame(tester, database: database, clock: clock);
      await playAndSolve(tester, clock, after: const Duration(minutes: 5));

      await tester.tap(find.byKey(SudokuCompletionView.anotherKey));
      await tester.pumpAndSettle();
      await playAndSolve(
        tester,
        clock,
        after: const Duration(seconds: 30),
        withHint: true,
      );

      expect(find.byKey(SudokuCompletionView.personalBestKey), findsNothing);
      expect(figureOn(tester, SudokuCompletionView.previousKey), '05:00');
      expect(
        (await storedStats(tester, database)).single.bestTime,
        const Duration(minutes: 5),
        reason: 'a helped puzzle took the best time',
      );
    });
  });

  group('a puzzle nobody finished', () {
    testWidgets('is not recorded, however much of it was played', (
      WidgetTester tester,
    ) async {
      // There is no failure statistic anywhere in Nook. Walking away from a
      // puzzle leaves the save and nothing else.
      final NookDatabase database = memoryDatabase();
      await pumpSudokuGame(tester, database: database);

      await tapCell(tester, 0);
      await tapDigit(tester, 1);
      await tapCell(tester, 1);
      await tapDigit(tester, 2);
      // The player leaves the game screen.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      expect(await storedStats(tester, database), isEmpty);
    });
  });

  group('the screen asks nothing of the player', () {
    testWidgets('it offers a puzzle, the way out, and nothing else', (
      WidgetTester tester,
    ) async {
      // The guard on the rule that this moment is never spent: no tip prompt,
      // no rating request, no promotion. Three controls, and every one of them
      // is about the puzzles.
      final TestClock clock = TestClock();
      await pumpSudokuGame(tester, database: memoryDatabase(), clock: clock);

      await playAndSolve(tester, clock);

      expect(find.byType(InkWell), findsNWidgets(3));
      expect(find.byKey(SudokuCompletionView.anotherKey), findsOneWidget);
      expect(find.byKey(SudokuCompletionView.homeKey), findsOneWidget);
      expect(find.byKey(SudokuCompletionView.closeKey), findsOneWidget);
      expect(
        find.text(en.completionAnother(en.difficultyGentle)),
        findsOneWidget,
      );
      expect(find.text(en.completionBackHome), findsOneWidget);
    });

    testWidgets('and reads out what it says', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        final TestClock clock = TestClock();
        await pumpSudokuGame(tester, database: memoryDatabase(), clock: clock);

        await playAndSolve(tester, clock, after: const Duration(minutes: 2));

        expect(
          find.bySemanticsLabel(en.completionTimeLabel('02:00')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(en.completionNoPreviousLabel),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(en.completionSolvedLabel(1)),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel(en.completionClose), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });
  });

  group('the ways out', () {
    testWidgets('another puzzle keeps the game and the difficulty', (
      WidgetTester tester,
    ) async {
      final TestClock clock = TestClock();
      await pumpSudokuGame(tester, database: memoryDatabase(), clock: clock);
      await playAndSolve(tester, clock);

      await tester.tap(find.byKey(SudokuCompletionView.anotherKey));
      await tester.pumpAndSettle();

      expect(find.byType(SudokuBoard), findsOneWidget);
      expect(
        find.text(en.gameSubtitle(en.gridSize(4), en.difficultyGentle)),
        findsOneWidget,
      );
      expect(digitIn(tester, 0), isNull, reason: 'the old answers came back');
      expect(
        find.text('00:00'),
        findsOneWidget,
        reason: 'the new puzzle started on the finished one\'s clock',
      );
    });

    testWidgets('closing goes back to this game\'s difficulties', (
      WidgetTester tester,
    ) async {
      final TestClock clock = TestClock();
      await pumpDifficultyThenPlay(tester, clock);

      await tester.tap(find.byKey(SudokuCompletionView.closeKey));
      await tester.pumpAndSettle();

      expect(find.text(en.difficultyStartNew), findsOneWidget);
    });

    testWidgets('and Back to Nook goes all the way to the game list', (
      WidgetTester tester,
    ) async {
      final TestClock clock = TestClock();
      await pumpDifficultyThenPlay(tester, clock);

      await tester.tap(find.byKey(SudokuCompletionView.homeKey));
      await tester.pumpAndSettle();

      expect(find.text(en.homeAllGames), findsOneWidget);
      expect(find.text(en.difficultyStartNew), findsNothing);
    });
  });
}

/// Walks in from the home screen, picks Gentle, and finishes the puzzle.
///
/// The long way round, because the buttons under test are about where the
/// player ends up rather than about what they say.
Future<void> pumpDifficultyThenPlay(
  WidgetTester tester,
  TestClock clock,
) async {
  await pumpHome(tester, database: memoryDatabase(), clock: clock);
  await tester.tap(find.text(en.sudokuMiniTitle));
  await tester.pumpAndSettle();
  await tester.tap(find.text(en.difficultyGentle));
  await tester.pumpAndSettle();
  clock.advance(const Duration(minutes: 1));
  await solvePuzzle(tester, fixedMiniPuzzle());
}
