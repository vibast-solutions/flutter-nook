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

/// A star a hint has just taken off the board.
///
/// Kept so the board can show the cell being emptied — the star is already gone
/// from the grid by the time anything draws, and a cell that simply blanked
/// would look like a bug rather than like a star being taken away. Never written
/// to disk: it describes a moment, not a game.
///
/// The Stars twin of Sudoku's `HintRemoval`, with no digit to carry: a cell held
/// a star or it did not.
@immutable
class StarRemoval {
  const StarRemoval({required this.index});

  /// The cell that was emptied.
  final int index;

  @override
  bool operator ==(Object other) =>
      other is StarRemoval && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => 'StarRemoval(star at $index)';
}

/// The rule a star in breach breaks. Each is a separate rule of the game.
///
/// A star can break more than one at once — two stars side by side share a row
/// *and* touch — so the board names the most specific one it can, in the order
/// the values are declared: touching is the most local thing to point at, then
/// the region, then the two lines. Whichever is named, it is a rule genuinely
/// broken; the pair, not the rule, is the thing to look at.
enum StarBreach {
  /// Another star touches this one — one of the eight neighbouring cells.
  adjacent,

  /// Another star sits in this one's region.
  region,

  /// Another star sits in this one's row.
  row,

  /// Another star sits in this one's column.
  column,
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
    this.starRemoval,
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

  /// The star a hint has just taken off the board, or `null` if the last thing
  /// that happened was anything else.
  ///
  /// Transient, and the one piece of this state a save does not carry: it exists
  /// for the length of an animation, and a puzzle resumed tomorrow should not
  /// replay a star being crossed out.
  final StarRemoval? starRemoval;

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

  /// The cells the player currently holds a star in.
  ///
  /// What a hint is handed so it can skip them: a cell already starred is the
  /// player's, and a hint never writes over it.
  Set<int> get starCells => <int>{
    for (int index = 0; index < cells.length; index++)
      if (cells[index] == StarsMark.star) index,
  };

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

  /// Each star in breach, mapped to the rule it most saliently breaks.
  ///
  /// Computed from the marks and the rules alone — [puzzle] is never consulted
  /// for the answer. A star is in breach when another star shares its row, its
  /// column or its region, or touches it; a star that breaks none of those is
  /// left in peace however wrong it is, because a board that marked it would be
  /// an oracle to brute-force rather than a puzzle to solve. A ruled-out dot is
  /// an annotation and can never breach.
  ///
  /// Both stars in a breach are marked, never one singled out as the intruder:
  /// deciding which of the two is wrong would mean knowing the answer.
  late final Map<int, StarBreach> _breaches = _breachedStars();

  /// The cells holding a star that breaks a rule.
  late final Set<int> breaches = Set<int>.unmodifiable(_breaches.keys);

  /// Whether the star in the cell at [index] breaks a rule.
  bool isBreaching(int index) => _breaches.containsKey(index);

  /// The rule the star at [index] most saliently breaks, or `null` if it is in
  /// no breach (or holds no star).
  StarBreach? breachAt(int index) => _breaches[index];

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

  /// Works out every star in breach and the rule each one most saliently
  /// breaks.
  ///
  /// One pass groups the stars by row, by column and by region — a group of
  /// more than one is a broken line or region, and every star in it is marked —
  /// and a second pass checks each star against its neighbours for the touching
  /// rule. Where a star ends up breaking several rules, the salient one is the
  /// first [StarBreach] value it broke.
  Map<int, StarBreach> _breachedStars() {
    final List<int> stars = <int>[
      for (int index = 0; index < cells.length; index++)
        if (cells[index] == StarsMark.star) index,
    ];
    final Map<int, Set<StarBreach>> kinds = <int, Set<StarBreach>>{};
    void mark(int index, StarBreach kind) =>
        (kinds[index] ??= <StarBreach>{}).add(kind);

    // A shared row, column or region: group the stars by the unit and mark
    // every star in a group of more than one.
    final Map<StarBreach, int Function(int)> units =
        <StarBreach, int Function(int)>{
          StarBreach.row: spec.rowOf,
          StarBreach.column: spec.columnOf,
          StarBreach.region: regionOf,
        };
    units.forEach((StarBreach kind, int Function(int) unitOf) {
      final Map<int, List<int>> byUnit = <int, List<int>>{};
      for (final int star in stars) {
        (byUnit[unitOf(star)] ??= <int>[]).add(star);
      }
      for (final List<int> group in byUnit.values) {
        if (group.length > 1) {
          for (final int star in group) {
            mark(star, kind);
          }
        }
      }
    });

    // Touching: any of the eight neighbours holding a star, diagonals included.
    final Set<int> starSet = stars.toSet();
    for (final int star in stars) {
      for (final int neighbour in spec.neighbours(star)) {
        if (starSet.contains(neighbour)) {
          mark(star, StarBreach.adjacent);
          break;
        }
      }
    }

    return <int, StarBreach>{
      for (final MapEntry<int, Set<StarBreach>> entry in kinds.entries)
        entry.key: _salient(entry.value),
    };
  }

  /// The rule to name for a star that broke [kinds]: the first [StarBreach]
  /// value it broke, since the values are declared most-specific first.
  StarBreach _salient(Set<StarBreach> kinds) =>
      StarBreach.values.firstWhere(kinds.contains);

  /// A copy with the given fields replaced.
  ///
  /// [selectedIndex] cannot be cleared through this; nothing needs to.
  /// [starRemoval] can, through [forgetRemoval], because it has to be: it marks
  /// a moment, and every move after that moment has to be able to say the moment
  /// is over.
  StarsGameState copyWith({
    List<StarsMark>? cells,
    Set<int>? hints,
    int? selectedIndex,
    MoveHistory? history,
    bool? wasHinted,
    StarRemoval? starRemoval,
    bool forgetRemoval = false,
  }) {
    return StarsGameState(
      variant: variant,
      puzzle: puzzle,
      cells: cells ?? this.cells,
      hints: hints ?? this.hints,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      history: history ?? this.history,
      wasHinted: wasHinted ?? this.wasHinted,
      starRemoval: forgetRemoval ? null : (starRemoval ?? this.starRemoval),
    );
  }
}
