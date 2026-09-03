import 'package:flutter/foundation.dart';

import '../chrome/move_history.dart';

/// A puzzle the player left unfinished, as it is written to disk.
///
/// Deliberately game-agnostic: every Nook game is a grid whose cells hold a
/// small number, so one row shape describes a saved Sudoku, a saved Stars and a
/// saved Duo. Nothing here is a widget, an enum or a puzzle object — [gameId]
/// and [difficulty] are the identifiers the app layer maps back to its own
/// types, which is what keeps a save readable after those types are renamed.
///
/// **The grids are stored, not regenerated from [seed].** The seed alone would
/// be smaller, and it is kept for provenance, but rebuilding a puzzle from it
/// makes every save in the world depend on the generator behaving identically
/// for ever: one tweak to the carving order and a player's entries come back
/// sitting on somebody else's givens. Storing a few hundred small integers is
/// the cheaper promise to keep.
@immutable
class SavedGame {
  SavedGame({
    required this.gameId,
    required this.difficulty,
    required this.seed,
    required List<int> givens,
    required List<int> solution,
    required List<int> cells,
    required List<int> notes,
    required this.history,
    required this.elapsed,
    required DateTime updatedAt,
    List<int>? hints,
    List<int>? regions,
    List<int>? badges,
    this.notesMode = false,
    this.wasHinted = false,
  }) : updatedAt = updatedAt.toUtc(),
       givens = List<int>.unmodifiable(givens),
       solution = List<int>.unmodifiable(solution),
       cells = List<int>.unmodifiable(cells),
       notes = List<int>.unmodifiable(notes),
       hints = List<int>.unmodifiable(hints ?? const <int>[]),
       regions = regions == null ? null : List<int>.unmodifiable(regions),
       badges = badges == null ? null : List<int>.unmodifiable(badges);

  /// Which game this is a save of — the stable identifier, never a name the
  /// player reads. One save per game id: starting another discards this one.
  final String gameId;

  /// The tier the puzzle was generated at, as its identifier.
  ///
  /// A string rather than an enum because this layer knows nothing about any
  /// one game's ladder, and because a save has to survive a tier being added
  /// above or below it.
  final String difficulty;

  /// The seed the puzzle came from.
  ///
  /// Kept as provenance — the daily puzzle is identified by its seed — rather
  /// than as the way the puzzle is restored. See the class comment.
  final int seed;

  /// The starting grid, `0` for a cell the player must fill.
  final List<int> givens;

  /// The one solution.
  final List<int> solution;

  /// The grid as the player left it: givens plus their own entries.
  final List<int> cells;

  /// The pencil marks in each cell, one bitmask per cell.
  final List<int> notes;

  /// The region each cell belongs to, one index per cell, or `null` for a game
  /// whose board has no regions.
  ///
  /// This is where a game that carries its puzzle in a region map — Stars — puts
  /// it, and it is the one field that made the store stop being sudoku's: a
  /// Sudoku is drawn from [givens] and leaves this null, while a Stars puzzle
  /// *is* its regions and leaves [givens] empty. A nullable column rather than a
  /// second table, so a Sudoku row is untouched and every field a save holds
  /// stays a named column a query can reach.
  final List<int>? regions;

  /// The constraint badges between cells, as flat triples of small integers —
  /// two cell indices and a relation — or `null` for a game whose board has no
  /// badges.
  ///
  /// Duo's counterpart of [regions]: its `=`/`x` badges are half the puzzle,
  /// and a Duo save carries them here while Sudoku and Stars leave the column
  /// null. What the three integers of a triple mean is the Duo save layer's
  /// business, the way a mark's meaning is Stars'; this layer only promises to
  /// keep the numbers.
  final List<int>? badges;

  /// The cells whose contents were given away rather than worked out.
  ///
  /// Indices into [cells], and the same idea in every game: a Sudoku digit, a
  /// Stars mark or a Duo symbol the player was handed. Kept so a resumed
  /// puzzle still shows which cells it made its own way to.
  final List<int> hints;

  /// Whether this puzzle was ever helped along, however much was undone since.
  ///
  /// Separate from [hints] because it answers a different question. A hint can
  /// be taken back off the board; that it was once shown is what a personal
  /// best has to be told about (VIB-77).
  final bool wasHinted;

  /// The moves still to take back, oldest first.
  final MoveHistory history;

  /// Whether the player left the pad writing pencil marks.
  final bool notesMode;

  /// How long the puzzle has been on screen and in the foreground.
  final Duration elapsed;

  /// When the save was last written — what makes one of them the most recent.
  ///
  /// Always UTC, whatever it was given: this is only ever compared with other
  /// saves, and a player who changes time zone must not reorder their own
  /// puzzles by doing so.
  final DateTime updatedAt;

  /// How many cells the player still has to fill.
  ///
  /// Counted over [givens], the cells a puzzle asked to be filled: a board with
  /// no givens has nothing to count and reports none, which is what keeps this
  /// sudoku-shaped measure from reaching past the end of an empty list on a
  /// Stars save. Stars measures how far along a player is by its stars, not by
  /// this.
  int get blanksLeft {
    int left = 0;
    for (int i = 0; i < givens.length; i++) {
      if (givens[i] == 0 && cells[i] == 0) {
        left++;
      }
    }
    return left;
  }

  /// How many cells the puzzle asked the player to fill.
  int get blanksTotal => givens.where((int value) => value == 0).length;

  /// How far through the puzzle the player is, from 0 to 1.
  ///
  /// A filled cell counts whether or not the digit in it is right: this is a
  /// measure of how much of the grid is written on, and telling a player they
  /// have gone backwards would mean marking their work for them, which Nook
  /// does not do anywhere else either.
  double get progress {
    final int total = blanksTotal;
    if (total == 0) {
      return 1;
    }
    return (total - blanksLeft) / total;
  }
}
