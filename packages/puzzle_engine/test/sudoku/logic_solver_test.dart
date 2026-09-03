import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

/// The three shapes Nook ships, so every test states which grid it failed on.
const Map<String, SudokuSpec> variants = <String, SudokuSpec>{
  '4x4': SudokuSpec.mini,
  '6x6': SudokuSpec.light,
  '9x9': SudokuSpec.classic,
};

/// A second, genuinely different solution of [grid], or `null` if it has only
/// one.
///
/// Used to build the fork the technique solver must refuse to jump: the cells
/// where two solutions disagree are precisely the cells that cannot be deduced.
List<int>? otherSolution(SudokuSpec spec, List<int> grid, List<int> first) {
  final SudokuSolver solver = SudokuSolver(spec);
  for (int index = 0; index < grid.length; index++) {
    if (grid[index] != 0) {
      continue;
    }
    for (int digit = 1; digit <= spec.size; digit++) {
      if (digit == first[index]) {
        continue;
      }
      final List<int> forced = List<int>.of(grid)..[index] = digit;
      final List<int>? solution = solver.solve(forced);
      if (solution != null) {
        return solution;
      }
    }
  }
  return null;
}

void main() {
  group('SudokuLogicSolver never guesses', () {
    variants.forEach((String name, SudokuSpec spec) {
      test('$name: an empty grid tells it nothing, so it places nothing', () {
        // The sharpest form of the guarantee. An empty grid has an enormous
        // number of solutions, so a solver that tries digits to see what
        // happens would fill it in immediately. This one has nothing to
        // deduce and must therefore do nothing at all.
        final SudokuSolveReport report = SudokuLogicSolver(spec)
            .solve(List<int>.filled(spec.cellCount, 0));

        expect(report.isSolved, isFalse);
        expect(report.steps, isEmpty);
        expect(report.cells, everyElement(0));
      });

      test('$name: it stops at the fork when a grid has two solutions', () {
        final SudokuGenerator generator = SudokuGenerator(spec);
        final SudokuLogicSolver logic = SudokuLogicSolver(spec);
        int forksTested = 0;

        for (int seed = 1; seed <= 40 && forksTested < 10; seed++) {
          final SudokuPuzzle puzzle = generator.generate(seed);
          // Taking a given away is the cheapest way to manufacture ambiguity:
          // the puzzle was minimal, so any removal costs it its uniqueness.
          final int given = puzzle.givens.indexWhere((int d) => d != 0);
          final List<int> ambiguous = List<int>.of(puzzle.givens)..[given] = 0;
          final List<int>? second = otherSolution(
            spec,
            ambiguous,
            puzzle.solution,
          );
          if (second == null) {
            continue;
          }
          forksTested++;

          final SudokuSolveReport report = logic.solve(ambiguous);
          expect(
            report.isSolved,
            isFalse,
            reason: 'seed $seed: finished a grid with two answers',
          );
          for (int i = 0; i < spec.cellCount; i++) {
            if (puzzle.solution[i] != second[i]) {
              expect(
                report.cells[i],
                0,
                reason:
                    'seed $seed: cell $i differs between the two solutions, '
                    'so nothing can justify filling it',
              );
            }
          }
        }

        expect(
          forksTested,
          greaterThan(0),
          reason: 'the test never managed to build an ambiguous grid',
        );
      });
    });
  });

  group('SudokuLogicSolver is sound', () {
    variants.forEach((String name, SudokuSpec spec) {
      test('$name: every digit it places is the one the puzzle wanted', () {
        // Covers the whole ladder at once: an unsound elimination anywhere in
        // it eventually shows up here as a digit in the wrong square.
        final SudokuGenerator generator = SudokuGenerator(spec);
        final SudokuLogicSolver logic = SudokuLogicSolver(spec);

        for (int seed = 1; seed <= 120; seed++) {
          final SudokuPuzzle puzzle = generator.generate(seed);
          final SudokuSolveReport report = logic.solve(puzzle.givens);
          for (int i = 0; i < spec.cellCount; i++) {
            if (report.cells[i] != 0) {
              expect(
                report.cells[i],
                puzzle.solution[i],
                reason: 'seed $seed: wrong digit deduced for cell $i',
              );
            }
          }
        }
      });
    });
  });

  group('SudokuLogicSolver reports what it needed', () {
    test('an already-solved grid needs no techniques', () {
      final SudokuPuzzle puzzle = SudokuGenerator(SudokuSpec.light).generate(7);
      final SudokuSolveReport report = SudokuLogicSolver(SudokuSpec.light)
          .solve(puzzle.solution);

      expect(report.isSolved, isTrue);
      expect(report.steps, isEmpty);
      expect(report.hardest, isNull);
      expect(report.hardestTier, isNull);
    });

    test('a grid that already breaks the rules is refused', () {
      final List<int> broken = List<int>.filled(SudokuSpec.mini.cellCount, 0);
      broken[0] = 3;
      broken[1] = 3;

      final SudokuSolveReport report = SudokuLogicSolver(SudokuSpec.mini)
          .solve(broken);

      expect(report.isSolved, isFalse);
      expect(report.steps, isEmpty);
    });

    test('the easiest rung that works is the one that gets charged', () {
      // A 4x4 always has a cell readable on its own, so nothing above the
      // bottom rung should ever be reached for one.
      final SudokuGenerator generator = SudokuGenerator(SudokuSpec.mini);
      final SudokuLogicSolver logic = SudokuLogicSolver(SudokuSpec.mini);

      for (int seed = 1; seed <= 60; seed++) {
        final SudokuSolveReport report = logic.solve(
          generator.generate(seed).givens,
        );
        expect(report.isSolved, isTrue, reason: 'seed $seed stalled');
        expect(
          report.steps.keys,
          everyElement(SudokuTechnique.nakedSingle),
          reason: 'seed $seed was charged for more than it needed',
        );
      }
    });

    test('counts add up per tier and per technique', () {
      final SudokuPuzzle puzzle = SudokuGenerator(SudokuSpec.classic)
          .generateAt(PuzzleDifficulty.hard, 4);
      final SudokuSolveReport report = SudokuLogicSolver(SudokuSpec.classic)
          .solve(puzzle.givens);

      int fromSteps = 0;
      report.steps.forEach(
        (SudokuTechnique t, int count) => fromSteps += count,
      );
      int fromTiers = 0;
      for (final TechniqueTier tier in TechniqueTier.values) {
        fromTiers += report.countOf(tier);
      }

      expect(fromTiers, fromSteps);
      expect(
        report.countTechnique(SudokuTechnique.nakedSingle),
        report.steps[SudokuTechnique.nakedSingle] ?? 0,
      );
      expect(report.countTechnique(SudokuTechnique.swordfish), isNonNegative);
    });

    test('real 9x9 puzzles exercise every rung of the ladder', () {
      // Guards against a technique that is written but never fires — dead code
      // in here would quietly change what every tier above it means. All
      // twelve turn up within this many seeds; swordfish and hidden triple are
      // the rare ones and are why the sample is not smaller.
      final SudokuGenerator generator = SudokuGenerator(SudokuSpec.classic);
      final SudokuLogicSolver logic = SudokuLogicSolver(SudokuSpec.classic);
      final Set<SudokuTechnique> seen = <SudokuTechnique>{};

      for (int seed = 1; seed <= 400; seed++) {
        seen.addAll(logic.solve(generator.generate(seed).givens).steps.keys);
      }

      expect(seen, containsAll(SudokuTechnique.values));
    });
  });
}
