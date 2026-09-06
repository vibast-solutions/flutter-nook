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
class DuoGenerationException implements Exception {
  const DuoGenerationException(this.spec, this.attempts, [this.target]);

  /// The grid shape that was asked for.
  final DuoSpec spec;

  /// How many complete grids were tried before giving up.
  final int attempts;

  /// The tier that could not be reached, or `null` for an untargeted request.
  final PuzzleDifficulty? target;

  @override
  String toString() =>
      'DuoGenerationException: no '
      '${target == null ? 'valid' : target!.name} $spec after '
      '$attempts attempts.';
}

/// Generates Duo puzzles that are guaranteed to have exactly one solution and to
/// be solvable without a guess.
///
/// The puzzle is built backwards from a finished grid, the way Sudoku's is,
/// because the uniqueness guarantee falls out of the order rather than being
/// bolted on:
///
/// 1. fill a complete valid grid by randomised backtracking against the balance
///    and no-three-in-a-row rules;
/// 2. scatter a random subset of `=`/`x` badges, each reading the relation off
///    that grid, so the grid stays a legal solution of the badges by
///    construction;
/// 3. carve the givens one at a time in random order, putting a cell straight
///    back the moment clearing it leaves more than one solution — so every grid
///    along the way has exactly one solution, and the puzzle that comes out does
///    too;
/// 4. hand what is left to [DuoLogicSolver]; if a person could not finish it
///    without guessing, restore givens until they could — the extreme being the
///    finished grid, which needs no deduction at all.
///
/// The difficulty knob (VIB-94) is **how much is given**: a harder tier scatters
/// fewer badges and keeps fewer givens, a gentler one the reverse. But the tier
/// a puzzle is finally labelled with is always *measured* off the solve by
/// [DuoRater], never assumed from those counts — the counts only shape how often
/// generation lands near a tier, and [generateAt] retries until the measurement
/// agrees.
///
/// Nothing here reads the clock or an unseeded random source. Two calls with the
/// same seed produce identical puzzles, badges and all, on any platform.
class DuoGenerator {
  DuoGenerator(this.spec)
    : _solver = DuoSolver(spec),
      _logic = DuoLogicSolver(spec),
      _rater = DuoRater(spec) {
    spec.validate();
  }

  final DuoSpec spec;
  final DuoSolver _solver;
  final DuoLogicSolver _logic;
  final DuoRater _rater;

  /// How many complete grids [generate] will try before it gives up.
  ///
  /// A cap rather than an endless loop: a request nothing can satisfy has to end
  /// in an error the caller can see, not a spinner that never stops. Carving a
  /// grid always yields a puzzle — in the worst case the finished grid itself —
  /// so the budget is only ever spent in full when the answer is genuinely no.
  static const int defaultMaxAttempts = 200;

  /// The chance each edge carries a badge for an untargeted [generate].
  ///
  /// Enough badges to give the simple techniques a foothold on most grids, few
  /// enough to leave a puzzle worth solving. [generateAt] varies this by tier.
  static const int _badgePercent = 26;

  /// The most signs a Duo board will ever show, as a percentage of its edges —
  /// a hard ceiling on top of the per-tier chance below.
  ///
  /// The per-edge chance is a *bias*; on a lucky roll it can still crowd the
  /// board. A wall of `=`/`x` signs reads as noise rather than as clues, and it
  /// was worst at the gentle end, where the chance is highest. So however the
  /// rolls fall, no board carries signs on more than this share of its edges —
  /// on the 6x6 standard board (60 edges) that is at most 16 signs. When a roll
  /// overshoots, a random subset is kept, so no corner of the board is favoured.
  /// Fewer signs lean the solve onto givens, which is the intended trade: a
  /// gentler board shows more symbols already placed and fewer signs between
  /// them (VIB-105 board-feedback follow-up).
  static const int _badgeCeilingPercent = 28;

  /// Generates the puzzle for [seed], as hard as it happens to fall, and labels
  /// it with the tier the technique solver measures.
  ///
  /// Used where the tier is beside the point — tests, and the daily puzzle's
  /// fixed seed before it grows a tier of its own. [generateAt] is what a
  /// player's choice goes through.
  ///
  /// Throws [DuoGenerationException] if the budget is exhausted.
  DuoPuzzle generate(int seed, {int maxAttempts = defaultMaxAttempts}) {
    final PuzzleRandom random = PuzzleRandom(seed);
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final List<DuoSymbol>? solution = _buildSolution(random);
      if (solution == null) {
        continue;
      }
      final List<DuoBadge> badges = _scatterBadges(
        solution,
        random,
        _badgePercent,
      );
      final List<DuoSymbol?> givens = _carve(solution, badges, random);
      _easeToGuessFree(solution, givens, badges, random);
      final PuzzleDifficulty? tier = _tierOf(givens, badges);
      if (tier == null) {
        continue;
      }
      return DuoPuzzle(
        spec: spec,
        seed: seed,
        givens: givens,
        badges: badges,
        solution: solution,
        difficulty: tier,
      );
    }
    throw DuoGenerationException(spec, maxAttempts);
  }

  /// Generates a puzzle measured at [target].
  ///
  /// Mirrors `StarsGenerator.generateAt`: build a candidate biased toward the
  /// tier, rate it, accept it if it lands on [target], otherwise vary and retry,
  /// giving up after a bounded number of attempts. The bias is the give-count —
  /// fewer badges and fewer givens for the harder tiers — but the *rating* is
  /// what a puzzle is accepted on, so the tier a player is handed is always the
  /// tier they asked for.
  ///
  /// Throws [DuoGenerationException] if [maxAttempts] grids all fail.
  DuoPuzzle generateAt(
    PuzzleDifficulty target,
    int seed, {
    int maxAttempts = defaultMaxAttempts,
  }) {
    final PuzzleRandom random = PuzzleRandom(seed);
    final int badgePercent = _badgePercentFor(target);
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final List<DuoSymbol>? solution = _buildSolution(random);
      if (solution == null) {
        continue;
      }
      final List<DuoBadge> badges = _scatterBadges(
        solution,
        random,
        badgePercent,
      );
      final List<DuoSymbol?> givens = _carve(solution, badges, random);
      _easeToGuessFree(solution, givens, badges, random);
      final DuoPuzzle? landed = _reduceToTarget(
        solution,
        givens,
        badges,
        target,
        seed,
        random,
      );
      if (landed != null) {
        return landed;
      }
    }
    throw DuoGenerationException(spec, maxAttempts, target);
  }

  /// Brings a minimal, guess-free puzzle down to [target] by restoring givens.
  ///
  /// A carved puzzle is the hardest that base can be; restoring a given only
  /// ever makes it easier. So if the puzzle already measures [target] it is
  /// taken; if it measures harder, givens are put back one at a time until it
  /// drops onto [target]; and if it is already easier — or overshoots [target]
  /// on the way down — this base cannot reach the tier and the caller tries
  /// another. Rating is measured at every step, so the label is never a guess.
  DuoPuzzle? _reduceToTarget(
    List<DuoSymbol> solution,
    List<DuoSymbol?> givens,
    List<DuoBadge> badges,
    PuzzleDifficulty target,
    int seed,
    PuzzleRandom random,
  ) {
    PuzzleDifficulty? current = _tierOf(givens, badges);
    if (current == target) {
      return _puzzleOf(solution, givens, badges, seed, target);
    }
    if (current == null || current.index < target.index) {
      return null;
    }
    final List<int> spare = <int>[
      for (int index = 0; index < spec.cellCount; index++)
        if (givens[index] == null) index,
    ];
    random.shuffle(spare);
    for (final int cell in spare) {
      givens[cell] = solution[cell];
      current = _tierOf(givens, badges);
      if (current == target) {
        return _puzzleOf(solution, givens, badges, seed, target);
      }
      if (current != null && current.index < target.index) {
        return null;
      }
    }
    return null;
  }

  DuoPuzzle _puzzleOf(
    List<DuoSymbol> solution,
    List<DuoSymbol?> givens,
    List<DuoBadge> badges,
    int seed,
    PuzzleDifficulty tier,
  ) {
    return DuoPuzzle(
      spec: spec,
      seed: seed,
      givens: givens,
      badges: badges,
      solution: solution,
      difficulty: tier,
    );
  }

  /// The measured tier of [givens] and [badges], or `null` if it is not a
  /// puzzle Nook will offer: more than one solution, or one that cannot be
  /// finished without a guess.
  PuzzleDifficulty? _tierOf(List<DuoSymbol?> givens, List<DuoBadge> badges) {
    if (_solver.countSolutions(givens, badges, limit: 2) != 1) {
      return null;
    }
    return _rater.rate(_logic.solve(givens, badges));
  }

  /// The badge density to reach for [target]: a gentler tier leans on badges,
  /// a fiendish one starves the board of them so the line-reading rung has to
  /// carry the solve.
  int _badgePercentFor(PuzzleDifficulty target) {
    switch (target) {
      case PuzzleDifficulty.gentle:
        return 26;
      case PuzzleDifficulty.easy:
        return 22;
      case PuzzleDifficulty.medium:
        return 20;
      case PuzzleDifficulty.hard:
        return 18;
      case PuzzleDifficulty.fiendish:
        return 14;
    }
  }

  /// Fills a complete grid that obeys balance and the no-three-in-a-row rule,
  /// or `null` if the randomised search runs out (impossible for a valid spec,
  /// guarded rather than assumed).
  List<DuoSymbol>? _buildSolution(PuzzleRandom random) {
    final List<int> grid = List<int>.filled(spec.cellCount, -1);
    final List<int> rowCount = List<int>.filled(spec.size * 2, 0);
    final List<int> columnCount = List<int>.filled(spec.size * 2, 0);

    bool fill(int index) {
      if (index == spec.cellCount) {
        return true;
      }
      final int row = spec.rowOf(index);
      final int column = spec.columnOf(index);
      final List<int> order = random.nextInt(2) == 0
          ? <int>[0, 1]
          : <int>[1, 0];
      for (final int symbol in order) {
        if (rowCount[row * 2 + symbol] >= spec.perSymbol ||
            columnCount[column * 2 + symbol] >= spec.perSymbol) {
          continue;
        }
        if (_wouldOverrun(grid, index, symbol)) {
          continue;
        }
        grid[index] = symbol;
        rowCount[row * 2 + symbol]++;
        columnCount[column * 2 + symbol]++;
        if (fill(index + 1)) {
          return true;
        }
        grid[index] = -1;
        rowCount[row * 2 + symbol]--;
        columnCount[column * 2 + symbol]--;
      }
      return false;
    }

    if (!fill(0)) {
      return null;
    }
    return <DuoSymbol>[for (final int value in grid) DuoSymbol.values[value]];
  }

  /// Whether putting [symbol] in [grid] at [index] would make a run one too long
  /// among the cells already placed to its left and above it.
  bool _wouldOverrun(List<int> grid, int index, int symbol) {
    int leftRun = 0;
    for (int c = spec.columnOf(index) - 1; c >= 0; c--) {
      if (grid[spec.indexOf(spec.rowOf(index), c)] != symbol) {
        break;
      }
      leftRun++;
    }
    if (leftRun >= spec.runLimit) {
      return true;
    }
    int upRun = 0;
    for (int r = spec.rowOf(index) - 1; r >= 0; r--) {
      if (grid[spec.indexOf(r, spec.columnOf(index))] != symbol) {
        break;
      }
      upRun++;
    }
    return upRun >= spec.runLimit;
  }

  /// Places a badge on a random subset of edges — each edge taken with
  /// probability [percent] — reading the relation the finished grid already has
  /// across it, and never more than [_badgeCeilingPercent] of the edges.
  List<DuoBadge> _scatterBadges(
    List<DuoSymbol> solution,
    PuzzleRandom random,
    int percent,
  ) {
    final List<(int, int)> edges = spec.edges().toList();
    final List<(int, int)> chosen = <(int, int)>[];
    for (final (int, int) edge in edges) {
      if (random.nextInt(100) >= percent) {
        continue;
      }
      chosen.add(edge);
    }
    // Hold the sign count under the ceiling however the rolls fell. Keeping a
    // shuffled prefix trims to a random subset, so the ceiling never favours the
    // edges the walk happens to reach first.
    final int maxBadges = edges.length * _badgeCeilingPercent ~/ 100;
    if (chosen.length > maxBadges) {
      random.shuffle(chosen);
      chosen.length = maxBadges;
    }
    return <DuoBadge>[
      for (final (int, int) edge in chosen)
        DuoBadge(
          a: edge.$1,
          b: edge.$2,
          relation: solution[edge.$1] == solution[edge.$2]
              ? DuoRelation.equal
              : DuoRelation.unequal,
        ),
    ];
  }

  /// Empties as many cells as can be spared while [badges] and the givens still
  /// admit exactly one solution.
  List<DuoSymbol?> _carve(
    List<DuoSymbol> solution,
    List<DuoBadge> badges,
    PuzzleRandom random,
  ) {
    final List<DuoSymbol?> givens = List<DuoSymbol?>.of(solution);
    final List<int> order = List<int>.generate(
      spec.cellCount,
      (int index) => index,
    );
    random.shuffle(order);
    for (final int index in order) {
      final DuoSymbol removed = givens[index]!;
      givens[index] = null;
      if (_solver.countSolutions(givens, badges, limit: 2) != 1) {
        givens[index] = removed;
      }
    }
    return givens;
  }

  /// Puts givens back, in random order, until a person could finish the puzzle
  /// by deduction alone. The finished grid needs no deduction, so this always
  /// terminates in a guess-free puzzle.
  void _easeToGuessFree(
    List<DuoSymbol> solution,
    List<DuoSymbol?> givens,
    List<DuoBadge> badges,
    PuzzleRandom random,
  ) {
    final List<int> spare = <int>[
      for (int index = 0; index < spec.cellCount; index++)
        if (givens[index] == null) index,
    ];
    random.shuffle(spare);
    int next = 0;
    while (!_logic.solve(givens, badges).isSolved && next < spare.length) {
      givens[spare[next]] = solution[spare[next]];
      next++;
    }
  }
}
