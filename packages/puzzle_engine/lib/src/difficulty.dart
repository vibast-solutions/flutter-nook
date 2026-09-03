/// How hard a puzzle is, as the player is told it.
///
/// A tier is *measured* by each game's rater, never assumed from how much of
/// the board was left blank: two puzzles that look equally sparse routinely sit
/// two tiers apart. Tiers are never locked — a new player may start on
/// [fiendish].
///
/// The tiers carry no names. A name a player reads has to be translated, and
/// this package is pure Dart on purpose — so naming a tier is the app's job.
/// What lives here is the order, which is the part the rating depends on.
///
/// Shared by every Nook game rather than owned by one: Sudoku, Stars and Duo
/// all describe difficulty on the same five rungs, and a save that stores a
/// tier by [name] stays readable whichever game wrote it. Where one rung stops
/// and the next begins is each game's own tuning — see `SudokuRater` and
/// `StarsRater`.
enum PuzzleDifficulty {
  /// Every cell can be read off on its own.
  gentle,

  /// Still only scanning, but the board has to be searched for it.
  easy,

  /// At least one deduction that rules candidates out before placing.
  medium,

  /// Those deductions again and again.
  hard,

  /// Reasoning across the whole grid at once.
  fiendish,
}
