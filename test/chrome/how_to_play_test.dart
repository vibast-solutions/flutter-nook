import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/duo_board.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/chrome/how_to_play.dart';
import 'package:nook/games/duo/duo_naming.dart';
import 'package:nook/games/duo/duo_variant.dart';
import 'package:nook/games/stars/stars_naming.dart';
import 'package:nook/games/stars/stars_variant.dart';
import 'package:nook/games/sudoku/sudoku_naming.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';

import '../support/duo_fixture.dart' as duo;
import '../support/stars_fixture.dart' as stars;
import '../support/sudoku_fixture.dart' as sudoku;

/// The one localisation lookup — every fixture reads the same English strings,
/// so either fixture's [duo.en] is the whole app's `en`.
final en = duo.en;

/// The label of the help tile in the header, and of the row long-press, for a
/// game whose name is [title].
String openLabel(String title) => en.howToPlayOpen(title);

void main() {
  group('the help tile in the game header', () {
    testWidgets('opens Duo\'s rules, legend and all', (
      WidgetTester tester,
    ) async {
      await duo.pumpDuoGame(tester);

      expect(find.byType(HowToPlaySheet), findsNothing);
      await tester.tap(
        find.bySemanticsLabel(openLabel(DuoVariant.standard.title(en))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HowToPlaySheet), findsOneWidget);
      expect(find.text(en.howToPlayHeading), findsOneWidget);
      expect(find.text(en.duoRulesObjective), findsOneWidget);
      expect(find.text(en.duoRulesInteraction), findsOneWidget);
      // The sheet shows the board's own legend, not a second-hand copy of it.
      expect(
        find.descendant(
          of: find.byType(HowToPlaySheet),
          matching: find.byType(DuoLegend),
        ),
        findsOneWidget,
      );
    });

    testWidgets('opens Stars\' rules and region key', (
      WidgetTester tester,
    ) async {
      await stars.pumpStarsGame(tester);

      await tester.tap(
        find.bySemanticsLabel(openLabel(StarsVariant.standard.title(en))),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HowToPlaySheet), findsOneWidget);
      // Unique to the sheet — the objective is not printed under the board.
      expect(find.text(en.starsRulesObjective), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HowToPlaySheet),
          matching: find.byType(StarsLegend),
        ),
        findsOneWidget,
      );
    });

    testWidgets('keeps its tap target and does not overflow at 320px', (
      WidgetTester tester,
    ) async {
      // The narrowest layout Nook supports: back button, title, help tile and
      // clock all share one row. A header that overflowed would throw during
      // the pump before this line is reached.
      await sudoku.pumpSudokuGame(tester, width: 320);

      final Finder help = find.bySemanticsLabel(
        openLabel(SudokuVariant.mini.title(en)),
      );
      expect(help, findsOneWidget);
      expect(tester.getSize(help).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(help).height, greaterThanOrEqualTo(44));

      await tester.tap(help);
      await tester.pumpAndSettle();
      expect(find.byType(HowToPlaySheet), findsOneWidget);
    });

    for (final SudokuVariant variant in <SudokuVariant>[
      SudokuVariant.classic,
      SudokuVariant.light,
      SudokuVariant.mini,
    ]) {
      testWidgets('opens ${variant.title(en)}\'s rules, sized to its grid', (
        WidgetTester tester,
      ) async {
        await sudoku.pumpSudokuGame(tester, variant: variant);

        await tester.tap(find.bySemanticsLabel(openLabel(variant.title(en))));
        await tester.pumpAndSettle();

        expect(find.byType(HowToPlaySheet), findsOneWidget);
        // The aim names the grid's own largest number, so the three sizes read
        // differently and none is a stray copy of another.
        expect(
          find.text(en.sudokuRulesObjective(variant.spec.size)),
          findsOneWidget,
        );
        // Sudoku's only symbols are the numbers the aim already names, so the
        // sheet carries no legend.
        expect(
          find.descendant(
            of: find.byType(HowToPlaySheet),
            matching: find.byType(DuoLegend),
          ),
          findsNothing,
        );
      });
    }
  });

  group('the game row in the menu', () {
    testWidgets('opens a game\'s rules on a long press', (
      WidgetTester tester,
    ) async {
      await sudoku.pumpHome(tester);

      // Held rather than tapped: a tap opens the difficulties, a hold reads the
      // rules first.
      await tester.longPress(find.text(SudokuVariant.mini.title(en)));
      await tester.pumpAndSettle();

      expect(find.byType(HowToPlaySheet), findsOneWidget);
      expect(
        find.text(en.sudokuRulesObjective(SudokuVariant.mini.spec.size)),
        findsOneWidget,
      );
    });

    testWidgets('reads Duo before it is started', (WidgetTester tester) async {
      await duo.pumpDuoHome(tester);

      await tester.longPress(find.text(en.duoSubtitle));
      await tester.pumpAndSettle();

      expect(find.byType(HowToPlaySheet), findsOneWidget);
      expect(find.text(en.duoRulesObjective), findsOneWidget);
    });

    testWidgets('reads Stars before it is started', (
      WidgetTester tester,
    ) async {
      await stars.pumpStarsHome(tester);

      // The subtitle is on the row alone — "Stars" itself also names the daily
      // card — so holding it is unambiguous.
      await tester.longPress(find.text(en.starsSubtitle));
      await tester.pumpAndSettle();

      expect(find.byType(HowToPlaySheet), findsOneWidget);
      expect(find.text(en.starsRulesObjective), findsOneWidget);
    });
  });

  group('the sheet', () {
    testWidgets('closes from its own button', (WidgetTester tester) async {
      await duo.pumpDuoGame(tester);
      await tester.tap(
        find.bySemanticsLabel(openLabel(DuoVariant.standard.title(en))),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HowToPlaySheet), findsOneWidget);

      // Scoped to the sheet: the dismiss barrier behind it carries the same
      // label, and the close control is the one inside the panel.
      await tester.tap(
        find.descendant(
          of: find.byType(HowToPlaySheet),
          matching: find.bySemanticsLabel(en.howToPlayClose),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HowToPlaySheet), findsNothing);
    });

    testWidgets('opens without a transition under reduced motion', (
      WidgetTester tester,
    ) async {
      await duo.pumpDuoGame(tester, disableAnimations: true);

      await tester.tap(
        find.bySemanticsLabel(openLabel(DuoVariant.standard.title(en))),
      );
      // A single frame, no time advanced: with motion off the sheet is already
      // in place rather than partway through sliding up.
      await tester.pump();

      expect(find.byType(HowToPlaySheet), findsOneWidget);
      expect(find.text(en.duoRulesObjective), findsOneWidget);
      // Flush to the bottom of the 1000-high test surface: fully in place, not
      // caught mid-slide as it would be one frame into an animation.
      expect(
        tester.getBottomLeft(find.byType(HowToPlaySheet)).dy,
        closeTo(1000, 1),
      );
    });
  });
}
