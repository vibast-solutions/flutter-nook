import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/chrome/completion_view.dart';
import 'package:nook/games/stars/stars_variant.dart';
import 'package:nook/games/stars/stars_state.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/stars_fixture.dart';

/// The figure printed on the completion card [key].
String figureOn(WidgetTester tester, Key key) {
  final List<Text> lines = tester
      .widgetList<Text>(
        find.descendant(of: find.byKey(key), matching: find.byType(Text)),
      )
      .toList();
  return lines.last.data!;
}

void main() {
  group('opening Stars', () {
    testWidgets('reaches a board from the home screen', (
      WidgetTester tester,
    ) async {
      await pumpStarsHome(tester);
      // The Stars row no longer says it is on the way.
      expect(find.text(en.starsSubtitle), findsOneWidget);
      expect(en.starsSubtitle, isNot(contains('coming soon')));

      await tester.tap(find.text(en.starsTitle));
      await tester.pumpAndSettle();

      expect(find.byType(StarsBoard), findsOneWidget);
      expect(
        find.text(en.gameSubtitle(en.gridSize(8), en.difficultyGentle)),
        findsOneWidget,
      );
    });
  });

  group('marking a cell', () {
    testWidgets('a tap cycles empty → ruled out → star → empty', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      expect(starMarkAt(tester, 0), StarsMark.empty);
      await tapStarsCell(tester, 0);
      expect(starMarkAt(tester, 0), StarsMark.ruledOut);
      await tapStarsCell(tester, 0);
      expect(starMarkAt(tester, 0), StarsMark.star);
      await tapStarsCell(tester, 0);
      expect(starMarkAt(tester, 0), StarsMark.empty);
    });

    testWidgets('the counter follows the stars on the board', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);
      expect(find.text(en.starsCounter(0, 8)), findsOneWidget);

      // Two taps on a cell is one star.
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 0);
      expect(find.text(en.starsCounter(1, 8)), findsOneWidget);
    });
  });

  group('finishing a puzzle', () {
    testWidgets('lands on the completion screen with a time', (
      WidgetTester tester,
    ) async {
      final TestClock clock = TestClock();
      final StarsPuzzle puzzle = fixedStarsPuzzle();
      await pumpStarsGame(
        tester,
        puzzle: puzzle,
        database: memoryDatabase(),
        clock: clock,
      );

      clock.advance(const Duration(seconds: 92));
      await solveStars(tester, puzzle);

      expect(find.text(en.gameSolved), findsOneWidget);
      expect(
        find.text(en.completionSubtitle(en.starsTitle, en.difficultyGentle)),
        findsOneWidget,
      );
      expect(figureOn(tester, GameCompletionView.timeKey), '01:32');
      expect(find.byType(StarsBoard), findsNothing);
    });

    testWidgets('counts the solve under game id stars', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      final StarsPuzzle puzzle = fixedStarsPuzzle();
      await pumpStarsGame(
        tester,
        puzzle: puzzle,
        database: database,
        clock: clock,
      );

      clock.advance(const Duration(minutes: 2));
      await solveStars(tester, puzzle);

      expect(figureOn(tester, GameCompletionView.solvedKey), '1');
      final GameStats stats = (await storedStats(tester, database)).single;
      expect(stats.gameId, StarsVariant.starsId);
      expect(stats.difficulty, PuzzleDifficulty.gentle.name);
      expect(stats.solved, 1);
      expect(stats.bestTime, const Duration(minutes: 2));
    });
  });
}
