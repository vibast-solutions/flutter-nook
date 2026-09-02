import 'package:meta/meta.dart';

import 'difficulty.dart';
import 'spec.dart';

/// A generated Sudoku: the grid the player starts from, and its one solution.
///
/// Both grids are flat, row-major lists of [SudokuSpec.cellCount] digits.
/// In [givens], `0` means the cell is empty and the player fills it; every
/// other position is a given and can never be changed.
@immutable
class SudokuPuzzle {
  SudokuPuzzle({
    required this.spec,
    required this.seed,
    required List<int> givens,
    required List<int> solution,
    this.difficulty,
  }) : givens = List<int>.unmodifiable(givens),
       solution = List<int>.unmodifiable(solution);

  /// The shape of the grid.
  final SudokuSpec spec;

  /// The seed this puzzle was generated from.
  ///
  /// The spec, the seed and [difficulty] together reproduce this puzzle
  /// exactly, on any platform and any Dart version — which is what lets a save
  /// store three small values instead of a grid.
  final int seed;

  /// The measured tier, or `null` for a puzzle generated without a target.
  ///
  /// Measured by running a solver that only makes deductions a person could
  /// make, never inferred from [givenCount].
  final SudokuDifficulty? difficulty;

  /// The starting grid, `0` for the cells the player must fill.
  final List<int> givens;

  /// The unique solution.
  final List<int> solution;

  /// How many cells are filled in at the start.
  int get givenCount => givens.where((int value) => value != 0).length;

  /// Whether the cell at [index] was given rather than entered by the player.
  bool isGiven(int index) => givens[index] != 0;

  @override
  String toString() => 'SudokuPuzzle($spec, seed $seed, $givenCount givens)';
}
