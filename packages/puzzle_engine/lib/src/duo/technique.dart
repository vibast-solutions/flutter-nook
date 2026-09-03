import '../technique.dart';

export '../technique.dart' show TechniqueTier;

/// One deduction a person could make at a Duo board.
///
/// Like the Sudoku and Stars ladders these carry no names — a name a player
/// reads in a hint is translated, and this package stays Flutter-free — only
/// the rung of [TechniqueTier] each sits on, which is what a difficulty
/// measurement (VIB-94) reads.
///
/// This story carries the **simple** tier only: the three deductions a player
/// makes by looking at one cell, one line, or one badge and reading the answer
/// straight off. The intermediate and advanced rungs — and the rater that turns
/// a solve into a tier — arrive in VIB-94; the enum has room for them, and the
/// solver already tries the rungs in declaration order and stops at the first
/// that moves the board, so a puzzle is only ever credited with the simplest
/// technique that worked.
enum DuoTechnique {
  /// A cell forced by a badge on it: an `=` beside a filled cell copies its
  /// symbol, an `x` takes the other. The most local deduction there is.
  badge(TechniqueTier.simple),

  /// A cell forced by the no-three-in-a-row rule: it sits where one symbol
  /// would make three alike in a line, so it has to be the other.
  noTriple(TechniqueTier.simple),

  /// A cell forced by a line that already holds all of one symbol: the row or
  /// column has its three circles (or squares), so every empty cell left in it
  /// is the other symbol.
  lineFull(TechniqueTier.simple);

  const DuoTechnique(this.tier);

  /// Which band of the ladder this belongs to.
  final TechniqueTier tier;
}
