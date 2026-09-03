import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

/// A puzzle the technique solver stalls on at once: no givens and no badges.
///
/// An empty board gives every deduction nothing to hold on to — any legal
/// completion of a line stays legal with the two symbols swapped, so no cell
/// is ever forced. That is exactly the shape a hinter's fallback exists for,
/// so it stands in for "a puzzle logic cannot finish" without needing one the
/// generator would never make. Its solution is borrowed from a real puzzle of
/// the same shape, because any full legal grid is a legal solution to a board
/// with nothing on it.
DuoPuzzle stuckPuzzle(DuoGenerator generator) {
  final DuoPuzzle real = generator.generate(2026);
  return DuoPuzzle(
    spec: real.spec,
    seed: 0,
    givens: List<DuoSymbol?>.filled(real.spec.cellCount, null),
    badges: const <DuoBadge>[],
    solution: real.solution,
  );
}

void main() {
  const DuoSpec spec = DuoSpec.standard;
  final DuoGenerator generator = DuoGenerator(spec);

  /// The board as a player who has entered nothing sees it: the givens.
  List<DuoSymbol?> untouched(DuoPuzzle puzzle) =>
      List<DuoSymbol?>.of(puzzle.givens);

  group('DuoHinter', () {
    test('a hint is a symbol the player could have worked out', () {
      final DuoPuzzle puzzle = generator.generate(2026);
      final DuoHint? hint = DuoHinter(puzzle).hintFor(untouched(puzzle));

      expect(hint, isNotNull);
      expect(hint!.isDeduced, isTrue);
      expect(hint.technique, isNotNull);
      expect(puzzle.isGiven(hint.index), isFalse);
      expect(
        hint.symbol,
        puzzle.solution[hint.index],
        reason: 'a hint has to agree with the puzzle it came from',
      );
    });

    test('it gives the next justified symbol for a partly-solved board', () {
      final DuoPuzzle puzzle = generator.generate(2026);
      final DuoHinter hinter = DuoHinter(puzzle);

      // The symbol the solver reaches first, then the same board with it down.
      final List<DuoSymbol?> board = untouched(puzzle);
      final DuoHint first = hinter.hintFor(board)!;
      board[first.index] = first.symbol;
      final DuoHint next = hinter.hintFor(board)!;

      expect(next.index, isNot(first.index));
      expect(next.isDeduced, isTrue);
      expect(next.symbol, puzzle.solution[next.index]);
    });

    test('hint after hint finishes the puzzle', () {
      // The property that matters most: a hint is always available while the
      // board has an empty cell, always correct, and always moves it on. A
      // player leaning on hints alone must reach a solved board.
      final DuoPuzzle puzzle = generator.generate(5);
      final DuoHinter hinter = DuoHinter(puzzle);
      final List<DuoSymbol?> board = untouched(puzzle);

      for (int step = 0; step < spec.cellCount; step++) {
        final DuoHint? hint = hinter.hintFor(board);
        if (hint == null) {
          break;
        }
        expect(board[hint.index], isNull);
        board[hint.index] = hint.symbol;
      }

      expect(board, puzzle.solution);
      expect(hinter.hintFor(board), isNull);
    });

    test('it never targets a given or a cell already holding the correct '
        'symbol', () {
      final DuoPuzzle puzzle = generator.generate(9);
      final DuoHinter hinter = DuoHinter(puzzle);

      // Half the empty cells already filled in correctly by the player. A hint
      // has to skip every one of them, and every given.
      final List<DuoSymbol?> board = untouched(puzzle);
      int placed = 0;
      for (int index = 0; index < spec.cellCount && placed < 16; index++) {
        if (board[index] == null) {
          board[index] = puzzle.solution[index];
          placed++;
        }
      }

      final DuoHint hint = hinter.hintFor(board)!;

      expect(board[hint.index], isNull);
      expect(puzzle.isGiven(hint.index), isFalse);
      expect(hint.symbol, puzzle.solution[hint.index]);
    });

    test('a full board has no hint left in it', () {
      final DuoPuzzle puzzle = generator.generate(4);

      expect(
        DuoHinter(puzzle).hintFor(List<DuoSymbol?>.of(puzzle.solution)),
        isNull,
      );
    });

    test('a puzzle logic cannot finish still gives a symbol away', () {
      // An empty board stalls the technique solver at once, so the hint comes
      // off the solution instead of a deduction. The generator never produces
      // one of these; a save from an older build one day might.
      final DuoPuzzle stuck = stuckPuzzle(generator);

      final DuoHint? hint = DuoHinter(stuck).hintFor(untouched(stuck));

      expect(hint, isNotNull);
      expect(hint!.isDeduced, isFalse);
      expect(hint.technique, isNull);
      expect(hint.symbol, stuck.solution[hint.index]);
    });
  });
}
