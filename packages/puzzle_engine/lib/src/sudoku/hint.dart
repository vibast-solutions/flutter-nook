import 'package:meta/meta.dart';

import 'logic_solver.dart';
import 'puzzle.dart';
import 'technique.dart';

/// A cell a player can be given, and whether anything justifies it.
///
/// [technique] is the deduction that produced it — the whole point of a Nook
/// hint is that it reveals a cell the player could have worked out, so it
/// teaches rather than only advances. It is `null` in the one case where
/// nothing could: a puzzle whose remainder this solver cannot reason its way
/// through, where the digit is read off the solution instead.
@immutable
class SudokuHint {
  const SudokuHint({required this.index, required this.digit, this.technique});

  /// Which cell to fill.
  final int index;

  /// The digit that belongs there.
  final int digit;

  /// The deduction behind it, or `null` if it was read off the solution.
  final SudokuTechnique? technique;

  /// Whether a person could have reached this cell from the board in front of
  /// them.
  bool get isDeduced => technique != null;

  @override
  bool operator ==(Object other) {
    return other is SudokuHint &&
        other.index == index &&
        other.digit == digit &&
        other.technique == technique;
  }

  @override
  int get hashCode => Object.hash(index, digit, technique);

  @override
  String toString() =>
      'SudokuHint($digit at $index, ${technique?.name ?? 'from the solution'})';
}

/// Chooses which cell to give away when a player asks for a hint.
///
/// Which cell matters. A hint that reveals a cell the player could have
/// deduced at that moment shows them what they were not seeing; a cell picked
/// at random just takes a piece of the puzzle away. So the choice is made by
/// the same technique solver that measures difficulty, run against the board
/// as it stands, and the first cell it can justify is the one that is given.
///
/// A wrong entry does not stop it. The solver is run against the board with
/// the player's mistakes treated as blanks, which is the true puzzle again and
/// so still reasons correctly, and the hint lands on a cell that is genuinely
/// empty. The wrong digit is left exactly where it is: Nook does not mark a
/// player's work, and silently correcting a cell would be marking it in the
/// most confusing way available.
class SudokuHinter {
  SudokuHinter(this.puzzle) : _solver = SudokuLogicSolver(puzzle.spec);

  /// The puzzle being played, which is where the truth about each cell is.
  final SudokuPuzzle puzzle;

  final SudokuLogicSolver _solver;

  /// The hint to give on the board [cells], or `null` if it is already full.
  ///
  /// [cells] is the grid as the player left it: givens, their answers, and `0`
  /// for anything still blank.
  SudokuHint? hintFor(List<int> cells) {
    if (cells.length != puzzle.solution.length) {
      throw ArgumentError(
        'Expected ${puzzle.solution.length} cells, got ${cells.length}.',
      );
    }
    // Anything that disagrees with the solution is reasoned around rather than
    // reasoned from: one wrong digit makes the rest of the grid unsolvable,
    // and a solver fed it would deduce a string of wrong cells before noticing.
    final List<int> consistent = <int>[
      for (int index = 0; index < cells.length; index++)
        cells[index] == puzzle.solution[index] ? cells[index] : 0,
    ];
    for (final SudokuPlacement placement in _solver.placements(consistent)) {
      // A hint never overwrites what the player put down, right or wrong.
      if (cells[placement.index] == 0) {
        return SudokuHint(
          index: placement.index,
          digit: placement.digit,
          technique: placement.technique,
        );
      }
    }
    return _fromSolution(cells);
  }

  /// The first blank cell, straight off the solution.
  ///
  /// Only reached for a puzzle the technique solver cannot finish, which the
  /// generator's no-guessing guarantee says should never reach a player. If
  /// one ever does, a player who asked for help gets help: an unexplained cell
  /// beats a button that does nothing.
  SudokuHint? _fromSolution(List<int> cells) {
    for (int index = 0; index < cells.length; index++) {
      if (cells[index] == 0) {
        return SudokuHint(index: index, digit: puzzle.solution[index]);
      }
    }
    return null;
  }
}
