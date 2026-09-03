import 'package:flutter_test/flutter_test.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/games/stars/stars_state.dart';

import '../support/stars_fixture.dart';

/// Taps the control with this [id] in the row under the board.
Future<void> tapAction(WidgetTester tester, String id) async {
  final Finder tile = find.byKey(BoardActionRow.keyFor(id));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pump();
}

/// Whether the control with this [id] reads to a screen reader as unavailable
/// for [reason] — the greyed-out control's spoken form.
Finder unavailable(String id, String label, String reason) {
  return find.bySemanticsLabel(en.actionUnavailableLabel(label, reason));
}

void main() {
  group('undo', () {
    testWidgets('takes back one tap at a time and stops at the start', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      // Three taps on one cell: empty → dot → star → empty. Undo walks back
      // through each, one at a time, not the whole cell in one go.
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 0);
      expect(starMarkAt(tester, 0), StarsMark.empty);

      await tapAction(tester, 'undo');
      expect(starMarkAt(tester, 0), StarsMark.star);
      await tapAction(tester, 'undo');
      expect(starMarkAt(tester, 0), StarsMark.ruledOut);
      await tapAction(tester, 'undo');
      expect(starMarkAt(tester, 0), StarsMark.empty);

      // Back at the start of the puzzle: undo is unavailable, not a no-op tap.
      expect(
        unavailable('undo', en.actionUndo, en.reasonNothingToUndo),
        findsOneWidget,
      );
    });
  });

  group('erase', () {
    testWidgets('empties a star, and undo puts it back', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      // Two taps place a star and leave that cell selected.
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 0);
      expect(starMarkAt(tester, 0), StarsMark.star);

      await tapAction(tester, 'erase');
      expect(starMarkAt(tester, 0), StarsMark.empty);

      // Erase is a move forward, so undo reverses it exactly.
      await tapAction(tester, 'undo');
      expect(starMarkAt(tester, 0), StarsMark.star);
    });

    testWidgets('empties a dot, and undo puts it back', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      await tapStarsCell(tester, 4);
      expect(starMarkAt(tester, 4), StarsMark.ruledOut);

      await tapAction(tester, 'erase');
      expect(starMarkAt(tester, 4), StarsMark.empty);

      await tapAction(tester, 'undo');
      expect(starMarkAt(tester, 4), StarsMark.ruledOut);
    });

    testWidgets('is unavailable with nothing selected', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      expect(
        unavailable('erase', en.actionErase, en.reasonNothingToErase),
        findsOneWidget,
      );
    });
  });

  group('clear marks', () {
    testWidgets('wipes every dot, leaves the stars, and one undo brings the '
        'dots back', (WidgetTester tester) async {
      await pumpStarsGame(tester);

      // Three dots and one star.
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 1);
      await tapStarsCell(tester, 2);
      await tapStarsCell(tester, 20);
      await tapStarsCell(tester, 20);
      expect(starMarkAt(tester, 0), StarsMark.ruledOut);
      expect(starMarkAt(tester, 20), StarsMark.star);

      await tapAction(tester, 'clear-marks');
      expect(starMarkAt(tester, 0), StarsMark.empty);
      expect(starMarkAt(tester, 1), StarsMark.empty);
      expect(starMarkAt(tester, 2), StarsMark.empty);
      expect(
        starMarkAt(tester, 20),
        StarsMark.star,
        reason: 'clear marks leaves the stars where they are',
      );

      // The whole sweep comes back in one undo, each dot where it was.
      await tapAction(tester, 'undo');
      expect(starMarkAt(tester, 0), StarsMark.ruledOut);
      expect(starMarkAt(tester, 1), StarsMark.ruledOut);
      expect(starMarkAt(tester, 2), StarsMark.ruledOut);
      expect(starMarkAt(tester, 20), StarsMark.star);
    });

    testWidgets('is unavailable when there are no dots, not a no-op tap', (
      WidgetTester tester,
    ) async {
      await pumpStarsGame(tester);

      // A lone star is not a dot: clear marks stays unavailable.
      await tapStarsCell(tester, 5);
      await tapStarsCell(tester, 5);
      expect(starMarkAt(tester, 5), StarsMark.star);

      expect(
        unavailable('clear-marks', en.actionClearMarks, en.reasonNoMarks),
        findsOneWidget,
      );
    });
  });
}
