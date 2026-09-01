import 'package:meta/meta.dart';

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
  }) : givens = List<int>.unmodifiable(givens),
       solution = List<int>.unmodifiable(solution);

  /// The shape of the grid.
  final SudokuSpec spec;

  /// The seed this puzzle was generated from. The same seed and spec always
  /// reproduce it exactly, which is what lets a save store a seed rather than
  /// a grid.
  final int seed;

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
