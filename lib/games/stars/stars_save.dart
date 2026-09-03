import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../store/saved_game.dart';
import 'stars_state.dart';
import 'stars_variant.dart';

/// A saved game read back as Stars.
///
/// Stars' half of what Sudoku's [SudokuSave] does: the one place a stored row
/// becomes a Stars game again. Everything off disk is treated as possibly
/// unreadable — [read] returns `null` rather than throwing — because a save can
/// outlive the build that wrote it, and a puzzle nobody can open should quietly
/// stop being offered rather than take the home screen down with it.
///
/// The store is game-agnostic and knows nothing of a region map; this is where
/// the columns a Stars save uses become types again. A Stars row has no givens
/// and no notes: its [SavedGame.regions] is the puzzle, its [SavedGame.solution]
/// is the star cells, and its [SavedGame.cells] is the player's marks as their
/// [StarsMark] indices.
@immutable
class StarsSave {
  const StarsSave({
    required this.variant,
    required this.difficulty,
    required this.game,
    required this.elapsed,
    required this.progress,
  });

  /// Which Stars game it is.
  final StarsVariant variant;

  /// The tier it was started at.
  final PuzzleDifficulty difficulty;

  /// The board and the moves, exactly as they were left.
  final StarsGameState game;

  /// How long it has been played for.
  final Duration elapsed;

  /// How far along the player is, from 0 to 1 — stars placed over stars wanted.
  ///
  /// Measured from the stars rather than from filled cells: Stars has no givens
  /// to count blanks against, and the running count a player watches is how many
  /// of the board's stars are down.
  final double progress;

  /// Reads [save] as Stars, or returns `null` if it is not a readable one.
  static StarsSave? read(SavedGame save) {
    final StarsVariant? variant = StarsVariant.byId(save.gameId);
    if (variant == null) {
      return null;
    }
    final PuzzleDifficulty? difficulty = _difficultyNamed(save.difficulty);
    if (difficulty == null) {
      return null;
    }
    final int cellCount = variant.spec.cellCount;
    final List<int>? regions = save.regions;
    // A Stars save is exactly the one that carries a region map of the right
    // size and a mark for every cell. A Sudoku row (regions null) or a row from
    // a board of another shape is not one, and is left for another reader.
    if (regions == null ||
        regions.length != cellCount ||
        save.cells.length != cellCount) {
      return null;
    }
    final List<StarsMark>? cells = _marksFrom(save.cells);
    if (cells == null) {
      return null;
    }
    final StarsPuzzle puzzle = StarsPuzzle(
      spec: variant.spec,
      seed: save.seed,
      difficulty: difficulty,
      regions: regions,
      solution: save.solution,
    );
    final StarsGameState game = StarsGameState(
      variant: variant,
      puzzle: puzzle,
      cells: cells,
      hints: save.hints.toSet(),
      history: save.history,
      wasHinted: save.wasHinted,
    );
    return StarsSave(
      variant: variant,
      difficulty: difficulty,
      game: game,
      elapsed: save.elapsed,
      progress: _progressOf(game),
    );
  }

  /// The stored cell values as marks, or `null` if any is not one of the three.
  ///
  /// A value off disk that names no [StarsMark] is a save this build cannot
  /// read, handled the same way as every other unreadable field: skipped, not
  /// crashed on.
  static List<StarsMark>? _marksFrom(List<int> cells) {
    final List<StarsMark> marks = <StarsMark>[];
    for (final int value in cells) {
      if (value < 0 || value >= StarsMark.values.length) {
        return null;
      }
      marks.add(StarsMark.values[value]);
    }
    return marks;
  }

  static double _progressOf(StarsGameState game) {
    final int target = game.starTarget;
    if (target == 0) {
      return 1;
    }
    return game.starCount / target;
  }

  static PuzzleDifficulty? _difficultyNamed(String name) {
    for (final PuzzleDifficulty difficulty in PuzzleDifficulty.values) {
      if (difficulty.name == name) {
        return difficulty;
      }
    }
    return null;
  }
}

/// The row to write for [game], as it stands at [at] after [elapsed] of play.
///
/// Stars' counterpart to Sudoku's `savedGameFor`. The tier is passed in rather
/// than read off the puzzle: what the player chose is what the Continue card
/// should say, and a puzzle handed to the screen by a test may have been
/// measured at nothing at all.
///
/// A Stars row leaves [SavedGame.givens] and [SavedGame.notes] empty — the game
/// has neither — and puts its region map in [SavedGame.regions], its star cells
/// in [SavedGame.solution] and the player's marks in [SavedGame.cells].
SavedGame savedStarsGame(
  StarsGameState game, {
  required PuzzleDifficulty difficulty,
  required Duration elapsed,
  required DateTime at,
}) {
  return SavedGame(
    gameId: game.variant.id,
    difficulty: difficulty.name,
    seed: game.puzzle.seed,
    givens: const <int>[],
    solution: game.puzzle.solution,
    cells: <int>[for (final StarsMark mark in game.cells) mark.index],
    notes: const <int>[],
    regions: game.puzzle.regions,
    // Sorted so two saves of the same board are the same row: a set has no
    // order of its own, and a save that differed only by iteration order would
    // be a diff nobody could read.
    hints: game.hints.toList()..sort(),
    history: game.history,
    wasHinted: game.wasHinted,
    elapsed: elapsed,
    updatedAt: at,
  );
}
