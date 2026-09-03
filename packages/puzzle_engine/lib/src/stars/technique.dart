import '../technique.dart';

export '../technique.dart' show TechniqueTier;

/// One deduction a person could make at a Stars board.
///
/// Like the Sudoku ladder these carry no names — a name a player reads in a
/// hint is translated, and this package stays Flutter-free — only the rung of
/// [TechniqueTier] each sits on, which is what a difficulty measurement reads.
///
/// The declaration order is the ladder, easiest first: the solver tries them
/// in order and stops at the first that makes progress, so a puzzle is only
/// ever credited with the simplest technique that moved it.
///
/// **This story (VIB-85) carries the simple rung only.** The intermediate and
/// advanced techniques, and the rater that reads this ladder, are VIB-86; the
/// generator here produces whatever the simple rung can finish and labels it
/// [PuzzleDifficulty.gentle].
enum StarsTechnique {
  /// A row, column or region with exactly as many cells still open as it has
  /// stars left to place — so every one of them is a star.
  ///
  /// For Nook's one-star units that is "a unit with a single cell left"; the
  /// definition is written for [StarsSpec.starsPerUnit] so a two-star variant
  /// reads the same rung the same way.
  soleCandidate(TechniqueTier.simple);

  const StarsTechnique(this.tier);

  /// Which band of the ladder this belongs to.
  final TechniqueTier tier;
}
