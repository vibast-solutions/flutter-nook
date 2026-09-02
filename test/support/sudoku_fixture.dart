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
    difficulty: SudokuDifficulty.gentle,
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

/// A puzzle for [variant], the same one every run.
///
/// The 6x6 and 9x9 grids are generated rather than written out: the engine is
/// deterministic, so a seed names a puzzle as precisely as eighty-one digits
/// would, and a test that says what it wants beats a wall of numbers nobody
/// can check by eye. The 4x4 keeps its handwritten one, which several tests
/// assert exact answers against.
SudokuPuzzle fixedPuzzle(SudokuVariant variant) {
  if (variant == SudokuVariant.mini) {
    return fixedMiniPuzzle();
  }
  return SudokuGenerator(variant.spec)
      .generateAt(SudokuDifficulty.gentle, 2026);
}

/// The three Sudokus, for a test that has to hold for all of them.
const List<SudokuVariant> allVariants = <SudokuVariant>[
  SudokuVariant.mini,
  SudokuVariant.light,
  SudokuVariant.classic,
];

/// Gives the test a phone-shaped window, so a board and its pad both fit and
/// taps are not swallowed by an off-screen scroll position.
///
/// [width] defaults to a common phone; pass [kSmallestSupportedWidth] to check
/// the layout where it is tightest.
Future<void> setPhoneSurface(WidgetTester tester, {double width = 400}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Pumps the Sudoku screen with a puzzle already generated.
///
/// Generation is replaced rather than awaited: the tests here are about what
/// happens once a player has a board, and the real generator has its own
/// exhaustive tests in the engine package.
Future<void> pumpSudokuGame(
  WidgetTester tester, {
  SudokuVariant variant = SudokuVariant.mini,
  SudokuDifficulty difficulty = SudokuDifficulty.gentle,
  SudokuPuzzle? puzzle,
  double width = 400,
  double textScale = 1,
}) async {
  final SudokuPuzzle fixed = puzzle ?? fixedPuzzle(variant);
  await setPhoneSurface(tester, width: width);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sudokuPuzzleSourceProvider.overrideWithValue(
          (SudokuSpec spec, SudokuDifficulty tier, int seed) async => fixed,
        ),
      ],
      child: MaterialApp(
        theme: buildNookTheme(NookColors.softClay),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: SudokuGamePage(variant: variant, difficulty: difficulty),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
