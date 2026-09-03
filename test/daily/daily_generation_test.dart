import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/daily/daily_launch.dart';
import 'package:nook/daily/daily_puzzle.dart';
import 'package:nook/games/duo/duo_controller.dart';
import 'package:nook/games/stars/stars_controller.dart';
import 'package:nook/games/sudoku/sudoku_controller.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// The daily must serve exactly the board its date names — the one
/// `generateAt(tier, seed)` produces — which is only true if the pack-first
/// source the app root wires in never gets between the daily and the plain
/// generator. Both halves are pinned here: the daily sources *are* the plain
/// generators whatever the root says, and the plain generators produce the
/// same board as a direct `generateAt` call.
void main() {
  test('the daily sources stay the plain generators under the pack wiring', () {
    // A root configured the way main.dart configures it: the ordinary sources
    // replaced. The daily's own must not budge.
    Future<SudokuPuzzle> packSudoku(
      SudokuSpec spec,
      PuzzleDifficulty tier,
      int seed,
    ) => throw StateError('the pack source must never serve the daily');
    Future<StarsPuzzle> packStars(
      StarsSpec spec,
      PuzzleDifficulty tier,
      int seed,
    ) => throw StateError('the pack source must never serve the daily');
    final ProviderContainer container = ProviderContainer(
      overrides: [
        sudokuPuzzleSourceProvider.overrideWithValue(packSudoku),
        starsPuzzleSourceProvider.overrideWithValue(packStars),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(dailySudokuSourceProvider),
      same(generateSudokuOffThread),
    );
    expect(
      container.read(dailyStarsSourceProvider),
      same(generateStarsOffThread),
    );
    expect(container.read(dailyDuoSourceProvider), same(generateDuoOffThread));
  });

  // Three gentle Mondays, one per game in the rotation, so the equality is
  // checked at the identity the daily would really use — and generation stays
  // quick, gentle being the tier that is never packed.

  test('a daily Stars board is the one generateAt names', () async {
    final DailyPuzzle daily = dailyPuzzleFor(DateTime(2026, 9, 14));
    expect(daily.game, DailyGame.stars);
    expect(daily.difficulty, PuzzleDifficulty.gentle);

    final StarsPuzzle direct = StarsGenerator(StarsSpec.standard)
        .generateAt(daily.difficulty, daily.seed);
    final StarsPuzzle served = await generateStarsOffThread(
      StarsSpec.standard,
      daily.difficulty,
      daily.seed,
    );
    expect(served.regions, direct.regions);
    expect(served.solution, direct.solution);
  });

  test('a daily Duo board is the one generateAt names', () async {
    final DailyPuzzle daily = dailyPuzzleFor(DateTime(2026, 9, 21));
    expect(daily.game, DailyGame.duo);
    expect(daily.difficulty, PuzzleDifficulty.gentle);

    final DuoPuzzle direct = DuoGenerator(DuoSpec.standard)
        .generateAt(daily.difficulty, daily.seed);
    final DuoPuzzle served = await generateDuoOffThread(
      DuoSpec.standard,
      daily.difficulty,
      daily.seed,
    );
    expect(served.givens, direct.givens);
    expect(served.badges, direct.badges);
    expect(served.solution, direct.solution);
  });

  test('a daily Sudoku board is the one generateAt names', () async {
    final DailyPuzzle daily = dailyPuzzleFor(DateTime(2026, 9, 28));
    expect(daily.game, DailyGame.sudokuClassic);
    expect(daily.difficulty, PuzzleDifficulty.gentle);

    final SudokuPuzzle direct = SudokuGenerator(SudokuSpec.classic)
        .generateAt(daily.difficulty, daily.seed);
    final SudokuPuzzle served = await generateSudokuOffThread(
      SudokuSpec.classic,
      daily.difficulty,
      daily.seed,
    );
    expect(served.givens, direct.givens);
    expect(served.solution, direct.solution);
  });
}
