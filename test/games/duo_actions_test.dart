import 'package:flutter_test/flutter_test.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/games/duo/duo_state.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/duo_fixture.dart';

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
  final DuoPuzzle puzzle = fixedDuoPuzzle();
  final int blank = puzzle.givens.indexWhere((DuoSymbol? s) => s == null);
  final int given = puzzle.givens.indexWhere((DuoSymbol? s) => s != null);

  group('undo', () {
    testWidgets('takes back one tap at a time and stops at the start', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);

      // Three taps on one cell: empty → circle → square → empty. Undo walks back
      // through each, one at a time.
      await tapDuoCell(tester, blank);
      await tapDuoCell(tester, blank);
      await tapDuoCell(tester, blank);
      expect(duoCellAt(tester, blank), DuoCell.empty);

      await tapAction(tester, 'undo');
      expect(duoCellAt(tester, blank), DuoCell.square);
      await tapAction(tester, 'undo');
      expect(duoCellAt(tester, blank), DuoCell.circle);
      await tapAction(tester, 'undo');
      expect(duoCellAt(tester, blank), DuoCell.empty);

      // Back at the start: undo is unavailable, not a no-op tap.
      expect(
        unavailable('undo', en.actionUndo, en.reasonNothingToUndo),
        findsOneWidget,
      );
    });
  });

  group('erase', () {
    testWidgets('empties a player cell, and undo puts it back', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);

      await tapDuoCell(tester, blank);
      expect(duoCellAt(tester, blank), DuoCell.circle);

      await tapAction(tester, 'erase');
      expect(duoCellAt(tester, blank), DuoCell.empty);

      // Erase is a move forward, so undo reverses it exactly.
      await tapAction(tester, 'undo');
      expect(duoCellAt(tester, blank), DuoCell.circle);
    });

    testWidgets('is unavailable with a reason when nothing is selected', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester);
      expect(actionEnabled(tester, 'erase'), isFalse);
      expect(
        unavailable('erase', en.actionErase, en.reasonNothingToErase),
        findsOneWidget,
      );
    });

    testWidgets('a given cannot be erased', (WidgetTester tester) async {
      await pumpDuoGame(tester);

      // Tapping a given selects nothing new — it does not respond — so erase
      // stays unavailable.
      await tapDuoCell(tester, given);
      expect(actionEnabled(tester, 'erase'), isFalse);
    });
  });
}
