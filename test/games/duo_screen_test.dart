import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/duo_board.dart';
import 'package:nook/chrome/completion_view.dart';
import 'package:nook/games/duo/duo_state.dart';
import 'package:nook/games/duo/duo_variant.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/duo_fixture.dart';

void main() {
  final DuoPuzzle puzzle = fixedDuoPuzzle();
  final int blank = puzzle.givens.indexWhere((DuoSymbol? s) => s == null);
  final int givenIndex = puzzle.givens.indexWhere((DuoSymbol? s) => s != null);

  group('the home screen', () {
    testWidgets('lists Duo as playable and opens it', (
      WidgetTester tester,
    ) async {
      await pumpDuoHome(tester);

      // The row is live, not greyed with "coming soon".
      expect(find.text(en.duoSubtitle), findsOneWidget);
      expect(
        find.bySemanticsLabel(en.gameRowUnavailableLabel(en.duoTitle)),
        findsNothing,
      );

      await tester.tap(find.text(en.duoTitle));
      await tester.pumpAndSettle();
      expect(find.byType(DuoBoard), findsOneWidget);
      expect(find.text(en.duoLegendCircle), findsOneWidget);
    });
  });

  group('the board', () {
    testWidgets('cycles a cell empty → circle → square → empty', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);

      expect(duoCellAt(tester, blank), DuoCell.empty);
      await tapDuoCell(tester, blank);
      expect(duoCellAt(tester, blank), DuoCell.circle);
      await tapDuoCell(tester, blank);
      expect(duoCellAt(tester, blank), DuoCell.square);
      await tapDuoCell(tester, blank);
      expect(duoCellAt(tester, blank), DuoCell.empty);
    });

    testWidgets('a given cell does not change on tap', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);

      final DuoCell before = duoCellAt(tester, givenIndex);
      expect(before, isNot(DuoCell.empty));
      await tapDuoCell(tester, givenIndex);
      expect(duoCellAt(tester, givenIndex), before);
    });
  });

  group('finishing', () {
    testWidgets('lands on the completion screen with a time', (
      WidgetTester tester,
    ) async {
      final TestClock clock = TestClock();
      await pumpDuoGame(tester, clock: clock);
      clock.advance(const Duration(minutes: 2, seconds: 5));

      await solveDuo(tester, puzzle);

      expect(find.text(en.gameSolved), findsOneWidget);
      expect(find.byKey(GameCompletionView.timeKey), findsOneWidget);
      expect(find.byType(DuoBoard), findsNothing);
    });

    testWidgets('records a solve under game id duo', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpDuoGame(tester, database: database);

      await solveDuo(tester, puzzle);
      await tester.pumpAndSettle();

      final List<GameStats> stats = await storedStats(tester, database);
      final GameStats duo = stats.singleWhere(
        (GameStats s) => s.gameId == DuoVariant.duoId,
      );
      expect(duo.solved, 1);
      expect(duo.difficulty, PuzzleDifficulty.gentle.name);
    });
  });
}
