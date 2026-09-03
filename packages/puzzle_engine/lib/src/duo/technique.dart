import '../technique.dart';

export '../technique.dart' show TechniqueTier;

/// One deduction a person could make at a Duo board.
///
/// Like the Sudoku and Stars ladders these carry no names — a name a player
/// reads in a hint is translated, and this package stays Flutter-free — only
/// the rung of [TechniqueTier] each sits on, which is what a difficulty
/// measurement reads.
///
/// The declaration order is the ladder, easiest first: the solver tries them in
/// order and stops at the first that moves the board, so a puzzle is only ever
/// credited with the simplest technique that worked. Within a tier the later
/// entries are the harder ones.
enum DuoTechnique {
  /// A cell forced by a badge on it: an `=` beside a filled cell copies its
  /// symbol, an `x` takes the other. The most local deduction there is.
  badge(TechniqueTier.simple),

  /// A cell forced by two of a symbol already sitting **next to** it: a run of
  /// [DuoSpec.runLimit] alike ends at the neighbour, so this cell must be the
  /// other symbol or the run grows one too long. The two-in-a-row a player
  /// reads without looking past the adjacent cells.
  noTriple(TechniqueTier.simple),

  /// A cell forced by a line that already holds all of one symbol: the row or
  /// column has its three circles (or squares), so every empty cell left in it
  /// is the other symbol.
  lineFull(TechniqueTier.simple),

  /// A cell forced by a symbol sitting one cell away **on either side**: a
  /// `circle _ circle` gap must be a square, because filling it alike would make
  /// three in a row across the gap. A step up from [noTriple] because the eye has
  /// to bridge the empty cell between the two, rather than read a pair straight
  /// off.
  ///
  /// This is the whole intermediate rung. The design's other candidate — "a line
  /// completed by counting" — turns out to be the *simple* [lineFull] rung on a
  /// binary grid: every cell a line-count could force is already forced one at a
  /// time, because the only reasons a symbol is barred from a cell (a run, a
  /// full line, a full crossing line) each place that cell through [noTriple],
  /// [lineFull] or [sandwich] before a count of the line's remaining candidates
  /// is ever reached. A separate counting rung would never fire, so there is
  /// deliberately not one.
  sandwich(TechniqueTier.intermediate),

  /// A cell forced by weighing every way a line could still be filled: a row or
  /// column is completed in the mind against the balance rule, the run rule, its
  /// own badges and everything the crossing lines already fix, and any cell that
  /// comes out the same symbol in every one of those completions is that symbol.
  /// The rung that reasons across a whole line and the lines that cross it at
  /// once, and the one a player reaches for notes to make.
  lineReading(TechniqueTier.advanced);

  const DuoTechnique(this.tier);

  /// Which band of the ladder this belongs to.
  final TechniqueTier tier;
}
