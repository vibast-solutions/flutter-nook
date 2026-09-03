import 'package:meta/meta.dart';

import '../difficulty.dart';
import 'logic_solver.dart';
import 'spec.dart';
import 'technique.dart';

export '../difficulty.dart' show PuzzleDifficulty;

/// Where one tier stops and the next begins.
///
/// **This is the tuning knob.** Every boundary in Nook's difficulty model lives
/// in [_bySize] below, one line per grid size, so retuning a tier is a number
/// change and nothing else. Everything else — the solver, the generator, the
/// screen — reads the tiers back out and has no opinion about where they sit.
@immutable
class DifficultyBoundaries {
  const DifficultyBoundaries({required this.hardFromIntermediateSteps});

  /// How many intermediate deductions turn "requires ruling out" into
  /// "requires ruling out repeatedly" — the Medium/Hard line.
  final int hardFromIntermediateSteps;

  /// The default for a grid shape Nook has not tuned by hand.
  static const DifficultyBoundaries fallback = DifficultyBoundaries(
    hardFromIntermediateSteps: 3,
  );

  /// Tuned against the puzzles each grid actually produces.
  ///
  /// A 9x9 that needs three separate intermediate deductions is a noticeably
  /// longer sit than one that needs a single naked pair, which is where the
  /// line went. Only the 9x9 has an entry because only the 9x9 reaches the
  /// intermediate band often enough for the line to mean anything — see
  /// [SudokuRater.tiersFor].
  static const Map<int, DifficultyBoundaries> _bySize =
      <int, DifficultyBoundaries>{
        9: DifficultyBoundaries(hardFromIntermediateSteps: 3),
      };

  /// The boundaries for a grid of [size] cells across.
  static DifficultyBoundaries forSize(int size) => _bySize[size] ?? fallback;
}

/// Turns a solve report into a tier.
///
/// The mapping is the one on the Business Logic page, read literally: Gentle is
/// the simplest technique on its own, Easy adds the rest of the simple band,
/// Medium needs the intermediate band at all, Hard needs it repeatedly, and
/// Fiendish needs the advanced band. Clue count appears nowhere.
class SudokuRater {
  SudokuRater(this.spec) : boundaries = DifficultyBoundaries.forSize(spec.size);

  /// The grid shape being rated.
  final SudokuSpec spec;

  /// The tier boundaries in force for this grid.
  final DifficultyBoundaries boundaries;

  /// The tier [report] describes, or `null` when the puzzle could not be
  /// finished by deduction.
  ///
  /// `null` is a rejection, never a promotion: a puzzle that stalls the
  /// technique solver is one that would need a guess, and Nook throws those
  /// away rather than offering them as a harder tier.
  PuzzleDifficulty? rate(SudokuSolveReport report) {
    if (!report.isSolved) {
      return null;
    }
    final SudokuTechnique? hardest = report.hardest;
    if (hardest == null) {
      // Nothing to deduce: the grid arrived complete.
      return PuzzleDifficulty.gentle;
    }
    switch (hardest.tier) {
      case TechniqueTier.simple:
        return hardest == SudokuTechnique.nakedSingle
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

  /// Which tiers a grid of this shape can actually produce.
  ///
  /// Not every size spans the whole ladder, and offering a tier a grid cannot
  /// make would mean five buttons that hand back the same puzzle. These lists
  /// are measurements, not opinions — each was taken by rating three thousand
  /// minimal grids per shape:
  ///
  /// * **4x4** — Gentle, every time, in 3000 of 3000. Sixteen cells leave
  ///   something readable on its own at every step, so nothing harder is ever
  ///   *required*. A minimal grid is the hardest a shape can be, so this is a
  ///   ceiling rather than a tuning failure.
  /// * **6x6** — Gentle (64%), Easy (30%) and Fiendish (4.5%). The middle of
  ///   the ladder is missing rather than untuned: with six digits a chain
  ///   breaks the grid open before a pair ever bites, so Medium and Hard turn
  ///   up in under 0.3% of grids and cannot be promised on demand.
  /// * **9x9** — all five, every one of them within a few tens of
  ///   milliseconds.
  ///
  /// Retake the measurement whenever the ladder or [DifficultyBoundaries]
  /// change; `test/sudoku/difficulty_test.dart` fails if a listed tier stops
  /// being reachable.
  static List<PuzzleDifficulty> tiersFor(SudokuSpec spec) {
    switch (spec.size) {
      case 4:
        return const <PuzzleDifficulty>[PuzzleDifficulty.gentle];
      case 6:
        return const <PuzzleDifficulty>[
          PuzzleDifficulty.gentle,
          PuzzleDifficulty.easy,
          PuzzleDifficulty.fiendish,
        ];
      default:
        return PuzzleDifficulty.values;
    }
  }
}
