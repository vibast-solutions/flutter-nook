import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/duo_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/duo/duo_state.dart';
import 'package:nook/games/duo/duo_variant.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/duo_fixture.dart';

const DuoSpec _spec = DuoSpec.standard;

/// A Duo game holding [circles], [squares] and a chosen set of [badges], with
/// everything else empty.
///
/// Built straight rather than tapped: what is under test is a reading of the
/// grid, and saying which cells hold what is the shortest way to name a board.
/// [givens] names the cells the puzzle should treat as fixed — a breach reads
/// the same whether a cell is given or the player's, and this is how the tests
/// prove it. [solution] is never read by the breach code, so it defaults to a
/// throwaway all-circle grid.
DuoGameState board({
  Set<int> circles = const <int>{},
  Set<int> squares = const <int>{},
  List<DuoBadge> badges = const <DuoBadge>[],
  Set<int> givens = const <int>{},
  List<DuoSymbol>? solution,
}) {
  final List<DuoSymbol?> givenList = <DuoSymbol?>[
    for (int i = 0; i < _spec.cellCount; i++)
      if (!givens.contains(i))
        null
      else if (circles.contains(i))
        DuoSymbol.circle
      else
        DuoSymbol.square,
  ];
  final DuoPuzzle puzzle = DuoPuzzle(
    spec: _spec,
    seed: 0,
    givens: givenList,
    badges: badges,
    solution:
        solution ??
        <DuoSymbol>[for (int i = 0; i < _spec.cellCount; i++) DuoSymbol.circle],
  );
  final List<DuoCell> cells = List<DuoCell>.filled(
    _spec.cellCount,
    DuoCell.empty,
  );
  for (final int index in circles) {
    cells[index] = DuoCell.circle;
  }
  for (final int index in squares) {
    cells[index] = DuoCell.square;
  }
  return DuoGameState(
    variant: DuoVariant.standard,
    puzzle: puzzle,
    cells: cells,
  );
}

/// A badge between adjacent cells [a] and [b].
DuoBadge eq(int a, int b) => DuoBadge(a: a, b: b, relation: DuoRelation.equal);
DuoBadge ne(int a, int b) =>
    DuoBadge(a: a, b: b, relation: DuoRelation.unequal);

/// Pumps [game]'s board on its own, so a test can put any grid in front of a
/// screen reader without driving the controller to it.
Future<void> pumpBoard(WidgetTester tester, DuoGameState game) async {
  await setPhoneSurface(tester);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: buildNookTheme(NookColors.softClay),
      home: Scaffold(
        body: DuoBoard(game: game, onTap: (_) {}),
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
    test('three identical symbols in a row mark all three', () {
      // Cells 0, 1, 2 are the first three of row 0. A run of three circles
      // cannot balance nor obey the run limit — all three are in breach.
      expect(board(circles: <int>{0, 1, 2}).breaches, <int>{0, 1, 2});
    });

    test('three identical symbols in a column mark all three', () {
      // Cells 0, 6, 12 are the first three of column 0.
      expect(board(circles: <int>{0, 6, 12}).breaches, <int>{0, 6, 12});
    });

    test('a run longer than three marks every cell of it', () {
      // Four squares across the top of column 0: the overlapping windows of
      // three reach all four.
      expect(board(squares: <int>{0, 6, 12, 18}).breaches, <int>{0, 6, 12, 18});
    });

    test('a line with four of one symbol marks the offending symbols', () {
      // Four circles in row 0, spread so no three are consecutive (0, 1, 3, 4):
      // the run rule is quiet, but the line can never hold three-and-three, so
      // every circle in it is marked — and the lone square at cell 2 is not.
      final DuoGameState game = board(
        circles: <int>{0, 1, 3, 4},
        squares: <int>{2},
      );
      expect(game.breaches, <int>{0, 1, 3, 4});
      expect(game.isBreaching(2), isFalse);
    });

    test('a violated equals badge marks both its cells', () {
      // Cells 0 and 1 are joined by an `=` but hold different symbols.
      final DuoGameState game = board(
        circles: <int>{0},
        squares: <int>{1},
        badges: <DuoBadge>[eq(0, 1)],
      );
      expect(game.breaches, <int>{0, 1});
      expect(game.breachAt(0), DuoBreach.badge);
    });

    test('a violated not-equals badge marks both its cells', () {
      // Cells 0 and 1 are joined by an `x` but hold the same symbol. Two alike
      // side by side is a run of two, which the limit allows, so only the badge
      // is broken.
      final DuoGameState game = board(
        circles: <int>{0, 1},
        badges: <DuoBadge>[ne(0, 1)],
      );
      expect(game.breaches, <int>{0, 1});
      expect(game.breachAt(0), DuoBreach.badge);
    });

    test('a satisfied badge marks nothing', () {
      // An `=` whose cells match and an `x` whose cells differ: neither is
      // broken, and two circles a cell apart make no run.
      final DuoGameState game = board(
        circles: <int>{0, 1, 7},
        squares: <int>{6},
        badges: <DuoBadge>[eq(0, 1), ne(0, 6)],
      );
      expect(game.breaches, isEmpty);
    });

    test('a badge with an empty cell is not yet a breach', () {
      // Only one of the two cells is filled: there is nothing to contradict
      // until the player fills the other.
      final DuoGameState game = board(
        circles: <int>{0},
        badges: <DuoBadge>[ne(0, 1)],
      );
      expect(game.breaches, isEmpty);
    });

    test('a given completing a run is marked like the rest', () {
      // Cell 2 is a given circle; the player has put circles in 0 and 1. The
      // run of three is a breach and the given is one of its cells, marked
      // exactly like the player's own.
      final DuoGameState game = board(
        circles: <int>{0, 1, 2},
        givens: <int>{2},
      );
      expect(game.breaches, <int>{0, 1, 2});
      expect(game.isBreaching(2), isTrue);
    });

    test('an empty board has no breach', () {
      expect(board().breaches, isEmpty);
    });
  });

  group('a breach is never a judgement', () {
    test('a symbol that breaks nothing is left alone, however wrong it is', () {
      // A lone circle breaks no rule: no run, no overfull line, no badge. The
      // board says nothing, because a board that marked it would be an oracle
      // to brute-force rather than a puzzle.
      final DuoGameState game = board(circles: <int>{0});
      expect(game.breaches, isEmpty);
      expect(game.isBreaching(0), isFalse);
    });

    test('swapping the solution changes nothing at all', () {
      // The guard on the rule. Same symbols and badges, a different stored
      // answer: if any reading of the solution had crept in, the two would
      // disagree here.
      final DuoGameState honest = board(
        circles: <int>{0, 1, 2},
        solution: <DuoSymbol>[
          for (int i = 0; i < _spec.cellCount; i++) DuoSymbol.circle,
        ],
      );
      final DuoGameState fooled = board(
        circles: <int>{0, 1, 2},
        solution: <DuoSymbol>[
          for (int i = 0; i < _spec.cellCount; i++) DuoSymbol.square,
        ],
      );
      expect(honest.breaches, fooled.breaches);
      expect(honest.breaches, isNotEmpty);
    });
  });

  group('the board shows a breach', () {
    testWidgets('with a ring as well as a colour', (WidgetTester tester) async {
      // Colour alone would be silent for the players most likely to need it, so
      // a breach also rings the cell — a shape read without the hue — found here
      // as a keyed widget of its own, the wash's colour ignored entirely. The
      // board is built with the run already on it, so the ring is shown at once
      // rather than waiting out the delay.
      await pumpBoard(tester, board(circles: <int>{0, 1, 2}));

      for (final int index in <int>[0, 1, 2]) {
        expect(
          find.byKey(DuoBoard.breachKey(index)),
          findsOneWidget,
          reason: 'cell $index of the run should be ringed',
        );
      }
      expect(find.byKey(DuoBoard.breachKey(3)), findsNothing);
    });

    testWidgets('a breach the board opens with is marked on the first frame', (
      WidgetTester tester,
    ) async {
      // A resumed game is not mid-toggle, so the breaches it opens with are not
      // delayed. Built with the run in place and pumped a single frame with no
      // time advanced: the ring is already there.
      await setPhoneSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildNookTheme(NookColors.softClay),
          home: Scaffold(
            body: DuoBoard(
              game: board(circles: <int>{0, 1, 2}),
              onTap: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(DuoBoard.breachKey(0)), findsOneWidget);
    });

    testWidgets('until the offending symbol is erased', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester, puzzle: _runPuzzle());
      // Circles into the first three cells of row 0: a run of three. Freshly
      // made, so it waits out the delay before its ring is drawn.
      await tapDuoCell(tester, 0);
      await tapDuoCell(tester, 1);
      await tapDuoCell(tester, 2);
      await tester.pump(DuoBoard.breachDelay);
      expect(find.byKey(DuoBoard.breachKey(0)), findsOneWidget);

      // Cell 2 is selected after its tap; erasing it breaks the run, and the
      // marking goes in the same frame — nothing waits to stop being wrong.
      await tapAction(tester, 'erase');

      for (final int index in <int>[0, 1, 2]) {
        expect(find.byKey(DuoBoard.breachKey(index)), findsNothing);
      }
    });

    testWidgets('until the offending symbol is undone', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester, puzzle: _runPuzzle());
      await tapDuoCell(tester, 0);
      await tapDuoCell(tester, 1);
      await tapDuoCell(tester, 2);
      await tester.pump(DuoBoard.breachDelay);
      expect(find.byKey(DuoBoard.breachKey(0)), findsOneWidget);

      // The last move put a circle in cell 2; undo takes it back to empty, and
      // the breach it made goes with it, immediately.
      await tapAction(tester, 'undo');

      for (final int index in <int>[0, 1, 2]) {
        expect(find.byKey(DuoBoard.breachKey(index)), findsNothing);
      }
    });

    testWidgets('draws the ring over a selected breaching cell', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester, puzzle: _runPuzzle());
      await tapDuoCell(tester, 0);
      await tapDuoCell(tester, 1);
      // Cell 2's tap both completes the run and leaves cell 2 the selected cell.
      await tapDuoCell(tester, 2);
      await tester.pump(DuoBoard.breachDelay);

      // The ring is drawn on the selected cell too: a breach the player is
      // standing on is never hidden by the selection lift.
      expect(find.byKey(DuoBoard.breachKey(2)), findsOneWidget);
    });
  });

  group('a Duo breach waits out its delay', () {
    testWidgets('a tapped breach is unmarked until the delay elapses', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester, puzzle: _runPuzzle());
      await tapDuoCell(tester, 0);
      await tapDuoCell(tester, 1);
      await tapDuoCell(tester, 2);

      // A hair before the wait is over the board still says nothing.
      await tester.pump(DuoBoard.breachDelay - const Duration(milliseconds: 1));
      for (final int index in <int>[0, 1, 2]) {
        expect(find.byKey(DuoBoard.breachKey(index)), findsNothing);
      }

      // The moment it elapses, every cell of the run is ringed.
      await tester.pump(const Duration(milliseconds: 1));
      for (final int index in <int>[0, 1, 2]) {
        expect(find.byKey(DuoBoard.breachKey(index)), findsOneWidget);
      }
    });

    testWidgets('a breach passed through mid-cycle is never marked', (
      WidgetTester tester,
    ) async {
      await pumpDuoGame(tester, puzzle: _runPuzzle());
      await tapDuoCell(tester, 0);
      await tapDuoCell(tester, 1);
      // A circle in cell 2 makes the run — but the player is only passing
      // through it on the way to a square.
      await tapDuoCell(tester, 2);
      await tester.pump(const Duration(seconds: 1));
      // Cycle cell 2 on to a square before the wait is over: the run is gone.
      await tapDuoCell(tester, 2);

      // Let the original wait's full length pass: no ring ever appears, because
      // the pending mark was cancelled the moment the run broke.
      await tester.pump(DuoBoard.breachDelay);
      for (final int index in <int>[0, 1, 2]) {
        expect(find.byKey(DuoBoard.breachKey(index)), findsNothing);
      }
    });
  });

  group('a breach says which rule to a screen reader', () {
    testWidgets('three in a row', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpBoard(tester, board(circles: <int>{0, 1, 2}));
        // Cell 0 is row 1, column 1.
        expect(
          find.bySemanticsLabel(en.cellDuoCircleBreachTriple(1, 1)),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets("the line's balance", (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        // Four squares in row 0, none three consecutive: only the balance rule.
        await pumpBoard(
          tester,
          board(squares: <int>{0, 1, 3, 4}, circles: <int>{2}),
        );
        expect(
          find.bySemanticsLabel(en.cellDuoSquareBreachBalance(1, 1)),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('a badge', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpBoard(
          tester,
          board(
            circles: <int>{0},
            squares: <int>{1},
            badges: <DuoBadge>[eq(0, 1)],
          ),
        );
        expect(
          find.bySemanticsLabel(en.cellDuoCircleBreachBadge(1, 1)),
          findsOneWidget,
        );
        // The other cell of the badge is a square, named as one.
        expect(
          find.bySemanticsLabel(en.cellDuoSquareBreachBadge(1, 2)),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the breach sentence waits with the ring and arrives with it', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      try {
        await pumpDuoGame(tester, puzzle: _runPuzzle());
        await tapDuoCell(tester, 0);
        await tapDuoCell(tester, 1);
        await tapDuoCell(tester, 2);

        // A hair before the wait is over, cell 0 (row 1, column 1) reads as an
        // ordinary circle — the board says one thing in both languages, and the
        // ring is not there yet.
        await tester.pump(
          DuoBoard.breachDelay - const Duration(milliseconds: 1),
        );
        expect(
          find.bySemanticsLabel(en.cellDuoCircleBreachTriple(1, 1)),
          findsNothing,
        );
        expect(find.bySemanticsLabel(en.cellDuoCircle(1, 1)), findsOneWidget);

        // With the ring, the sentence names the rule that broke.
        await tester.pump(const Duration(milliseconds: 1));
        expect(
          find.bySemanticsLabel(en.cellDuoCircleBreachTriple(1, 1)),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });
  });
}

/// A puzzle with no givens on the first row, so a test can tap circles into
/// cells 0, 1 and 2 and make a run of three. Its badges are empty and its
/// solution is a throwaway the breach code never reads.
DuoPuzzle _runPuzzle() {
  return DuoPuzzle(
    spec: _spec,
    seed: 0,
    givens: List<DuoSymbol?>.filled(_spec.cellCount, null),
    badges: const <DuoBadge>[],
    solution: <DuoSymbol>[
      for (int i = 0; i < _spec.cellCount; i++) DuoSymbol.circle,
    ],
  );
}
