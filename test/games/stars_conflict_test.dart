import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/stars/stars_state.dart';
import 'package:nook/games/stars/stars_variant.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/stars_fixture.dart';

/// The region of cell [index] on the test board: blocks two cells wide and four
/// tall, eight of them, so row, column and region are three independent things.
///
/// A banded map — a region per row, or per column — would make a shared row
/// double as a shared region and there would be no way to test one breach in
/// isolation from the other. Blocks keep them apart.
int blockRegion(int index) {
  const int size = 8;
  final int row = index ~/ size;
  final int column = index % size;
  return (column ~/ 2) + (row ~/ 4) * 4;
}

/// A Stars game holding [stars] and [dots], with a chosen region map.
///
/// Built straight rather than tapped: what is under test is a reading of the
/// grid, and saying which cells hold what is the shortest way to name a board.
/// [solution] is never read by the breach code, so it defaults to a throwaway.
StarsGameState board({
  Set<int> stars = const <int>{},
  Set<int> dots = const <int>{},
  int Function(int) regionOf = blockRegion,
  List<int>? solution,
}) {
  const StarsSpec spec = StarsSpec.standard;
  final StarsPuzzle puzzle = StarsPuzzle(
    spec: spec,
    seed: 0,
    regions: <int>[for (int i = 0; i < spec.cellCount; i++) regionOf(i)],
    solution:
        solution ?? <int>[for (int i = 0; i < spec.size; i++) i * spec.size],
  );
  final List<StarsMark> cells = List<StarsMark>.filled(
    spec.cellCount,
    StarsMark.empty,
  );
  for (final int star in stars) {
    cells[star] = StarsMark.star;
  }
  for (final int dot in dots) {
    cells[dot] = StarsMark.ruledOut;
  }
  return StarsGameState(
    variant: StarsVariant.standard,
    puzzle: puzzle,
    cells: cells,
  );
}

/// Pumps [game]'s board on its own, so a test can put any grid in front of a
/// screen reader without driving the controller to it.
Future<void> pumpBoard(WidgetTester tester, StarsGameState game) async {
  await setPhoneSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildNookTheme(NookColors.softClay),
      home: Scaffold(
        body: StarsBoard(game: game, onTap: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps the control with this [id] in the row under the board.
Future<void> tapAction(WidgetTester tester, String id) async {
  final Finder tile = find.byKey(BoardActionRow.keyFor(id));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pump();
}

void main() {
  group('a breach is a rule being broken', () {
    test('two stars in a row mark both', () {
      // Cells 0 and 3 sit in row 0, in different blocks, with a gap between
      // them: nothing but the row can be doing this.
      expect(board(stars: <int>{0, 3}).breaches, <int>{0, 3});
    });

    test('two stars in a column mark both', () {
      // Cells 0 and 32 are column 0, four rows and two blocks apart.
      expect(board(stars: <int>{0, 32}).breaches, <int>{0, 32});
    });

    test('two stars in a region mark both', () {
      // Cells 0 and 17 share the top-left block and nothing else — different
      // rows, different columns, not touching.
      expect(board(stars: <int>{0, 17}).breaches, <int>{0, 17});
    });

    test('two stars touching diagonally mark both', () {
      // Cells 1 and 10 are a diagonal step apart, in different rows, columns
      // and blocks: only the touching rule marks them.
      expect(board(stars: <int>{1, 10}).breaches, <int>{1, 10});
    });

    test('an empty board has no breach', () {
      expect(board().breaches, isEmpty);
    });
  });

  group('a breach is never a judgement', () {
    test('a star that breaks nothing is left alone, however wrong it is', () {
      // A lone star breaks no rule: no other star in its row, column or region,
      // and nothing touching it. The board says nothing, because a board that
      // marked it would be an oracle to brute-force rather than a puzzle.
      final StarsGameState game = board(stars: <int>{0});
      expect(game.breaches, isEmpty);
      expect(game.isBreaching(0), isFalse);
    });

    test('a ruled-out dot is never marked', () {
      // Dots share the star's row (cell 3), its column (cell 8) and touch it
      // (cell 1). An annotation cannot break a rule, so none of them is marked
      // and the lone star still breaks nothing.
      final StarsGameState game = board(stars: <int>{0}, dots: <int>{1, 3, 8});
      expect(game.breaches, isEmpty);
      for (final int dot in <int>[1, 3, 8]) {
        expect(game.isBreaching(dot), isFalse);
      }
    });

    test('swapping the solution changes nothing at all', () {
      // The guard on the rule. Same stars and regions, a different stored
      // answer: if any reading of the solution had crept in, the two would
      // disagree here.
      final StarsGameState honest = board(
        stars: <int>{0, 1},
        solution: <int>[0, 1, 2, 3, 4, 5, 6, 7],
      );
      final StarsGameState fooled = board(
        stars: <int>{0, 1},
        solution: <int>[8, 9, 10, 11, 12, 13, 14, 15],
      );
      expect(honest.breaches, fooled.breaches);
      expect(honest.breaches, isNotEmpty);
    });
  });

  group('the board shows a breach', () {
    testWidgets('with a texture as well as a colour', (
      WidgetTester tester,
    ) async {
      // Colour alone would be silent for the players most likely to need it, so
      // the hatch is a widget of its own — found here with the wash's colour
      // ignored entirely.
      await pumpStarsGame(tester);

      expect(find.byKey(StarsBoard.breachKey(0)), findsNothing);

      // Two stars side by side: cells 0 and 1 touch, so both are marked.
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 1);
      await tapStarsCell(tester, 1);

      expect(find.byKey(StarsBoard.breachKey(0)), findsOneWidget);
      expect(
        find.byKey(StarsBoard.breachKey(1)),
        findsOneWidget,
        reason: 'only one half of the pair was marked',
      );
    });

    testWidgets('until the offending star is erased', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 1);
      await tapStarsCell(tester, 1);
      expect(find.byKey(StarsBoard.breachKey(0)), findsOneWidget);

      // Cell 1 is selected after its taps; erasing it leaves cell 0 alone.
      await tapAction(tester, 'erase');

      expect(find.byKey(StarsBoard.breachKey(0)), findsNothing);
      expect(find.byKey(StarsBoard.breachKey(1)), findsNothing);
    });

    testWidgets('until the offending star is undone', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 1);
      await tapStarsCell(tester, 1);
      expect(find.byKey(StarsBoard.breachKey(0)), findsOneWidget);

      // The last move turned cell 1 into a star; undo takes it back to a dot,
      // and the breach it made goes with it.
      await tapAction(tester, 'undo');

      expect(find.byKey(StarsBoard.breachKey(0)), findsNothing);
      expect(find.byKey(StarsBoard.breachKey(1)), findsNothing);
    });
  });

  group('a breach says which rule to a screen reader', () {
    testWidgets('another star in its row', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpBoard(tester, board(stars: <int>{0, 3}));
        // Cell 0 is row 1, column 1, region 1.
        expect(
          find.bySemanticsLabel(en.cellStarsStarBreachRow(1, 1, 1)),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('another star in its column', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpBoard(tester, board(stars: <int>{0, 32}));
        expect(
          find.bySemanticsLabel(en.cellStarsStarBreachColumn(1, 1, 1)),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('another star in its region', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpBoard(tester, board(stars: <int>{0, 17}));
        expect(
          find.bySemanticsLabel(en.cellStarsStarBreachRegion(1, 1, 1)),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('touching another star', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpBoard(tester, board(stars: <int>{1, 10}));
        // Cell 1 is row 1, column 2, region 1.
        expect(
          find.bySemanticsLabel(en.cellStarsStarBreachAdjacent(1, 2, 1)),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });
  });
}
