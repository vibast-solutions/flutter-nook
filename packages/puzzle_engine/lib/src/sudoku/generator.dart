import '../random.dart';
import 'difficulty.dart';
import 'logic_solver.dart';
import 'puzzle.dart';
import 'solver.dart';
import 'spec.dart';

/// Thrown when a tier could not be produced within the attempt budget.
///
/// Reaching this means the request itself was unreasonable for the grid, not
/// that generation is flaky: see [SudokuRater.tiersFor] for which tiers a
/// shape can actually produce. Nook would rather refuse than hand back a
/// puzzle wearing a tier it does not deserve.
class SudokuGenerationException implements Exception {
  const SudokuGenerationException(this.spec, this.target, this.attempts);

  /// The grid shape that was asked for.
  final SudokuSpec spec;

  /// The tier that could not be reached.
  final SudokuDifficulty target;

  /// How many grids were tried before giving up.
  final int attempts;

  @override
  String toString() =>
      'SudokuGenerationException: no ${target.name} $spec after '
      '$attempts attempts.';
}

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
/// [generateAt] adds the second guarantee on top: the puzzle is measured by a
/// solver that only reasons the way a person does, and is handed back only once
/// it both solves that way and lands on the requested tier.
///
/// Nothing here reads the clock or an unseeded random source. Two calls with
/// the same arguments produce identical puzzles, on any platform.
class SudokuGenerator {
  SudokuGenerator(this.spec)
    : _solver = SudokuSolver(spec),
      _logic = SudokuLogicSolver(spec),
      _rater = SudokuRater(spec) {
    spec.validate();
  }

  final SudokuSpec spec;
  final SudokuSolver _solver;
  final SudokuLogicSolver _logic;
  final SudokuRater _rater;

  /// How many grids [generateAt] will carve before it gives up.
  ///
  /// A cap rather than an endless loop: a request no grid can satisfy has to
  /// end in an error the caller can see, not a spinner that never stops.
  ///
  /// Sized by the rarest tier Nook actually offers. Only about one 6x6 grid in
  /// twenty-two is Fiendish, so a budget of forty would fail one request in
  /// six; at this budget it is a rounding error. Carving a grid is cheap, and
  /// the budget is only ever spent in full when the answer is genuinely no.
  static const int defaultMaxAttempts = 200;

  /// How many ratings one grid may cost while being eased toward its tier.
  ///
  /// Each rating is a full technique solve. The easing loop almost always
  /// lands within a handful, so this only bounds the pathological grid.
  static const int _maxRatingsPerAttempt = 250;

  /// Keeps the easing pass from shuffling in step with the carving pass, which
  /// used the same seed.
  static const int _easeSalt = 0x9E3779B9;

  /// Generates the puzzle for [seed], as hard as this grid happens to fall.
  ///
  /// Used where difficulty is beside the point — tests, and the daily puzzle's
  /// fixed seed before it grows a tier of its own.
  SudokuPuzzle generate(int seed) {
    final _Carved carved = _carve(seed);
    return SudokuPuzzle(
      spec: spec,
      seed: seed,
      givens: carved.givens,
      solution: carved.solution,
    );
  }

  /// Generates a puzzle measured at [target].
  ///
  /// Carves a minimal grid, measures it, and — when it comes out harder than
  /// asked, up to and including unsolvable by deduction — puts givens back one
  /// at a time until it measures right. A grid that is *easier* than the target
  /// at its hardest is abandoned for a fresh one, because no amount of removal
  /// could make it harder without risking a second solution.
  ///
  /// Throws [SudokuGenerationException] if [maxAttempts] grids all fail.
  SudokuPuzzle generateAt(
    SudokuDifficulty target,
    int seed, {
    int maxAttempts = defaultMaxAttempts,
  }) {
    final PuzzleRandom attempts = PuzzleRandom(seed);
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final int attemptSeed = attempts.nextUint32();
      final _Carved carved = _carve(attemptSeed);
      final SudokuDifficulty? rating = _rate(carved.givens);

      if (rating != target) {
        if (!_isAbove(rating, target)) {
          // Easier than asked even with every cell it can spare removed. No
          // amount of further removal would help, so take a different grid.
          continue;
        }
        if (!_easeTowards(
          target,
          carved,
          PuzzleRandom(attemptSeed ^ _easeSalt),
        )) {
          continue;
        }
      }
      return SudokuPuzzle(
        spec: spec,
        seed: seed,
        givens: carved.givens,
        solution: carved.solution,
        difficulty: target,
      );
    }
    throw SudokuGenerationException(spec, target, maxAttempts);
  }

  /// Whether [rating] is harder than [target]. An unrated puzzle — one the
  /// technique solver could not finish — counts as harder than anything, which
  /// is what lets easing rescue it instead of throwing the grid away.
  bool _isAbove(SudokuDifficulty? rating, SudokuDifficulty target) =>
      rating == null || rating.index > target.index;

  /// Puts givens back until the grid measures [target], leaving [carved]
  /// changed only if it succeeded.
  bool _easeTowards(
    SudokuDifficulty target,
    _Carved carved,
    PuzzleRandom random,
  ) {
    final List<int> spare = List<int>.of(carved.removed);
    random.shuffle(spare);
    int budget = _maxRatingsPerAttempt;

    while (spare.isNotEmpty && budget > 0) {
      int? eased;
      for (int slot = 0; slot < spare.length && budget > 0; slot++) {
        final int index = spare[slot];
        carved.givens[index] = carved.solution[index];
        budget--;
        final SudokuDifficulty? rating = _rate(carved.givens);
        if (rating == target) {
          return true;
        }
        if (_isAbove(rating, target)) {
          // Still too hard, but a step closer: keep this given and carry on.
          eased = slot;
          break;
        }
        // Overshot into an easier tier — this was the wrong cell to restore.
        carved.givens[index] = 0;
      }
      if (eased == null) {
        return false;
      }
      spare.removeAt(eased);
    }
    return false;
  }

  SudokuDifficulty? _rate(List<int> givens) =>
      _rater.rate(_logic.solve(givens));

  /// Carves a minimal puzzle out of a fresh solution, recording which cells it
  /// emptied so they can be put back.
  _Carved _carve(int seed) {
    final PuzzleRandom random = PuzzleRandom(seed);
    final List<int> solution = _solver.fillRandom(random.nextInt);
    final List<int> givens = List<int>.of(solution);

    final List<int> order = List<int>.generate(
      spec.cellCount,
      (int index) => index,
    );
    random.shuffle(order);

    final List<int> removed = <int>[];
    for (final int index in order) {
      final int digit = givens[index];
      givens[index] = 0;
      if (_solver.countSolutions(givens, limit: 2) != 1) {
        givens[index] = digit;
      } else {
        removed.add(index);
      }
    }
    return _Carved(solution: solution, givens: givens, removed: removed);
  }
}

/// A minimal grid and the cells that were taken out of it.
class _Carved {
  _Carved({
    required this.solution,
    required this.givens,
    required this.removed,
  });

  final List<int> solution;
  final List<int> givens;
  final List<int> removed;
}
