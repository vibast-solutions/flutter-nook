import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../store/saved_game.dart';
import 'sudoku_state.dart';
import 'sudoku_variant.dart';

/// A saved game read back as a Sudoku.
///
/// The one place stored identifiers become types again. Everything that comes
/// off disk is treated as possibly unreadable — [read] returns `null` rather
/// than throwing — because a save can outlive the build that wrote it, and a
/// puzzle nobody can open should quietly stop being offered instead of taking
/// the home screen down with it.
@immutable
class SudokuSave {
  const SudokuSave({
    required this.variant,
    required this.difficulty,
    required this.game,
    required this.elapsed,
    required this.progress,
  });

  /// Which Sudoku it is.
  final SudokuVariant variant;

  /// The tier it was started at.
  final SudokuDifficulty difficulty;

  /// The board, the notes and the moves, exactly as they were left.
  final SudokuGameState game;

  /// How long it has been played for.
  final Duration elapsed;

  /// How much of the grid has something written in it, from 0 to 1.
  final double progress;

  /// Reads [save] as a Sudoku, or returns `null` if it is not one.
  static SudokuSave? read(SavedGame save) {
    final SudokuVariant? variant = SudokuVariant.byId(save.gameId);
    if (variant == null) {
      return null;
    }
    final SudokuDifficulty? difficulty = _difficultyNamed(save.difficulty);
    if (difficulty == null) {
      return null;
    }
    final int cellCount = variant.spec.cellCount;
    if (save.givens.length != cellCount ||
        save.solution.length != cellCount ||
        save.cells.length != cellCount ||
        save.notes.length != cellCount) {
      return null;
    }
    return SudokuSave(
      variant: variant,
      difficulty: difficulty,
      game: SudokuGameState(
        variant: variant,
        puzzle: SudokuPuzzle(
          spec: variant.spec,
          seed: save.seed,
          difficulty: difficulty,
          givens: save.givens,
          solution: save.solution,
        ),
        cells: save.cells,
        notes: save.notes,
        history: save.history,
        notesMode: save.notesMode,
      ),
      elapsed: save.elapsed,
      progress: save.progress,
    );
  }

  static SudokuDifficulty? _difficultyNamed(String name) {
    for (final SudokuDifficulty difficulty in SudokuDifficulty.values) {
      if (difficulty.name == name) {
        return difficulty;
      }
    }
    return null;
  }
}

/// The row to write for [game], as it stands at [at] after [elapsed] of play.
///
/// The tier is passed in rather than read off the puzzle: what the player
/// chose is what the Continue card should say, and a puzzle handed to the
/// screen by a test may have been measured at nothing at all.
SavedGame savedGameFor(
  SudokuGameState game, {
  required SudokuDifficulty difficulty,
  required Duration elapsed,
  required DateTime at,
}) {
  return SavedGame(
    gameId: game.variant.id,
    difficulty: difficulty.name,
    seed: game.puzzle.seed,
    givens: game.puzzle.givens,
    solution: game.puzzle.solution,
    cells: game.cells,
    notes: game.notes,
    history: game.history,
    notesMode: game.notesMode,
    elapsed: elapsed,
    updatedAt: at,
  );
}
