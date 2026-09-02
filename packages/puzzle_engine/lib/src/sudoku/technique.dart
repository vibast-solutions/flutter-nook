/// How hard a family of deductions is to see at the board.
///
/// The three bands come straight from the technique ladder in the design docs.
/// They exist so difficulty can be described by *what kind* of thinking a
/// puzzle demanded, before any counting happens.
enum TechniqueTier {
  /// Look at one cell, or one unit, and read the answer off it.
  simple,

  /// Reason about a small group of cells to rule candidates out, then place.
  intermediate,

  /// Reason across several units at once. Notes are effectively necessary.
  advanced,
}

/// One deduction a person could make at a Sudoku board.
///
/// The declaration order is the ladder: the solver tries them in this order and
/// stops at the first that makes progress, so a puzzle is never credited with a
/// harder technique than it actually needed. Within a tier the later entries are
/// treated as the harder ones, which is why [nakedTriple] sits after
/// [pointingPair] rather than beside [nakedPair].
enum SudokuTechnique {
  /// A cell with one candidate left.
  nakedSingle(TechniqueTier.simple, 'Naked single'),

  /// A digit with one possible cell left in a row, column or box.
  hiddenSingle(TechniqueTier.simple, 'Hidden single'),

  /// Two cells in a unit holding the same two candidates, which are therefore
  /// spoken for and can go nowhere else in that unit.
  nakedPair(TechniqueTier.intermediate, 'Naked pair'),

  /// Two digits in a unit confined to the same two cells, which therefore hold
  /// nothing else.
  hiddenPair(TechniqueTier.intermediate, 'Hidden pair'),

  /// A digit whose candidates in a box all share one line, so it cannot appear
  /// elsewhere on that line.
  pointingPair(TechniqueTier.intermediate, 'Pointing pair'),

  /// A digit whose candidates on a line all share one box, so it cannot appear
  /// elsewhere in that box.
  boxLineReduction(TechniqueTier.intermediate, 'Box/line reduction'),

  /// [nakedPair] with three cells and three digits.
  nakedTriple(TechniqueTier.intermediate, 'Naked triple'),

  /// [hiddenPair] with three digits and three cells.
  hiddenTriple(TechniqueTier.intermediate, 'Hidden triple'),

  /// A digit confined to the same two columns in two rows (or the transpose),
  /// which clears it from the rest of those columns.
  xWing(TechniqueTier.advanced, 'X-wing'),

  /// [xWing] across three lines instead of two.
  swordfish(TechniqueTier.advanced, 'Swordfish'),

  /// A two-candidate cell whose two candidates each pair with a third digit in
  /// a cell it can see, ruling that third digit out of everything both wings
  /// see.
  xyWing(TechniqueTier.advanced, 'XY-wing'),

  /// Following a chain of either-or links for one digit until the chain
  /// contradicts itself.
  simpleColouring(TechniqueTier.advanced, 'Simple colouring');

  const SudokuTechnique(this.tier, this.label);

  /// Which band of the ladder this belongs to.
  final TechniqueTier tier;

  /// The name a player would recognise, used in hints later (VIB-76).
  final String label;
}
