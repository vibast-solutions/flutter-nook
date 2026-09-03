import 'package:meta/meta.dart';

import '../difficulty.dart';
import 'logic_solver.dart';
import 'spec.dart';
import 'technique.dart';

/// Where one Duo tier stops and the next begins.
///
/// **This is the tuning knob.** The boundaries are expected to move as real
/// puzzles accumulate; keeping them here means retuning a tier is a number
/// change and nothing else. Everything else — the solver, the generator, the
/// screen — reads the tiers back out and has no opinion about where they sit.
@immutable
class DuoBoundaries {
  const DuoBoundaries({
    required this.easyFromSimpleSteps,
    required this.hardFromIntermediateSteps,
  });

  /// How many simple deductions turn "the simplest reasoning, a few times"
  /// into "the simplest reasoning, but a lot of it" — the Gentle/Easy line.
  ///
  /// The simple tier of Duo does not divide by *which* technique the way
  /// Sudoku's and Stars's do: a full line is completed by counting near the end
  /// of almost every solve, so [DuoTechnique.lineFull] is nearly always the
  /// hardest simple rung a puzzle reaches. What separates a gentle puzzle from
  /// an easy one is therefore how much of that simplest reasoning it asks for —
  /// which is still read off the solve, never off the given count. A gentle
  /// puzzle is a short one; an easy puzzle is the same kind of thinking, more of
  /// it.
  final int easyFromSimpleSteps;

  /// How many intermediate deductions turn "needs an intermediate technique"
  /// into "needs them repeatedly" — the Medium/Hard line.
  final int hardFromIntermediateSteps;

  /// The default, and for now the only, set.
  static const DuoBoundaries fallback = DuoBoundaries(
    easyFromSimpleSteps: 12,
    hardFromIntermediateSteps: 3,
  );

  /// The boundaries in force for [spec]. One set today; a variant with its own
  /// feel would add an entry here rather than a branch anywhere else.
  static DuoBoundaries forSpec(DuoSpec spec) => fallback;
}

/// Turns a Duo solve report into a tier.
///
/// The mapping is the one on the Business Logic page, read literally, and it
/// reads *only* the report — never the number of givens, the number of badges,
/// or how long generation took:
///
/// * **Gentle** — the simplest reasoning, and not much of it: a short solve of
///   badges, two-in-a-rows and full lines.
/// * **Easy** — the same simple rungs, but a longer solve that asks for more of
///   them.
/// * **Medium** — needed at least one intermediate technique.
/// * **Hard** — needed intermediate techniques repeatedly.
/// * **Fiendish** — needed the advanced line-reading rung.
///
/// A puzzle the solver could not finish rates `null`, which is a rejection: it
/// would need a guess, and Nook throws those away rather than dressing them up
/// as a harder tier. There is no rung above the advanced set, so a puzzle past
/// it is discarded rather than promoted.
class DuoRater {
  DuoRater(this.spec) : boundaries = DuoBoundaries.forSpec(spec);

  /// The grid shape being rated.
  final DuoSpec spec;

  /// The tier boundaries in force for this grid.
  final DuoBoundaries boundaries;

  /// The tier [report] describes, or `null` when the puzzle could not be
  /// finished by deduction.
  PuzzleDifficulty? rate(DuoSolveReport report) {
    if (!report.isSolved) {
      return null;
    }
    final DuoTechnique? hardest = report.hardest;
    if (hardest == null) {
      return PuzzleDifficulty.gentle;
    }
    switch (hardest.tier) {
      case TechniqueTier.simple:
        return report.countOf(TechniqueTier.simple) >=
                boundaries.easyFromSimpleSteps
            ? PuzzleDifficulty.easy
            : PuzzleDifficulty.gentle;
      case TechniqueTier.intermediate:
        return report.countOf(TechniqueTier.intermediate) >=
                boundaries.hardFromIntermediateSteps
            ? PuzzleDifficulty.hard
            : PuzzleDifficulty.medium;
      case TechniqueTier.advanced:
        return PuzzleDifficulty.fiendish;
    }
  }

  /// Which tiers a Duo grid of this shape can produce, easiest first.
  ///
  /// The 6x6 spans the whole ladder. `test/duo/difficulty_test.dart` fails if a
  /// listed tier stops being reachable, so this stays a measurement rather than
  /// a wish.
  static List<PuzzleDifficulty> tiersFor(DuoSpec spec) =>
      PuzzleDifficulty.values;
}
