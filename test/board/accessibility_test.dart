import 'package:flutter_test/flutter_test.dart';

import '../support/sudoku_fixture.dart';

/// Runs [body] with the semantics tree switched on, and always turns it off
/// again — an undisposed handle fails the test for the wrong reason.
Future<void> withSemantics(
  WidgetTester tester,
  Future<void> Function() body,
) async {
  final SemanticsHandle handle = tester.ensureSemantics();
  try {
    await body();
  } finally {
    handle.dispose();
  }
}

void main() {
  group('a screen reader can read the board', () {
    testWidgets('cells describe where they are and who filled them', (
      WidgetTester tester,
    ) async {
      await withSemantics(tester, () async {
        await pumpSudokuGame(tester);

        // Cell 6 is row 2, column 3, and holds a given 1.
        expect(
          find.bySemanticsLabel('Row 2, column 3, 1, given'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Row 1, column 1, empty'), findsOneWidget);
      });
    });

    testWidgets('a cell the player filled reads as theirs', (
      WidgetTester tester,
    ) async {
      await withSemantics(tester, () async {
        await pumpSudokuGame(tester);

        await tester.tap(find.bySemanticsLabel('Row 1, column 1, empty'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('1, 2 left to place'));
        await tester.pump();

        expect(
          find.bySemanticsLabel('Row 1, column 1, 1, your answer'),
          findsOneWidget,
        );
      });
    });

    testWidgets('the pad says how many of each digit are left', (
      WidgetTester tester,
    ) async {
      await withSemantics(tester, () async {
        await pumpSudokuGame(tester);

        expect(find.bySemanticsLabel('4, 4 left to place'), findsOneWidget);
      });
    });

    testWidgets('the action row says why a control cannot be used', (
      WidgetTester tester,
    ) async {
      await withSemantics(tester, () async {
        await pumpSudokuGame(tester);

        expect(
          find.bySemanticsLabel('Undo, nothing to take back'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('Erase'), findsOneWidget);

        await tester.tap(find.bySemanticsLabel('Row 1, column 1, empty'));
        await tester.pump();
        await tester.tap(find.bySemanticsLabel('1, 2 left to place'));
        await tester.pump();

        expect(find.bySemanticsLabel('Undo'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Undo, nothing to take back'),
          findsNothing,
        );
      });
    });

    testWidgets('the board itself is announced', (WidgetTester tester) async {
      await withSemantics(tester, () async {
        await pumpSudokuGame(tester);

        expect(
          find.bySemanticsLabel('Sudoku Mini board, 4 by 4'),
          findsOneWidget,
        );
      });
    });
  });
}
