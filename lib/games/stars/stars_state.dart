import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/move_history.dart';
import 'stars_variant.dart';

/// What one Stars cell holds.
///
/// Three states, cycled by a tap: nothing, a ruled-out dot, a star. The dot is
/// an annotation the player makes and nothing more — it is never placed for
/// them, never checked, and putting one where a star belongs is allowed. The
/// order the values are declared in is the order a tap moves through them, and
/// [index] is what a saved move records, so it must stay stable.
enum StarsMark {
  /// Untouched.
  empty,

  /// The player has marked this cell as holding no star.
  ruledOut,

  /// The player has placed a star here.
  star,
}

/// A Stars puzzle in progress: the region map, what the player has marked so
/// far, and which cell they last touched.
///
/// Immutable — every change produces a new instance — which is what will make
/// undo (VIB-87) and resume (VIB-89) additions rather than rewrites. It mirrors
/// `SudokuGameState`: the marks stand in for the digits, and there is no number
/// pad because a tap on the board is the whole of the input.
@immutable
class StarsGameState {
  StarsGameState({
    required this.variant,
    required this.puzzle,
    required List<StarsMark> cells,
    Set<int>? hints,
    this.selectedIndex,
    this.history = const MoveHistory.empty(),
    this.wasHinted = false,
  }) : cells = List<StarsMark>.unmodifiable(cells),
       hints = Set<int>.unmodifiable(hints ?? const <int>{});

  /// Starts a fresh game from a generated [puzzle], every cell empty.
  factory StarsGameState.fresh({
    required StarsVariant variant,
    required StarsPuzzle puzzle,
  }) {
    return StarsGameState(
      variant: variant,
      puzzle: puzzle,
      cells: List<StarsMark>.filled(puzzle.spec.cellCount, StarsMark.empty),
    );
  }

  /// Which Stars game this is.
  final StarsVariant variant;

  /// The generated puzzle: its region map and its one solution.
  final StarsPuzzle puzzle;

  /// The mark in each cell, row-major.
  final List<StarsMark> cells;

  /// The cells a hint placed a star in, so the board can keep saying which
  /// stars were given away rather than worked out (VIB-90). Empty until then.
  final Set<int> hints;

  /// Whether this puzzle was ever helped along by a hint.
  ///
  /// Sticky, unlike [hints]: help stays counted even after a revealed star is
  /// taken back, which is what tells statistics the time counts but the
  /// personal best does not. Nothing sets it until VIB-90.
  final bool wasHinted;

  /// The cell the player last touched, or `null` if none.
  final int? selectedIndex;

  /// The moves the player can still take back.
  ///
  /// Held in the shared type every game uses, plain enough to be written to
  /// disk as it stands. The action row that spends it is VIB-87.
  final MoveHistory history;

  /// The shape of the grid.
  StarsSpec get spec => puzzle.spec;

  /// The tier this puzzle was measured at.
  PuzzleDifficulty? get difficulty => puzzle.difficulty;

  /// The mark in the cell at [index].
  StarsMark markAt(int index) => cells[index];

  /// Whether the cell at [index] holds a star.
  bool isStar(int index) => cells[index] == StarsMark.star;

  /// Whether the star in the cell at [index] came from a hint.
  bool isHinted(int index) => hints.contains(index);

  /// The region the cell at [index] belongs to.
  int regionOf(int index) => puzzle.regions[index];

  /// How many stars are on the board.
  int get starCount {
    int count = 0;
    for (final StarsMark mark in cells) {
      if (mark == StarsMark.star) {
        count++;
      }
    }
    return count;
  }

  /// How many stars a finished board holds.
  int get starTarget => spec.starCount;

  /// Whether the board obeys every rule of the game and is therefore finished.
  ///
  /// Read straight off the marks and the rules — the solution is **never**
  /// consulted. A board matches the one solution exactly when it has the right
  /// number of stars, one in every row, column and region, and no two
  /// touching; there is nothing else it could be, and checking the rules rather
  /// than the answer is what keeps the board from being an oracle to brute
  /// force rather than a puzzle to solve.
  bool get isSolved {
    final List<int> stars = <int>[
      for (int index = 0; index < cells.length; index++)
        if (cells[index] == StarsMark.star) index,
    ];
    if (stars.length != spec.starCount) {
      return false;
    }
    final List<int> perRow = List<int>.filled(spec.size, 0);
    final List<int> perColumn = List<int>.filled(spec.size, 0);
    final List<int> perRegion = List<int>.filled(spec.regionCount, 0);
    for (final int star in stars) {
      perRow[spec.rowOf(star)]++;
      perColumn[spec.columnOf(star)]++;
      perRegion[puzzle.regions[star]]++;
    }
    for (int unit = 0; unit < spec.size; unit++) {
      if (perRow[unit] != spec.starsPerUnit ||
          perColumn[unit] != spec.starsPerUnit ||
          perRegion[unit] != spec.starsPerUnit) {
        return false;
      }
    }
    final Set<int> starSet = stars.toSet();
    for (final int star in stars) {
      for (final int neighbour in spec.neighbours(star)) {
        if (starSet.contains(neighbour)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Whether there is a move to take back.
  ///
  /// A solved grid is finished, so the control switches off with the rest of
  /// the board — taking a star back out of a solved board would only be a way
  /// to unsolve it by accident.
  bool get canUndo => history.canUndo && !isSolved;

  /// Whether erase has a cell to empty: one is selected, it is not already
  /// empty, and the puzzle is still being played.
  bool get canErase =>
      !isSolved &&
      selectedIndex != null &&
      cells[selectedIndex!] != StarsMark.empty;

  /// Whether there is a ruled-out dot anywhere for "clear marks" to wipe.
  ///
  /// Stars alone: only the dot is the player's annotation, so this is the one
  /// control that reaches across the board rather than the selected cell.
  bool get canClearMarks =>
      !isSolved && cells.any((StarsMark mark) => mark == StarsMark.ruledOut);

  /// A copy with the given fields replaced.
  ///
  /// [selectedIndex] cannot be cleared through this; nothing needs to.
  StarsGameState copyWith({
    List<StarsMark>? cells,
    Set<int>? hints,
    int? selectedIndex,
    MoveHistory? history,
    bool? wasHinted,
  }) {
    return StarsGameState(
      variant: variant,
      puzzle: puzzle,
      cells: cells ?? this.cells,
      hints: hints ?? this.hints,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      history: history ?? this.history,
      wasHinted: wasHinted ?? this.wasHinted,
    );
  }
}
