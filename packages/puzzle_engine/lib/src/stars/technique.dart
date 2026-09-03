import '../technique.dart';

export '../technique.dart' show TechniqueTier;

/// One deduction a person could make at a Stars board.
///
/// Like the Sudoku ladder these carry no names — a name a player reads in a
/// hint is translated, and this package stays Flutter-free — only the rung of
/// [TechniqueTier] each sits on, which is what a difficulty measurement reads.
///
/// The declaration order is the ladder, easiest first: the solver tries them in
/// order and stops at the first that makes progress, so a puzzle is only ever
/// credited with the simplest technique that moved it. Within a tier the later
/// entries are the harder ones — a line-single is a whole row or column to scan
/// where a region-single is a shape already down to one cell, which is why they
/// split Gentle from Easy the way naked and hidden singles do in Sudoku.
enum StarsTechnique {
  /// A region with exactly as many open cells as stars left to place.
  ///
  /// The most visual deduction there is: a shape already down to its last cell.
  regionSingle(TechniqueTier.simple),

  /// A row or column with exactly as many open cells as stars left to place.
  ///
  /// The same idea across a line the eye has to run along, so it sits a rung
  /// above [regionSingle].
  lineSingle(TechniqueTier.simple),

  /// A region whose remaining open cells all fall on one row or column: that
  /// line's star is this region's, so the rest of the line is ruled out.
  regionConfinedToLine(TechniqueTier.intermediate),

  /// The reverse: a row or column whose open cells all lie inside one region,
  /// so that region's star is on this line and the rest of the region is ruled
  /// out.
  lineConfinedToRegion(TechniqueTier.intermediate),

  /// Set counting across several regions at once: N regions whose open cells
  /// lie wholly within N rows (or N columns) take those lines between them, so
  /// every other cell on those lines is ruled out.
  regionSetCover(TechniqueTier.advanced);

  const StarsTechnique(this.tier);

  /// Which band of the ladder this belongs to.
  final TechniqueTier tier;
}
