import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

/// The three shapes Nook ships, so every test states which grid it failed on.
const Map<String, SudokuSpec> variants = <String, SudokuSpec>{
  '4x4': SudokuSpec.mini,
  '6x6': SudokuSpec.light,
  '9x9': SudokuSpec.classic,
};

/// The two rungs of the ladder that place a digit rather than ruling one out.
const Set<SudokuTechnique> placingTechniques = <SudokuTechnique>{
  SudokuTechnique.nakedSingle,
  SudokuTechnique.hiddenSingle,
};

void main() {
  group('SudokuLogicSolver.placements', () {
    variants.forEach((String name, SudokuSpec spec) {
      test('$name: every placement is the puzzle\'s own solution', () {
        final SudokuPuzzle puzzle = SudokuGenerator(spec).generate(7);
        final SudokuLogicSolver solver = SudokuLogicSolver(spec);

        int placed = 0;
        for (final SudokuPlacement placement in solver.placements(
          puzzle.givens,
        )) {
          expect(
            placement.digit,
            puzzle.solution[placement.index],
            reason: 'deduced a digit the puzzle does not have there',
          );
          expect(puzzle.givens[placement.index], 0);
          expect(placement.technique, isIn(placingTechniques));
          placed++;
        }

        // The generator only ships puzzles this solver can finish, so the
        // sequence has to account for every blank on the board.
        expect(placed, spec.cellCount - puzzle.givenCount);
      });

      test('$name: a full grid has nothing left to place', () {
        final SudokuPuzzle puzzle = SudokuGenerator(spec).generate(11);

        expect(SudokuLogicSolver(spec).placements(puzzle.solution), isEmpty);
      });
    });

    test('a grid of the wrong size is refused', () {
      expect(
        () =>
            SudokuLogicSolver(SudokuSpec.mini)
                .placements(<int>[1, 2, 3])
                .toList(),
        throwsArgumentError,
      );
    });

    test('it stops at a board that contradicts itself', () {
      // Two 1s in a row: there is nothing legitimate to deduce from a grid
      // that already breaks the rules, so it says so by placing nothing.
      final List<int> broken = List<int>.filled(16, 0)
        ..[0] = 1
        ..[1] = 1;

      expect(SudokuLogicSolver(SudokuSpec.mini).placements(broken), isEmpty);
    });
  });

  group('SudokuHinter', () {
    variants.forEach((String name, SudokuSpec spec) {
      test('$name: a hint is a cell the player could have worked out', () {
        final SudokuPuzzle puzzle = SudokuGenerator(spec).generate(3);
        final SudokuHint? hint = SudokuHinter(puzzle).hintFor(puzzle.givens);

        expect(hint, isNotNull);
        expect(hint!.isDeduced, isTrue);
        expect(hint.technique, isIn(placingTechniques));
        expect(hint.digit, puzzle.solution[hint.index]);
        expect(puzzle.givens[hint.index], 0);
      });

      test('$name: hint after hint finishes the puzzle', () {
        // The property that matters most: a hint is always available while the
        // grid has a blank in it, always correct, and always moves the board
        // on. A player leaning on hints alone must reach a solved puzzle.
        final SudokuPuzzle puzzle = SudokuGenerator(spec).generate(5);
        final SudokuHinter hinter = SudokuHinter(puzzle);
        final List<int> board = List<int>.of(puzzle.givens);

        for (int step = 0; step < spec.cellCount; step++) {
          final SudokuHint? hint = hinter.hintFor(board);
          if (hint == null) {
            break;
          }
          expect(board[hint.index], 0);
          board[hint.index] = hint.digit;
        }

        expect(board, puzzle.solution);
        expect(hinter.hintFor(board), isNull);
      });

      test('$name: a wrong entry is reasoned around, never corrected', () {
        final SudokuPuzzle puzzle = SudokuGenerator(spec).generate(9);
        final List<int> board = List<int>.of(puzzle.givens);

        // Put a digit that is not the answer into the first blank cell.
        final int wrongAt = board.indexOf(0);
        final int wrong = puzzle.solution[wrongAt] % spec.size + 1;
        expect(wrong, isNot(puzzle.solution[wrongAt]));
        board[wrongAt] = wrong;

        final SudokuHint? hint = SudokuHinter(puzzle).hintFor(board);

        expect(hint, isNotNull);
        expect(hint!.index, isNot(wrongAt), reason: 'it overwrote a mistake');
        expect(board[hint.index], 0);
        expect(hint.digit, puzzle.solution[hint.index]);
        expect(board[wrongAt], wrong, reason: 'the mistake was changed');
      });
    });

    test('a hint never lands on a cell the player has already filled', () {
      final SudokuPuzzle puzzle = SudokuGenerator(SudokuSpec.classic)
          .generate(13);
      final List<int> board = List<int>.of(puzzle.givens);

      // Fill the first twenty blanks correctly and ask each time: the hint has
      // to keep finding somewhere new to go.
      for (int filled = 0; filled < 20; filled++) {
        final SudokuHint hint = SudokuHinter(puzzle).hintFor(board)!;
        expect(board[hint.index], 0);
        board[hint.index] = hint.digit;
      }

      final SudokuHint hint = SudokuHinter(puzzle).hintFor(board)!;
      expect(board[hint.index], 0);
    });

    test('a puzzle logic cannot finish still gives a cell away', () {
      // A grid with two solutions: the technique solver refuses to guess at
      // the fork, so the hint comes off the solution instead of a deduction.
      // The generator never produces one of these; a save from an older build
      // one day might.
      final SudokuPuzzle puzzle = SudokuGenerator(SudokuSpec.mini).generate(2);
      final List<int> ambiguous = List<int>.of(puzzle.givens);
      for (int index = 0; index < ambiguous.length; index++) {
        ambiguous[index] = 0;
      }
      final SudokuPuzzle empty = SudokuPuzzle(
        spec: SudokuSpec.mini,
        seed: puzzle.seed,
        givens: ambiguous,
        solution: puzzle.solution,
      );

      final SudokuHint? hint = SudokuHinter(empty).hintFor(ambiguous);

      expect(hint, isNotNull);
      expect(hint!.isDeduced, isFalse);
      expect(hint.index, 0);
      expect(hint.digit, puzzle.solution[0]);
    });

    test('a solved grid has no hint left in it', () {
      final SudokuPuzzle puzzle = SudokuGenerator(SudokuSpec.mini).generate(4);

      expect(SudokuHinter(puzzle).hintFor(puzzle.solution), isNull);
    });

    test('a board of the wrong size is refused', () {
      final SudokuPuzzle puzzle = SudokuGenerator(SudokuSpec.mini).generate(6);

      expect(
        () => SudokuHinter(puzzle).hintFor(<int>[0, 0]),
        throwsArgumentError,
      );
    });
  });
}
