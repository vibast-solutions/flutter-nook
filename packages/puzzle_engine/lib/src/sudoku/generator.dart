import '../random.dart';
import 'puzzle.dart';
import 'solver.dart';
import 'spec.dart';

/// Generates Sudoku puzzles that are guaranteed to have exactly one solution.
///
/// The approach is the standard one, and it is standard because the guarantee
/// falls out of it rather than being bolted on:
///
/// 1. fill an empty grid by randomised backtracking, giving a complete grid;
/// 2. walk the cells in random order, clearing each one;
/// 3. put a cell back the moment clearing it leaves more than one solution.
///
/// Every intermediate grid therefore has exactly one solution, so the puzzle
/// that comes out does too — it is never checked at the end and hoped for.
///
/// Nothing here reads the clock or an unseeded random source. Two calls with
/// the same [spec] and [seed] produce identical puzzles, on any platform.
class SudokuGenerator {
  SudokuGenerator(this.spec) : _solver = SudokuSolver(spec) {
    spec.validate();
  }

  final SudokuSpec spec;
  final SudokuSolver _solver;

  /// Generates the puzzle for [seed].
  SudokuPuzzle generate(int seed) {
    final PuzzleRandom random = PuzzleRandom(seed);
    final List<int> solution = _solver.fillRandom(random.nextInt);
    final List<int> givens = List<int>.of(solution);

    final List<int> order = List<int>.generate(
      spec.cellCount,
      (int index) => index,
    );
    random.shuffle(order);

    for (final int index in order) {
      final int removed = givens[index];
      givens[index] = 0;
      if (_solver.countSolutions(givens, limit: 2) != 1) {
        givens[index] = removed;
      }
    }

    return SudokuPuzzle(
      spec: spec,
      seed: seed,
      givens: givens,
      solution: solution,
    );
  }
}
