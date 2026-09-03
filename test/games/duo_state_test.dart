import 'package:flutter_test/flutter_test.dart';
import 'package:nook/chrome/move_history.dart';
import 'package:nook/games/duo/duo_state.dart';
import 'package:nook/games/duo/duo_variant.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// The solution as the cells a finished board would hold.
List<DuoCell> _solved(DuoPuzzle puzzle) => <DuoCell>[
  for (final DuoSymbol symbol in puzzle.solution) DuoCell.of(symbol),
];

DuoGameState _state(
  DuoPuzzle puzzle,
  List<DuoCell> cells, {
  int? selectedIndex,
  MoveHistory history = const MoveHistory.empty(),
}) {
  return DuoGameState(
    variant: DuoVariant.standard,
    puzzle: puzzle,
    cells: cells,
    selectedIndex: selectedIndex,
    history: history,
  );
}

void main() {
  final DuoPuzzle puzzle = DuoGenerator(DuoSpec.standard).generate(2026);
  final int aGiven = puzzle.givens.indexWhere((DuoSymbol? s) => s != null);
  final int aBlank = puzzle.givens.indexWhere((DuoSymbol? s) => s == null);

  group('DuoGameState.fresh', () {
    test('places the givens and leaves the rest empty', () {
      final DuoGameState game = DuoGameState.fresh(
        variant: DuoVariant.standard,
        puzzle: puzzle,
      );
      for (int index = 0; index < puzzle.spec.cellCount; index++) {
        if (puzzle.givens[index] == null) {
          expect(game.cellAt(index), DuoCell.empty);
        } else {
          expect(game.cellAt(index).symbol, puzzle.givens[index]);
          expect(game.isGiven(index), isTrue);
        }
      }
      expect(game.isSolved, isFalse);
    });
  });

  group('DuoGameState.isSolved', () {
    test('is true for the completed grid', () {
      expect(_state(puzzle, _solved(puzzle)).isSolved, isTrue);
    });

    test('is false while a cell is empty', () {
      final List<DuoCell> cells = _solved(puzzle)..[aBlank] = DuoCell.empty;
      expect(_state(puzzle, cells).isSolved, isFalse);
    });

    test('reads the rules, never the stored solution', () {
      // A puzzle whose `solution` field is a nonsense grid — all circles, which
      // breaks balance — but whose givens and badges are the real ones. A board
      // filled with the genuine answer is still solved, because isSolved checks
      // the rules and the badges, never the stored solution.
      final DuoPuzzle bogus = DuoPuzzle(
        spec: puzzle.spec,
        seed: puzzle.seed,
        givens: puzzle.givens,
        badges: puzzle.badges,
        solution: List<DuoSymbol>.filled(
          puzzle.spec.cellCount,
          DuoSymbol.circle,
        ),
      );
      expect(_state(bogus, _solved(puzzle)).isSolved, isTrue);
    });

    test('is false when a badge is broken', () {
      final DuoBadge badge = puzzle.badges.first;
      final List<DuoCell> cells = _solved(puzzle);
      // Flip one end of a badge's edge, breaking that badge (and, being one
      // cell wrong, the balance of its lines too) — the board is no longer
      // finished.
      cells[badge.a] = DuoCell.of(puzzle.solution[badge.a].other);
      expect(_state(puzzle, cells).isSolved, isFalse);
    });
  });

  group('undo and erase availability', () {
    test('undo needs a move and an unsolved board', () {
      final MoveHistory oneMove = const MoveHistory.empty().push(
        const BoardMove(index: 0, before: 0, after: 1),
      );
      expect(
        _state(
          puzzle,
          _solved(puzzle)..[aBlank] = DuoCell.empty,
          history: oneMove,
        ).canUndo,
        isTrue,
      );
      // Nothing to undo.
      expect(
        _state(puzzle, _solved(puzzle)..[aBlank] = DuoCell.empty).canUndo,
        isFalse,
      );
      // Solved: the control switches off with the board.
      expect(
        _state(puzzle, _solved(puzzle), history: oneMove).canUndo,
        isFalse,
      );
    });

    test('erase needs a selected, non-empty, non-given cell', () {
      final List<DuoCell> cells = DuoGameState.fresh(
        variant: DuoVariant.standard,
        puzzle: puzzle,
      ).cells.toList()..[aBlank] = DuoCell.circle;

      // A player cell with something in it: erasable.
      expect(_state(puzzle, cells, selectedIndex: aBlank).canErase, isTrue);
      // Nothing selected.
      expect(_state(puzzle, cells).canErase, isFalse);
      // A given can never be erased.
      expect(_state(puzzle, cells, selectedIndex: aGiven).canErase, isFalse);
      // An empty cell has nothing to erase.
      final int otherBlank = puzzle.givens.lastIndexWhere(
        (DuoSymbol? s) => s == null,
      );
      expect(
        _state(puzzle, cells, selectedIndex: otherBlank).canErase,
        isFalse,
      );
    });
  });
}
