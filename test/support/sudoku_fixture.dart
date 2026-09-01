import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/sudoku/sudoku_controller.dart';
import 'package:nook/games/sudoku/sudoku_screen.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// A 4x4 puzzle with a known solution, so a test can say what it expects.
///
/// Six givens, which is the minimal set that still pins this solution — the
/// state tests assert that, so a careless edit here is caught rather than
/// quietly weakening every test that depends on it.
SudokuPuzzle fixedMiniPuzzle() {
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

/// Gives the test a phone-shaped window, so a board and its pad both fit and
/// taps are not swallowed by an off-screen scroll position.
Future<void> setPhoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Pumps the Sudoku screen with [puzzle] already generated.
///
/// Generation is replaced rather than awaited: the tests here are about what
/// happens once a player has a board, and the real generator has its own
/// exhaustive tests in the engine package.
Future<void> pumpSudokuGame(WidgetTester tester, {SudokuPuzzle? puzzle}) async {
  final SudokuPuzzle fixed = puzzle ?? fixedMiniPuzzle();
  await setPhoneSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sudokuPuzzleSourceProvider.overrideWithValue(
          (SudokuSpec spec, int seed) async => fixed,
        ),
      ],
      child: MaterialApp(
        theme: buildNookTheme(NookColors.softClay),
        home: const SudokuGamePage(variant: SudokuVariant.mini),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
