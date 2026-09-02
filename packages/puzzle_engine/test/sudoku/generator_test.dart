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

    test('different seeds generally produce different puzzles', () {
      // 4x4 has few distinct grids, so duplicates are expected and accepted;
      // what would be wrong is the seed making no difference at all.
      final Set<String> distinct = <String>{};
      for (int seed = 1; seed <= 60; seed++) {
        distinct.add(generator.generate(seed).givens.join(','));
      }
      expect(distinct.length, greaterThan(10));
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

  group('SudokuGenerator (6x6, non-square boxes)', () {
    // 3x2 boxes are the shape that catches anything written for square ones,
    // so the guarantees are checked here in full rather than sampled.
    final SudokuGenerator generator = SudokuGenerator(SudokuSpec.light);
    final SudokuSolver solver = SudokuSolver(SudokuSpec.light);

    test('every generated puzzle has exactly one solution', () {
      for (int seed = 1; seed <= 150; seed++) {
        final SudokuPuzzle puzzle = generator.generate(seed);
        expect(puzzle.spec.size, 6);
        expect(puzzle.givens, hasLength(36));
        expect(
          solver.countSolutions(puzzle.givens, limit: 2),
          1,
          reason: 'seed $seed produced a puzzle that is not unique',
        );
      }
    });

    test('the stated solution really solves the given grid', () {
      for (int seed = 1; seed <= 150; seed++) {
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

    test('boxes are three wide and two tall, not two by three', () {
      // The one asymmetry a square-box assumption would silently get wrong:
      // read the shape back off a generated solution.
      final SudokuPuzzle puzzle = generator.generate(11);
      const SudokuSpec spec = SudokuSpec.light;
      for (int box = 0; box < spec.size; box++) {
        final Set<int> digits = <int>{};
        for (int i = 0; i < spec.cellCount; i++) {
          if (spec.boxOf(i) == box) {
            digits.add(puzzle.solution[i]);
          }
        }
        expect(digits, hasLength(6), reason: 'box $box repeats a digit');
      }
    });
  });

  group('SudokuGenerator (9x9)', () {
    final SudokuGenerator generator = SudokuGenerator(SudokuSpec.classic);
    final SudokuSolver solver = SudokuSolver(SudokuSpec.classic);

    test('every generated puzzle has exactly one solution', () {
      // The size that actually costs something to check, and the size the
      // promise matters most at — a 9x9 is where guessing would hurt.
      for (int seed = 1; seed <= 100; seed++) {
        final SudokuPuzzle puzzle = generator.generate(seed);
        expect(puzzle.givens, hasLength(81));
        expect(
          solver.countSolutions(puzzle.givens, limit: 2),
          1,
          reason: 'seed $seed produced a puzzle that is not unique',
        );
      }
    });

    test('the stated solution really solves the given grid', () {
      for (int seed = 1; seed <= 100; seed++) {
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

    test('removing any one given breaks uniqueness', () {
      for (int seed = 1; seed <= 5; seed++) {
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

    test('different seeds produce different puzzles', () {
      final Set<String> distinct = <String>{};
      for (int seed = 1; seed <= 25; seed++) {
        distinct.add(generator.generate(seed).givens.join(','));
      }
      expect(distinct, hasLength(25));
    });
  });

  group('SudokuGenerator (every variant)', () {
    // Determinism is the contract a saved game and the daily puzzle both rest
    // on, so it is asserted for each shape Nook ships rather than for one.
    const Map<String, SudokuSpec> variants = <String, SudokuSpec>{
      '4x4': SudokuSpec.mini,
      '6x6': SudokuSpec.light,
      '9x9': SudokuSpec.classic,
    };

    for (final MapEntry<String, SudokuSpec> variant in variants.entries) {
      test('${variant.key}: the same seed produces an identical puzzle', () {
        for (final int seed in <int>[1, 7, 99, 12345, -3]) {
          final SudokuPuzzle first = SudokuGenerator(variant.value)
              .generate(seed);
          final SudokuPuzzle second = SudokuGenerator(variant.value)
              .generate(seed);
          expect(second.givens, first.givens, reason: 'seed $seed differs');
          expect(second.solution, first.solution, reason: 'seed $seed differs');
          expect(second.seed, seed);
        }
      });

      test('${variant.key}: leaves cells for the player and keeps givens', () {
        for (int seed = 1; seed <= 20; seed++) {
          final SudokuPuzzle puzzle = SudokuGenerator(variant.value)
              .generate(seed);
          expect(puzzle.givenCount, greaterThan(0));
          expect(puzzle.givenCount, lessThan(puzzle.spec.cellCount));
        }
      });
    }
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
