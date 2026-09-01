import 'package:flutter_test/flutter_test.dart';
import 'package:nook/games/sudoku/sudoku_state.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// A fixed 4x4 so the expectations below are readable numbers rather than
/// whatever the generator happened to produce. The givens are the minimal set
/// that still pins this solution; the last test in the file proves it.
SudokuPuzzle _fixedPuzzle() {
  return SudokuPuzzle(
    spec: SudokuSpec.mini,
    seed: 0,
    givens: <int>[
      0, 0, 0, 0, //
      0, 0, 1, 2, //
      0, 1, 0, 3, //
      0, 3, 2, 0, //
    ],
    solution: <int>[
      1, 2, 3, 4, //
      3, 4, 1, 2, //
      2, 1, 4, 3, //
      4, 3, 2, 1, //
    ],
  );
}

SudokuGameState _fresh() =>
    SudokuGameState.fresh(variant: SudokuVariant.mini, puzzle: _fixedPuzzle());

void main() {
  group('SudokuGameState', () {
    test('starts from the givens with nothing selected', () {
      final SudokuGameState game = _fresh();
      expect(game.cells, _fixedPuzzle().givens);
      expect(game.selectedIndex, isNull);
      expect(game.selectedDigit, 0);
      expect(game.isSolved, isFalse);
    });

    test('knows which cells are givens', () {
      final SudokuGameState game = _fresh();
      expect(game.isGiven(6), isTrue);
      expect(game.isGiven(7), isTrue);
      expect(game.isGiven(0), isFalse);
      expect(game.isGiven(15), isFalse);
    });

    test('counts how many of each digit are left to place', () {
      final SudokuGameState game = _fresh();
      // Two each of 1, 2 and 3 are given; no 4 is.
      expect(game.remaining(1), 2);
      expect(game.remaining(2), 2);
      expect(game.remaining(3), 2);
      expect(game.remaining(4), 4);
      expect(game.isExhausted(4), isFalse);
    });

    test('a digit placed as often as the grid allows reads as exhausted', () {
      final SudokuGameState game = _fresh().copyWith(
        cells: List<int>.of(_fixedPuzzle().solution),
      );
      for (int digit = 1; digit <= 4; digit++) {
        expect(game.remaining(digit), 0);
        expect(game.isExhausted(digit), isTrue);
      }
    });

    test('never reports a negative remaining count', () {
      final SudokuGameState game = _fresh().copyWith(
        cells: <int>[
          1, 1, 1, 1, //
          1, 1, 1, 2, //
          0, 1, 0, 3, //
          0, 3, 2, 0, //
        ],
      );
      expect(game.remaining(1), 0);
    });

    test('sharesUnit finds rows, columns and boxes', () {
      final SudokuGameState game = _fresh();
      expect(game.sharesUnit(1, 0), isTrue, reason: 'same row');
      expect(game.sharesUnit(4, 0), isTrue, reason: 'same column');
      expect(game.sharesUnit(5, 0), isTrue, reason: 'same box');
      expect(game.sharesUnit(11, 4), isFalse);
    });

    test('is solved only when every cell matches the solution', () {
      final SudokuPuzzle puzzle = _fixedPuzzle();
      final SudokuGameState almost = _fresh().copyWith(
        cells: List<int>.of(puzzle.solution)..[7] = 0,
      );
      expect(almost.isSolved, isFalse);

      final SudokuGameState wrong = _fresh().copyWith(
        cells: List<int>.of(puzzle.solution)..[7] = 3,
      );
      expect(wrong.isSolved, isFalse);

      final SudokuGameState done = _fresh().copyWith(
        cells: List<int>.of(puzzle.solution),
      );
      expect(done.isSolved, isTrue);
    });

    test('cells cannot be modified through the state', () {
      expect(() => _fresh().cells[0] = 9, throwsUnsupportedError);
    });

    test('the fixed test puzzle really has one solution', () {
      // Guards the fixture itself: if this ever fails, the expectations above
      // are testing something that is not a Sudoku.
      expect(
        SudokuSolver(SudokuSpec.mini)
            .countSolutions(_fixedPuzzle().givens, limit: 2),
        1,
      );
    });
  });
}
