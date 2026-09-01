import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SudokuGenerator (4x4)', () {
    final SudokuGenerator generator = SudokuGenerator(SudokuSpec.mini);
    final SudokuSolver solver = SudokuSolver(SudokuSpec.mini);

    test('every generated puzzle has exactly one solution', () {
      // The guarantee Nook makes to the player: you will never have to guess,
      // because there is never more than one answer. It is worth the seconds
      // this test costs.
      for (int seed = 1; seed <= 250; seed++) {
        final SudokuPuzzle puzzle = generator.generate(seed);
        expect(
          solver.countSolutions(puzzle.givens, limit: 2),
          1,
          reason: 'seed $seed produced a puzzle that is not unique',
        );
      }
    });

    test('the stated solution really solves the given grid', () {
      for (int seed = 1; seed <= 250; seed++) {
        final SudokuPuzzle puzzle = generator.generate(seed);
        expect(
          solver.isSolved(puzzle.solution),
          isTrue,
          reason: 'seed $seed has an invalid solution',
        );
        for (int i = 0; i < puzzle.givens.length; i++) {
          if (puzzle.givens[i] != 0) {
            expect(
              puzzle.givens[i],
              puzzle.solution[i],
              reason: 'seed $seed contradicts itself at cell $i',
            );
          }
        }
      }
    });

    test('the same seed produces an identical puzzle', () {
      for (final int seed in <int>[1, 7, 99, 12345, -3]) {
        final SudokuPuzzle first = generator.generate(seed);
        final SudokuPuzzle second = generator.generate(seed);
        expect(second.givens, first.givens);
        expect(second.solution, first.solution);
        expect(second.seed, seed);
      }
    });

    test('a fresh generator reproduces an earlier puzzle', () {
      // Determinism must survive a new object, not just a repeated call —
      // this is what lets a save store a seed instead of a grid.
      final SudokuPuzzle first = SudokuGenerator(SudokuSpec.mini)
          .generate(2024);
      final SudokuPuzzle second = SudokuGenerator(SudokuSpec.mini)
          .generate(2024);
      expect(second.givens, first.givens);
    });

    test('different seeds generally produce different puzzles', () {
      // 4x4 has few distinct grids, so duplicates are expected and accepted;
      // what would be wrong is the seed making no difference at all.
      final Set<String> distinct = <String>{};
      for (int seed = 1; seed <= 60; seed++) {
        distinct.add(generator.generate(seed).givens.join(','));
      }
      expect(distinct.length, greaterThan(10));
    });

    test('leaves some cells for the player and some as givens', () {
      for (int seed = 1; seed <= 60; seed++) {
        final SudokuPuzzle puzzle = generator.generate(seed);
        expect(puzzle.givenCount, greaterThan(0));
        expect(puzzle.givenCount, lessThan(puzzle.spec.cellCount));
      }
    });

    test('removal is minimal — putting any given back is not needed, and '
        'removing any one more breaks uniqueness', () {
      for (int seed = 1; seed <= 30; seed++) {
        final SudokuPuzzle puzzle = generator.generate(seed);
        for (int i = 0; i < puzzle.givens.length; i++) {
          if (puzzle.givens[i] == 0) {
            continue;
          }
          final List<int> reduced = List<int>.of(puzzle.givens)..[i] = 0;
          expect(
            solver.countSolutions(reduced, limit: 2),
            greaterThan(1),
            reason: 'seed $seed keeps given $i for no reason',
          );
        }
      }
    });
  });

  group('SudokuGenerator (non-square boxes)', () {
    // Nothing in the app uses 6x6 yet, but the engine is written for any box
    // shape and the uniqueness guarantee has to hold for all of them.
    final SudokuGenerator generator = SudokuGenerator(SudokuSpec.light);
    final SudokuSolver solver = SudokuSolver(SudokuSpec.light);

    test('generates unique 6x6 puzzles with 3x2 boxes', () {
      for (int seed = 1; seed <= 25; seed++) {
        final SudokuPuzzle puzzle = generator.generate(seed);
        expect(puzzle.spec.size, 6);
        expect(puzzle.givens, hasLength(36));
        expect(
          solver.countSolutions(puzzle.givens, limit: 2),
          1,
          reason: 'seed $seed',
        );
        expect(solver.isSolved(puzzle.solution), isTrue);
      }
    });

    test('is deterministic at 6x6 too', () {
      expect(generator.generate(5).givens, generator.generate(5).givens);
    });
  });

  group('SudokuGenerator (9x9)', () {
    test('generates a unique 9x9 puzzle', () {
      final SudokuGenerator generator = SudokuGenerator(SudokuSpec.classic);
      final SudokuSolver solver = SudokuSolver(SudokuSpec.classic);
      final SudokuPuzzle puzzle = generator.generate(1);
      expect(puzzle.givens, hasLength(81));
      expect(solver.countSolutions(puzzle.givens, limit: 2), 1);
    });
  });

  group('SudokuPuzzle', () {
    test('exposes givens without letting them be changed', () {
      final SudokuPuzzle puzzle = SudokuGenerator(SudokuSpec.mini).generate(1);
      expect(() => puzzle.givens[0] = 9, throwsUnsupportedError);
      expect(() => puzzle.solution[0] = 9, throwsUnsupportedError);
    });

    test('isGiven matches the starting grid', () {
      final SudokuPuzzle puzzle = SudokuGenerator(SudokuSpec.mini).generate(1);
      for (int i = 0; i < puzzle.givens.length; i++) {
        expect(puzzle.isGiven(i), puzzle.givens[i] != 0);
      }
    });
  });
}
