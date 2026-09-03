import 'package:meta/meta.dart';

import '../difficulty.dart';
import 'spec.dart';

/// A generated Duo puzzle: the fixed cells the player starts from, the badges
/// between cells, and the one solution.
///
/// [givens] is a flat, row-major list of [DuoSpec.cellCount] entries; a `null`
/// is an empty cell the player fills, and every other entry is a given that can
/// never be changed. [badges] are the `=`/`x` constraints, canonical and
/// sorted. [solution] is the full grid.
///
/// The board a player sees is drawn from [givens] and [badges]; [solution] is
/// what proves the puzzle has exactly one answer, and it is never consulted to
/// tell a player they are wrong — that is the whole of the "the board never
/// grades unasked" rule.
@immutable
class DuoPuzzle {
  DuoPuzzle({
    required this.spec,
    required this.seed,
    required List<DuoSymbol?> givens,
    required List<DuoBadge> badges,
    required List<DuoSymbol> solution,
    this.difficulty,
  }) : givens = List<DuoSymbol?>.unmodifiable(givens),
       badges = List<DuoBadge>.unmodifiable(
         List<DuoBadge>.of(badges)..sort(_byEdge),
       ),
       solution = List<DuoSymbol>.unmodifiable(solution);

  /// The shape of the grid.
  final DuoSpec spec;

  /// The seed this puzzle was generated from.
  ///
  /// The spec and the seed together reproduce this puzzle exactly, on any
  /// platform and any Dart version — badges and all.
  final int seed;

  /// The measured tier, or `null` for a puzzle generated without a target.
  final PuzzleDifficulty? difficulty;

  /// The starting grid, `null` for the cells the player must fill.
  final List<DuoSymbol?> givens;

  /// The constraint badges, canonical and sorted by their edge.
  final List<DuoBadge> badges;

  /// The unique solution.
  final List<DuoSymbol> solution;

  /// Whether the cell at [index] was given rather than entered by the player.
  bool isGiven(int index) => givens[index] != null;

  /// How many cells are filled in at the start.
  int get givenCount =>
      givens.where((DuoSymbol? value) => value != null).length;

  /// The relation the badge between [a] and [b] carries, or `null` if no badge
  /// sits on that edge. Order of the two cells does not matter.
  DuoRelation? relationBetween(int a, int b) {
    final int lo = a < b ? a : b;
    final int hi = a < b ? b : a;
    for (final DuoBadge badge in badges) {
      if (badge.a == lo && badge.b == hi) {
        return badge.relation;
      }
    }
    return null;
  }

  /// Orders badges by their lower cell, then upper — a total order, so two
  /// puzzles with the same badges store them identically.
  static int _byEdge(DuoBadge x, DuoBadge y) {
    final int byA = x.a.compareTo(y.a);
    return byA != 0 ? byA : x.b.compareTo(y.b);
  }

  @override
  bool operator ==(Object other) =>
      other is DuoPuzzle &&
      other.spec == spec &&
      other.seed == seed &&
      other.difficulty == difficulty &&
      _sameGivens(other.givens, givens) &&
      _sameBadges(other.badges, badges) &&
      _sameSolution(other.solution, solution);

  @override
  int get hashCode => Object.hash(
    spec,
    seed,
    difficulty,
    Object.hashAll(givens),
    Object.hashAll(badges),
    Object.hashAll(solution),
  );

  static bool _sameGivens(List<DuoSymbol?> a, List<DuoSymbol?> b) {
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

  static bool _sameBadges(List<DuoBadge> a, List<DuoBadge> b) {
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

  static bool _sameSolution(List<DuoSymbol> a, List<DuoSymbol> b) {
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
      'DuoPuzzle($spec, seed $seed, $givenCount givens, '
      '${badges.length} badges)';
}
