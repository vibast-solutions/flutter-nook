import 'package:meta/meta.dart';

import 'logic_solver.dart';
import 'puzzle.dart';
import 'technique.dart';

/// A star a player can be given, and whether anything justifies it.
///
/// [technique] is the deduction that produced it — the whole point of a Nook
/// hint is that it gives a star the player could have worked out, so it teaches
/// rather than only advances. It is `null` in the one case where nothing could:
/// a region map whose remainder this solver cannot reason its way through, where
/// the star is read off the solution instead.
///
/// The Stars twin of `SudokuHint`, with no value to carry: a Stars cell holds a
/// star or it does not, so where it goes is the whole of the hint.
@immutable
class StarsHint {
  const StarsHint({required this.index, this.technique});

  /// The cell the star belongs in.
  final int index;

  /// The deduction behind it, or `null` if it was read off the solution.
  final StarsTechnique? technique;

  /// Whether a person could have reached this star from the board in front of
  /// them.
  bool get isDeduced => technique != null;

  @override
  bool operator ==(Object other) =>
      other is StarsHint &&
      other.index == index &&
      other.technique == technique;

  @override
  int get hashCode => Object.hash(index, technique);

  @override
  String toString() =>
      'StarsHint(star at $index, ${technique?.name ?? 'from the solution'})';
}

/// Chooses which star to give away when a player asks for a hint.
///
/// Which star matters. A hint that gives a star the player could have deduced at
/// that moment shows them what they were not seeing; a star picked at random
/// just takes a piece of the puzzle away. So the choice is made by the same
/// technique solver that measures difficulty, run against the region map, and
/// the first star it can justify that the player has not already placed is the
/// one that is given.
///
/// The solver reasons from the region map alone rather than from the board the
/// player left — every star it places is one of the puzzle's own, so any of them
/// the player has yet to find is a correct next move. The board is consulted
/// only to skip the stars already down: a cell the player has put a star in is
/// theirs, right or wrong, and a hint never writes over it.
///
/// Deciding what to do about a *wrong* star is not this class's job and is
/// deliberately left to the app, which takes one wrong star away before it asks
/// for a hint at all. Revealing onto a board that still holds a mistake would
/// put a correct star into a row already poisoned by a wrong one, and the two
/// would read as a breaching pair the moment they landed — the app marking its
/// own gift.
class StarsHinter {
  StarsHinter(this.puzzle) : _solver = StarsLogicSolver(puzzle.spec);

  /// The puzzle being played, which is where the truth about each cell is.
  final StarsPuzzle puzzle;

  final StarsLogicSolver _solver;

  /// The hint to give when the player already has [stars] down, or `null` if
  /// every star of the solution is placed.
  ///
  /// [stars] is the set of cells the player currently holds a star in — the
  /// dots are annotations the hinter neither reads nor touches. The first star
  /// the solver justifies that is not already in [stars] is the hint; when the
  /// solver cannot finish, the first solution star still missing is given
  /// instead.
  StarsHint? hintFor(Set<int> stars) {
    for (final StarsPlacement placement in _solver.placements(puzzle.regions)) {
      // A hint never overwrites what the player put down.
      if (!stars.contains(placement.index)) {
        return StarsHint(
          index: placement.index,
          technique: placement.technique,
        );
      }
    }
    return _fromSolution(stars);
  }

  /// The first solution star the player has not placed, straight off the
  /// solution.
  ///
  /// Only reached for a region map the technique solver cannot finish, which the
  /// generator's no-guessing guarantee says should never reach a player. If one
  /// ever does, a player who asked for help gets help: an unexplained star beats
  /// a button that does nothing.
  StarsHint? _fromSolution(Set<int> stars) {
    for (final int index in puzzle.solution) {
      if (!stars.contains(index)) {
        return StarsHint(index: index);
      }
    }
    return null;
  }
}
