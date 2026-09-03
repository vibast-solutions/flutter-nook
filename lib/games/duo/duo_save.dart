import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../store/saved_game.dart';
import 'duo_state.dart';
import 'duo_variant.dart';

/// A saved game read back as Duo.
///
/// Duo's third of what Sudoku's [SudokuSave] and Stars' [StarsSave] do: the one
/// place a stored row becomes a Duo game again. Everything off disk is treated
/// as possibly unreadable — [read] returns `null` rather than throwing —
/// because a save can outlive the build that wrote it, and a puzzle nobody can
/// open should quietly stop being offered rather than take the home screen down
/// with it.
///
/// The store is game-agnostic and knows nothing of a constraint badge; this is
/// where the columns a Duo save uses become types again. A Duo row stores its
/// symbols as [DuoCell] indices — in [SavedGame.givens] (zero for a cell the
/// player fills), [SavedGame.solution] and [SavedGame.cells] alike — and its
/// badges in [SavedGame.badges] as flat triples; [SavedGame.regions] and
/// [SavedGame.notes] stay empty, because the game has neither.
@immutable
class DuoSave {
  const DuoSave({
    required this.variant,
    required this.difficulty,
    required this.game,
    required this.elapsed,
    required this.progress,
  });

  /// Which Duo game it is.
  final DuoVariant variant;

  /// The tier it was started at.
  final PuzzleDifficulty difficulty;

  /// The board and the moves, exactly as they were left.
  final DuoGameState game;

  /// How long it has been played for.
  final Duration elapsed;

  /// How much of the grid has something written in it, from 0 to 1.
  final double progress;

  /// Reads [save] as Duo, or returns `null` if it is not a readable one.
  static DuoSave? read(SavedGame save) {
    final DuoVariant? variant = DuoVariant.byId(save.gameId);
    if (variant == null) {
      return null;
    }
    final PuzzleDifficulty? difficulty = _difficultyNamed(save.difficulty);
    if (difficulty == null) {
      return null;
    }
    final int cellCount = variant.spec.cellCount;
    // A Duo save is exactly the one that carries badges — the way a region map
    // is what makes a save Stars'. A row without them, whatever its shape, is
    // left for another reader; and an empty list is still a Duo board, one that
    // happens to have no badges.
    final List<int>? encodedBadges = save.badges;
    if (encodedBadges == null ||
        save.givens.length != cellCount ||
        save.solution.length != cellCount ||
        save.cells.length != cellCount) {
      return null;
    }
    final List<DuoBadge>? badges = _badgesFrom(encodedBadges, variant.spec);
    if (badges == null) {
      return null;
    }
    final List<DuoSymbol?>? givens = _givensFrom(save.givens);
    final List<DuoSymbol>? solution = _symbolsFrom(save.solution);
    final List<DuoCell>? cells = _cellsFrom(save.cells);
    if (givens == null || solution == null || cells == null) {
      return null;
    }
    final DuoPuzzle puzzle = DuoPuzzle(
      spec: variant.spec,
      seed: save.seed,
      difficulty: difficulty,
      givens: givens,
      badges: badges,
      solution: solution,
    );
    final DuoGameState game = DuoGameState(
      variant: variant,
      puzzle: puzzle,
      cells: cells,
      hints: save.hints.toSet(),
      history: save.history,
      wasHinted: save.wasHinted,
    );
    return DuoSave(
      variant: variant,
      difficulty: difficulty,
      game: game,
      elapsed: save.elapsed,
      // A Duo given is stored as a non-zero value, so the store's own count of
      // blanks filled is the right measure, exactly as it is for Sudoku.
      progress: save.progress,
    );
  }

  /// The stored badge triples as badges, or `null` if any triple is not one.
  ///
  /// Each badge rode to disk as three integers — the two cells of its edge and
  /// its relation — and each is checked on the way back: the edge must join two
  /// adjacent cells of this grid and the relation must name one of the two. A
  /// value off disk that does neither is a save this build cannot read, handled
  /// the same way as every other unreadable field: skipped, not crashed on.
  static List<DuoBadge>? _badgesFrom(List<int> encoded, DuoSpec spec) {
    if (encoded.length % 3 != 0) {
      return null;
    }
    final List<DuoBadge> badges = <DuoBadge>[];
    for (int i = 0; i < encoded.length; i += 3) {
      final int a = encoded[i];
      final int b = encoded[i + 1];
      final int relation = encoded[i + 2];
      if (a < 0 ||
          a >= spec.cellCount ||
          relation < 0 ||
          relation >= DuoRelation.values.length) {
        return null;
      }
      final bool horizontal = b == a + 1 && spec.hasRight(a);
      final bool vertical = b == a + spec.size && spec.hasBelow(a);
      if (!horizontal && !vertical) {
        return null;
      }
      badges.add(DuoBadge(a: a, b: b, relation: DuoRelation.values[relation]));
    }
    return badges;
  }

  /// The stored given values as symbols-or-empty, or `null` if any is neither.
  static List<DuoSymbol?>? _givensFrom(List<int> values) {
    final List<DuoSymbol?> givens = <DuoSymbol?>[];
    for (final int value in values) {
      if (value < 0 || value >= DuoCell.values.length) {
        return null;
      }
      givens.add(DuoCell.values[value].symbol);
    }
    return givens;
  }

  /// The stored solution values as symbols, or `null` if any cell is empty or
  /// not a symbol — a solution has no gaps.
  static List<DuoSymbol>? _symbolsFrom(List<int> values) {
    final List<DuoSymbol> symbols = <DuoSymbol>[];
    for (final int value in values) {
      if (value < 0 || value >= DuoCell.values.length) {
        return null;
      }
      final DuoSymbol? symbol = DuoCell.values[value].symbol;
      if (symbol == null) {
        return null;
      }
      symbols.add(symbol);
    }
    return symbols;
  }

  /// The stored cell values as cells, or `null` if any is not one of the three.
  static List<DuoCell>? _cellsFrom(List<int> values) {
    final List<DuoCell> cells = <DuoCell>[];
    for (final int value in values) {
      if (value < 0 || value >= DuoCell.values.length) {
        return null;
      }
      cells.add(DuoCell.values[value]);
    }
    return cells;
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
/// Duo's counterpart to Sudoku's `savedGameFor` and Stars' `savedStarsGame`.
/// The tier is passed in rather than read off the puzzle: what the player chose
/// is what the Continue card should say, and a puzzle handed to the screen by a
/// test may have been measured at nothing at all.
///
/// Every symbol is written as its [DuoCell] index, so the three grid columns
/// share one encoding; the badges go to [SavedGame.badges] as flat triples in
/// the puzzle's own canonical order, so two saves of the same board are the
/// same row. A Duo row leaves [SavedGame.notes] empty and [SavedGame.regions]
/// null — the game has neither.
SavedGame savedDuoGame(
  DuoGameState game, {
  required PuzzleDifficulty difficulty,
  required Duration elapsed,
  required DateTime at,
}) {
  return SavedGame(
    gameId: game.variant.id,
    difficulty: difficulty.name,
    seed: game.puzzle.seed,
    givens: <int>[
      for (final DuoSymbol? given in game.puzzle.givens)
        given == null ? DuoCell.empty.index : DuoCell.of(given).index,
    ],
    solution: <int>[
      for (final DuoSymbol symbol in game.puzzle.solution)
        DuoCell.of(symbol).index,
    ],
    cells: <int>[for (final DuoCell cell in game.cells) cell.index],
    notes: const <int>[],
    badges: <int>[
      for (final DuoBadge badge in game.puzzle.badges) ...<int>[
        badge.a,
        badge.b,
        badge.relation.index,
      ],
    ],
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
