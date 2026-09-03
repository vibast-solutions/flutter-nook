import 'package:meta/meta.dart';

import '../difficulty.dart';
import 'spec.dart';

/// A generated Stars puzzle: the region map the player is given, and its one
/// solution.
///
/// [regions] is a flat, row-major list of [StarsSpec.cellCount] region indices,
/// each in `0 .. regionCount - 1`; two cells share a region when their entries
/// are equal. [solution] is the star cells, as their indices, sorted — there
/// are [StarsSpec.starCount] of them.
///
/// The board a player sees is drawn entirely from [regions]; [solution] is
/// what proves the puzzle has exactly one answer and, later, what a hint reads.
/// It is never consulted to tell a player they are wrong — that is the whole of
/// the "the board never grades unasked" rule.
@immutable
class StarsPuzzle {
  StarsPuzzle({
    required this.spec,
    required this.seed,
    required List<int> regions,
    required List<int> solution,
    this.difficulty,
  }) : regions = List<int>.unmodifiable(regions),
       solution = List<int>.unmodifiable(List<int>.of(solution)..sort());

  /// The shape of the grid.
  final StarsSpec spec;

  /// The seed this puzzle was generated from.
  ///
  /// The spec and the seed together reproduce this puzzle exactly, on any
  /// platform and any Dart version — which is what lets the daily puzzle be
  /// the same for everyone from the date alone.
  final int seed;

  /// The measured tier, or `null` for a puzzle generated without a target.
  final PuzzleDifficulty? difficulty;

  /// One region index per cell, row-major.
  final List<int> regions;

  /// The star cells of the unique solution, sorted.
  final List<int> solution;

  /// The region the cell at [index] belongs to.
  int regionOf(int index) => regions[index];

  @override
  bool operator ==(Object other) =>
      other is StarsPuzzle &&
      other.spec == spec &&
      other.seed == seed &&
      other.difficulty == difficulty &&
      _sameList(other.regions, regions) &&
      _sameList(other.solution, solution);

  @override
  int get hashCode => Object.hash(
    spec,
    seed,
    difficulty,
    Object.hashAll(regions),
    Object.hashAll(solution),
  );

  static bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  String toString() =>
      'StarsPuzzle($spec, seed $seed, ${solution.length} stars)';
}
