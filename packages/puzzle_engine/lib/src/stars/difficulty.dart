import 'package:meta/meta.dart';

import '../difficulty.dart';
import 'logic_solver.dart';
import 'spec.dart';
import 'technique.dart';

/// Where one Stars tier stops and the next begins.
///
/// **This is the tuning knob.** The boundaries are expected to move as real
/// puzzles accumulate; keeping them here means retuning a tier is a number
/// change and nothing else. Everything else — the solver, the generator, the
/// screen — reads the tiers back out and has no opinion about where they sit.
@immutable
class StarsBoundaries {
  const StarsBoundaries({required this.hardFromIntermediateSteps});

  /// How many intermediate deductions turn "needs an intermediate technique"
  /// into "needs them repeatedly" — the Medium/Hard line.
  final int hardFromIntermediateSteps;

  /// The default, and for now the only, set.
  static const StarsBoundaries fallback = StarsBoundaries(
    hardFromIntermediateSteps: 3,
  );

  /// The boundaries in force for [spec]. One set today; a variant with its own
  /// feel would add an entry here rather than a branch anywhere else.
  static StarsBoundaries forSpec(StarsSpec spec) => fallback;
}

/// Turns a Stars solve report into a tier.
///
/// The mapping is the one on the Business Logic page, read literally, and it
/// reads *only* the report — never the number of cells, the region count, or
/// how long generation took:
///
/// * **Gentle** — the simplest technique alone: a region already down to one
///   cell, over and over.
/// * **Easy** — still only the simple rungs, but it took a line-single too,
///   the row-or-column scan that sits just above a region-single.
/// * **Medium** — needed at least one intermediate technique.
/// * **Hard** — needed intermediate techniques repeatedly.
/// * **Fiendish** — needed the advanced set-counting rung.
///
/// A puzzle the solver could not finish rates `null`, which is a rejection: it
/// would need a guess, and Nook throws those away rather than dressing them up
/// as a harder tier.
class StarsRater {
  StarsRater(this.spec) : boundaries = StarsBoundaries.forSpec(spec);

  /// The grid shape being rated.
  final StarsSpec spec;

  /// The tier boundaries in force for this grid.
  final StarsBoundaries boundaries;

  /// The tier [report] describes, or `null` when the puzzle could not be
  /// finished by deduction.
  PuzzleDifficulty? rate(StarsSolveReport report) {
    if (!report.isSolved) {
      return null;
    }
    final StarsTechnique? hardest = report.hardest;
    if (hardest == null) {
      return PuzzleDifficulty.gentle;
    }
    switch (hardest.tier) {
      case TechniqueTier.simple:
        return hardest == StarsTechnique.regionSingle
            ? PuzzleDifficulty.gentle
            : PuzzleDifficulty.easy;
      case TechniqueTier.intermediate:
        return report.countOf(TechniqueTier.intermediate) >=
                boundaries.hardFromIntermediateSteps
            ? PuzzleDifficulty.hard
            : PuzzleDifficulty.medium;
      case TechniqueTier.advanced:
        return PuzzleDifficulty.fiendish;
    }
  }

  /// Which tiers a Stars grid of this shape can produce, easiest first.
  ///
  /// The 8x8 spans the whole ladder. `test/stars/difficulty_test.dart` fails if
  /// a listed tier stops being reachable, so this stays a measurement rather
  /// than a wish.
  static List<PuzzleDifficulty> tiersFor(StarsSpec spec) =>
      PuzzleDifficulty.values;
}
