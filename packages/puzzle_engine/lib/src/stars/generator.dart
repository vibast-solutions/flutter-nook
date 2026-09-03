import '../difficulty.dart';
import '../random.dart';
import 'difficulty.dart';
import 'logic_solver.dart';
import 'puzzle.dart';
import 'solver.dart';
import 'spec.dart';

/// Thrown when a puzzle could not be produced within the attempt budget.
///
/// Reaching this means something is wrong with the request or the grid, not
/// that generation is merely unlucky: Nook would rather refuse than hand back a
/// puzzle that is not unique or cannot be solved without a guess.
class StarsGenerationException implements Exception {
  const StarsGenerationException(this.spec, this.attempts, [this.target]);

  /// The grid shape that was asked for.
  final StarsSpec spec;

  /// How many placements were tried before giving up.
  final int attempts;

  /// The tier that could not be reached, or `null` for an untargeted request.
  final PuzzleDifficulty? target;

  @override
  String toString() =>
      'StarsGenerationException: no '
      '${target == null ? 'valid' : target!.name} $spec after '
      '$attempts attempts.';
}

/// How region growth is nudged to hit a tier.
///
/// The tier is *measured* from the solve, never set by the shape — but the
/// shape is what a solve has to work with, so the growth is biased toward the
/// shapes that tend to land near the wanted tier, and the rating still has the
/// final say. Compact blobs shrink to single cells and fall to the simple
/// rungs; long regions strung across many rows and columns force the
/// intermediate and advanced ones.
enum _Growth {
  /// Favour the region already largest, leaving small compact leftovers — the
  /// easy shapes.
  compact,

  /// Favour whichever region a cell would stretch furthest from its star,
  /// growing long thin regions — the hard shapes.
  spread,
}

/// Generates Stars puzzles that are guaranteed to have exactly one solution and
/// to be solvable without a guess.
///
/// Forward generation — scatter regions and hope — almost never lands on a
/// unique puzzle, so the puzzle is built **backwards** from its answer:
///
/// 1. place the stars first: one per row and column, none touching, by
///    randomised backtracking;
/// 2. grow the regions outward from those stars until every cell is claimed,
///    so each region owns exactly one star and the placement is legal for the
///    map by construction;
/// 3. check with [StarsSolver] that the map admits that one placement and no
///    other;
/// 4. check with [StarsLogicSolver] that a person could finish it without
///    guessing;
/// 5. if either check fails, grow the regions again from the same stars; after
///    enough regrowths, start over from a fresh placement.
///
/// The growth is deliberately lazy — a cell joins whichever neighbouring region
/// happens to reach it first — which leaves regions of uneven size, and a small
/// region is exactly what lets the simple technique start the chain. Shaping
/// the regions to hit a chosen difficulty is VIB-86; here whatever the simple
/// gate passes is labelled [PuzzleDifficulty.gentle].
///
/// Nothing here reads the clock or an unseeded random source. Two calls with
/// the same seed produce identical puzzles, on any platform.
class StarsGenerator {
  StarsGenerator(this.spec)
    : _solver = StarsSolver(spec),
      _logic = StarsLogicSolver(spec),
      _rater = StarsRater(spec) {
    spec.validate();
  }

  final StarsSpec spec;
  final StarsSolver _solver;
  final StarsLogicSolver _logic;
  final StarsRater _rater;

  /// How many star placements [generate] will try before giving up.
  ///
  /// A cap rather than an endless loop: a request nothing can satisfy has to
  /// end in an error the caller can see, not a spinner that never stops.
  /// Generation almost always lands on the first placement's first few
  /// regrowths, so the budget is only ever spent in full when the answer is
  /// genuinely no.
  static const int defaultMaxAttempts = 200;

  /// How many times one placement's regions are regrown before a fresh
  /// placement is drawn.
  static const int _regrowthsPerPlacement = 60;

  /// Generates the puzzle for [seed], as hard as it happens to fall, and labels
  /// it with the tier the technique solver measures.
  ///
  /// Used where the tier is beside the point — tests, and the daily puzzle's
  /// fixed seed before it grows a tier of its own. [generateAt] is what a
  /// player's choice goes through.
  ///
  /// Throws [StarsGenerationException] if the budget is exhausted.
  StarsPuzzle generate(int seed, {int maxAttempts = defaultMaxAttempts}) {
    final PuzzleRandom random = PuzzleRandom(seed);
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final List<int>? placement = _placeStars(random);
      if (placement == null) {
        continue;
      }
      for (int regrowth = 0; regrowth < _regrowthsPerPlacement; regrowth++) {
        final List<int> regions = _growRegions(
          placement,
          random,
          _Growth.compact,
        );
        final PuzzleDifficulty? tier = _tierOf(regions);
        if (tier == null) {
          continue;
        }
        return StarsPuzzle(
          spec: spec,
          seed: seed,
          regions: regions,
          solution: placement,
          difficulty: tier,
        );
      }
    }
    throw StarsGenerationException(spec, maxAttempts);
  }

  /// Generates a puzzle measured at [target].
  ///
  /// Mirrors `SudokuGenerator.generateAt`: grow a region map, rate it, accept
  /// it if it lands on [target], otherwise grow another and — after enough
  /// tries on one placement — start over from a fresh one. The growth is biased
  /// toward the shapes that tend to land near [target], but the *rating* is
  /// what a puzzle is accepted on, so the tier a player is handed is always the
  /// tier they asked for.
  ///
  /// Throws [StarsGenerationException] if [maxAttempts] placements all fail.
  StarsPuzzle generateAt(
    PuzzleDifficulty target,
    int seed, {
    int maxAttempts = defaultMaxAttempts,
  }) {
    final _Growth growth = _growthFor(target);
    final PuzzleRandom random = PuzzleRandom(seed);
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final List<int>? placement = _placeStars(random);
      if (placement == null) {
        continue;
      }
      for (int regrowth = 0; regrowth < _regrowthsPerPlacement; regrowth++) {
        final List<int> regions = _growRegions(placement, random, growth);
        if (_tierOf(regions) != target) {
          continue;
        }
        return StarsPuzzle(
          spec: spec,
          seed: seed,
          regions: regions,
          solution: placement,
          difficulty: target,
        );
      }
    }
    throw StarsGenerationException(spec, maxAttempts, target);
  }

  /// The tier of [regions], or `null` if it is not a puzzle Nook will offer:
  /// more than one placement, or one that cannot be finished without a guess.
  PuzzleDifficulty? _tierOf(List<int> regions) {
    if (_solver.countPlacements(regions, limit: 2) != 1) {
      return null;
    }
    return _rater.rate(_logic.solve(regions));
  }

  /// The growth bias to reach for [target].
  _Growth _growthFor(PuzzleDifficulty target) {
    switch (target) {
      case PuzzleDifficulty.gentle:
      case PuzzleDifficulty.easy:
        return _Growth.compact;
      case PuzzleDifficulty.medium:
      case PuzzleDifficulty.hard:
      case PuzzleDifficulty.fiendish:
        return _Growth.spread;
    }
  }

  /// Places [StarsSpec.starsPerUnit] stars in every row so that no column holds
  /// more than its share and no two stars touch, by randomised backtracking.
  ///
  /// Returns the star cells sorted, or `null` in the rare event a row cannot be
  /// filled and the search runs out — the caller simply tries again.
  List<int>? _placeStars(PuzzleRandom random) {
    final List<int> columnCount = List<int>.filled(spec.size, 0);
    final List<int> stars = <int>[];

    bool fill(int row, List<int> previousColumns) {
      if (row == spec.size) {
        return true;
      }
      final List<List<int>> choices = _rowChoices();
      random.shuffle(choices);
      for (final List<int> choice in choices) {
        if (!_clearsRow(choice, previousColumns)) {
          continue;
        }
        bool overflowed = false;
        for (final int column in choice) {
          if (columnCount[column] >= spec.starsPerUnit) {
            overflowed = true;
            break;
          }
        }
        if (overflowed) {
          continue;
        }
        for (final int column in choice) {
          columnCount[column]++;
          stars.add(spec.indexOf(row, column));
        }
        if (fill(row + 1, choice)) {
          return true;
        }
        for (final int column in choice) {
          columnCount[column]--;
          stars.removeLast();
        }
      }
      return false;
    }

    if (!fill(0, const <int>[])) {
      return null;
    }
    return stars..sort();
  }

  /// Whether no column in [choice] touches a star in the row above.
  bool _clearsRow(List<int> choice, List<int> previousColumns) {
    for (final int column in choice) {
      for (final int previous in previousColumns) {
        if ((column - previous).abs() <= 1) {
          return false;
        }
      }
    }
    return true;
  }

  /// Every way to pick [StarsSpec.starsPerUnit] non-touching columns in a row.
  List<List<int>> _rowChoices() {
    final List<List<int>> out = <List<int>>[];
    final List<int> current = List<int>.filled(spec.starsPerUnit, 0);

    void walk(int depth) {
      if (depth == spec.starsPerUnit) {
        out.add(List<int>.of(current));
        return;
      }
      final int from = depth == 0 ? 0 : current[depth - 1] + 2;
      for (int column = from; column < spec.size; column++) {
        current[depth] = column;
        walk(depth + 1);
      }
    }

    walk(0);
    return out;
  }

  /// Grows the regions outward from [placement], one cell at a time.
  ///
  /// Every star seeds its own region, so a region always owns exactly one star
  /// and is a single edge-connected blob. The frontier is walked in random
  /// order; a stale cell — one another region reached first — is skipped.
  ///
  /// When a frontier cell borders more than one region, which it joins is the
  /// whole of the [growth] bias:
  ///
  /// * [_Growth.compact] hands it to the **larger** neighbour, so a few regions
  ///   swell and the rest starve down to a cell or two — the toeholds the
  ///   simple rungs need. Even growth would make tidy equal blobs no simple
  ///   deduction can break into.
  /// * [_Growth.spread] hands it to whichever neighbour's star is **furthest**
  ///   away, drawing regions out into long thin shapes that cross many rows and
  ///   columns — which is what forces the intermediate and advanced rungs.
  ///
  /// The bias only shapes the map; the tier is still measured from the solve.
  List<int> _growRegions(
    List<int> placement,
    PuzzleRandom random,
    _Growth growth,
  ) {
    final List<int> regions = List<int>.filled(spec.cellCount, -1);
    final List<int> sizes = List<int>.filled(placement.length, 1);
    for (int region = 0; region < placement.length; region++) {
      regions[placement[region]] = region;
    }

    final List<int> frontier = <int>[];
    final List<bool> queued = List<bool>.filled(spec.cellCount, false);
    for (final int star in placement) {
      for (final int neighbour in spec.orthogonalNeighbours(star)) {
        if (regions[neighbour] == -1 && !queued[neighbour]) {
          queued[neighbour] = true;
          frontier.add(neighbour);
        }
      }
    }

    int remaining = spec.cellCount - placement.length;
    while (remaining > 0 && frontier.isNotEmpty) {
      // Swap-remove a random frontier cell: the last entry fills the hole, so a
      // removal is O(1) and the walk order stays random.
      final int slot = random.nextInt(frontier.length);
      final int last = frontier.removeLast();
      final int cell;
      if (slot < frontier.length) {
        cell = frontier[slot];
        frontier[slot] = last;
      } else {
        cell = last;
      }
      if (regions[cell] != -1) {
        continue;
      }
      int chosen = -1;
      int best = -1;
      for (final int neighbour in spec.orthogonalNeighbours(cell)) {
        final int region = regions[neighbour];
        if (region == -1) {
          continue;
        }
        final int score = switch (growth) {
          _Growth.compact => sizes[region],
          _Growth.spread => _distance(cell, placement[region]),
        };
        if (chosen == -1 || score > best) {
          chosen = region;
          best = score;
        }
      }
      if (chosen == -1) {
        // Cannot happen while the frontier holds only cells next to a claimed
        // one, but guard rather than assume.
        continue;
      }
      regions[cell] = chosen;
      sizes[chosen]++;
      remaining--;
      for (final int neighbour in spec.orthogonalNeighbours(cell)) {
        if (regions[neighbour] == -1 && !queued[neighbour]) {
          queued[neighbour] = true;
          frontier.add(neighbour);
        }
      }
    }

    return regions;
  }

  /// The Manhattan distance between two cells.
  int _distance(int a, int b) =>
      (spec.rowOf(a) - spec.rowOf(b)).abs() +
      (spec.columnOf(a) - spec.columnOf(b)).abs();
}
