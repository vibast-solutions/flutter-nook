/// How hard a family of deductions is to see at the board.
///
/// The three bands come straight from the technique ladder in the design docs.
/// They exist so difficulty can be described by *what kind* of thinking a
/// puzzle demanded, before any counting happens.
///
/// Shared rather than Sudoku's own: every Nook game grades on the same three
/// rungs, so a rater can be written once and a difficulty tier means the same
/// depth of thinking whichever game produced it. Each game names its own
/// deductions ([SudokuTechnique], `StarsTechnique`, …) and tags each with the
/// rung it sits on.
enum TechniqueTier {
  /// Look at one cell, or one unit, and read the answer off it.
  simple,

  /// Reason about a small group of cells to rule candidates out, then place.
  intermediate,

  /// Reason across several units at once. Notes are effectively necessary.
  advanced,
}
