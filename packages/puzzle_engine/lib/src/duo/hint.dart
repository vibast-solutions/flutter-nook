import 'package:meta/meta.dart';

import 'logic_solver.dart';
import 'puzzle.dart';
import 'spec.dart';
import 'technique.dart';

/// A symbol a player can be given, and whether anything justifies it.
///
/// [technique] is the deduction that produced it — the whole point of a Nook
/// hint is that it gives a symbol the player could have worked out, so it
/// teaches rather than only advances. It is `null` in the one case where
/// nothing could: a board whose remainder this solver cannot reason its way
/// through, where the symbol is read off the solution instead.
///
/// The Duo third of `SudokuHint` and `StarsHint`, carrying both halves of a
/// move: which cell, and which of the two symbols goes in it.
@immutable
class DuoHint {
  const DuoHint({required this.index, required this.symbol, this.technique});

  /// The cell the symbol belongs in.
  final int index;

  /// The symbol that goes there.
  final DuoSymbol symbol;

  /// The deduction behind it, or `null` if it was read off the solution.
  final DuoTechnique? technique;

  /// Whether a person could have reached this symbol from the board in front
  /// of them.
  bool get isDeduced => technique != null;

  @override
  bool operator ==(Object other) =>
      other is DuoHint &&
      other.index == index &&
      other.symbol == symbol &&
      other.technique == technique;

  @override
  int get hashCode => Object.hash(index, symbol, technique);

  @override
  String toString() =>
      'DuoHint(${symbol.name} at $index, '
      '${technique?.name ?? 'from the solution'})';
}

/// Chooses which symbol to give away when a player asks for a hint.
///
/// Which symbol matters. A hint that gives a symbol the player could have
/// deduced at that moment shows them what they were not seeing; one picked at
/// random just takes a piece of the puzzle away. So the choice is made by the
/// same technique solver that measures difficulty, run against the puzzle's
/// own givens and badges, and the first symbol it can justify in a cell the
/// player has left empty is the one that is given.
///
/// The solver reasons from the givens and badges alone rather than from the
/// board the player left — every symbol it places is one of the solution's
/// own, so any of them the player has yet to find is a correct next move. The
/// board is consulted only to skip the cells already filled: a given can never
/// be written over, and a symbol the player put down is theirs, right or
/// wrong, and a hint never writes over it either.
///
/// Deciding what to do about a *wrong* symbol is not this class's job and is
/// deliberately left to the app, which takes one wrong symbol away before it
/// asks for a hint at all. Revealing onto a board that still holds a mistake
/// would put a correct symbol into a line already poisoned by a wrong one, and
/// the board would mark the pair as a breach the moment it landed — the app
/// marking its own gift.
class DuoHinter {
  DuoHinter(this.puzzle) : _solver = DuoLogicSolver(puzzle.spec);

  /// The puzzle being played, which is where the truth about each cell is.
  final DuoPuzzle puzzle;

  final DuoLogicSolver _solver;

  /// The hint to give when the player's board stands at [board], or `null` if
  /// no cell is left empty.
  ///
  /// [board] is what each cell currently holds — givens, the player's own
  /// symbols, and `null` where nothing has been entered. The first symbol the
  /// solver justifies whose cell is still empty on [board] is the hint; when
  /// the solver cannot finish, the first empty cell is filled straight off the
  /// solution instead.
  DuoHint? hintFor(List<DuoSymbol?> board) {
    for (final DuoPlacement placement in _solver.placements(
      puzzle.givens,
      puzzle.badges,
    )) {
      // A hint never overwrites a given or what the player put down.
      if (board[placement.index] == null) {
        return DuoHint(
          index: placement.index,
          symbol: placement.symbol,
          technique: placement.technique,
        );
      }
    }
    return _fromSolution(board);
  }

  /// The first empty cell's symbol, straight off the solution.
  ///
  /// Only reached for a puzzle the technique solver cannot finish, which the
  /// generator's no-guessing guarantee says should never reach a player. If
  /// one ever does, a player who asked for help gets help: an unexplained
  /// symbol beats a button that does nothing.
  DuoHint? _fromSolution(List<DuoSymbol?> board) {
    for (int index = 0; index < board.length; index++) {
      if (board[index] == null) {
        return DuoHint(index: index, symbol: puzzle.solution[index]);
      }
    }
    return null;
  }
}
