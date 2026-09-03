import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/duo_board.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/duo_fixture.dart';

/// The background colour of the cell at [index].
Color cellBackground(WidgetTester tester, int index) {
  final Container box = tester.widget<Container>(
    find.descendant(
      of: find.byKey(DuoBoard.cellKey(index)),
      matching: find.byType(Container),
    ),
  );
  return (box.decoration! as BoxDecoration).color!;
}

void main() {
  final DuoPuzzle puzzle = fixedDuoPuzzle();

  group('DuoBoard', () {
    test('the fixture exercises both badge kinds and both orientations', () {
      // The board tests below lean on the fixture having something to draw; if a
      // future generator change emptied it, this fails first and loudly.
      expect(
        puzzle.badges.any((DuoBadge b) => b.relation == DuoRelation.equal),
        isTrue,
      );
      expect(
        puzzle.badges.any((DuoBadge b) => b.relation == DuoRelation.unequal),
        isTrue,
      );
      expect(puzzle.badges.any((DuoBadge b) => b.isHorizontal), isTrue);
      expect(puzzle.badges.any((DuoBadge b) => !b.isHorizontal), isTrue);
    });

    testWidgets('the two symbols differ in shape, not only colour', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);
      final int blankA = puzzle.givens.indexWhere((DuoSymbol? s) => s == null);
      final int blankB = puzzle.givens.lastIndexWhere(
        (DuoSymbol? s) => s == null,
      );

      await tapDuoCell(tester, blankA); // once: circle
      await tapDuoCell(tester, blankB); // twice: square
      await tapDuoCell(tester, blankB);

      final Icon circle = tester.widget<Icon>(
        find.byKey(DuoBoard.markKey(blankA)),
      );
      final Icon square = tester.widget<Icon>(
        find.byKey(DuoBoard.markKey(blankB)),
      );
      expect(circle.icon, DuoBoard.circleIcon);
      expect(square.icon, DuoBoard.squareIcon);
      expect(circle.icon, isNot(square.icon));
    });

    testWidgets('draws every badge, on the edge between its two cells', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);

      // One badge widget per badge, no more and no fewer.
      expect(
        find.byKey(
          DuoBoard.badgeKey(puzzle.badges.first.a, puzzle.badges.first.b),
        ),
        findsOneWidget,
      );

      for (final DuoBadge badge in puzzle.badges) {
        final Rect a = tester.getRect(find.byKey(DuoBoard.cellKey(badge.a)));
        final Rect b = tester.getRect(find.byKey(DuoBoard.cellKey(badge.b)));
        final Offset expected = Offset(
          (a.center.dx + b.center.dx) / 2,
          (a.center.dy + b.center.dy) / 2,
        );
        final Offset drawn = tester
            .getRect(find.byKey(DuoBoard.badgeKey(badge.a, badge.b)))
            .center;
        expect(
          (drawn - expected).distance,
          lessThan(1.0),
          reason: 'badge $badge is not centred on its edge',
        );
      }
    });

    testWidgets('a given reads distinct from a player cell', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);
      final int given = puzzle.givens.indexWhere((DuoSymbol? s) => s != null);
      final int blank = puzzle.givens.indexWhere((DuoSymbol? s) => s == null);

      // The two backgrounds differ, so a fixed cell never looks like an empty
      // one waiting to be filled.
      expect(
        cellBackground(tester, given),
        isNot(cellBackground(tester, blank)),
      );
    });

    testWidgets('the legend explains both symbols and both badges', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);
      expect(find.text(en.duoLegendCircle), findsOneWidget);
      expect(find.text(en.duoLegendSquare), findsOneWidget);
      expect(find.text(en.duoLegendEqual), findsOneWidget);
      expect(find.text(en.duoLegendUnequal), findsOneWidget);
    });
  });
}
