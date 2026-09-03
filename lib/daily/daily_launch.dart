import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../chrome/game_providers.dart';
import '../games/duo/duo_controller.dart';
import '../games/duo/duo_save.dart';
import '../games/duo/duo_screen.dart';
import '../games/duo/duo_variant.dart';
import '../games/stars/stars_controller.dart';
import '../games/stars/stars_save.dart';
import '../games/stars/stars_screen.dart';
import '../games/stars/stars_variant.dart';
import '../games/sudoku/sudoku_controller.dart';
import '../games/sudoku/sudoku_save.dart';
import '../games/sudoku/sudoku_screen.dart';
import '../games/sudoku/sudoku_variant.dart';
import '../store/saved_game.dart';
import 'daily_puzzle.dart';

/// The saved-game slot the daily lives in.
///
/// Its own row rather than the game's: a player halfway through an ordinary
/// Duo must be able to play a Duo daily without either puzzle discarding the
/// other. The row's payload is an ordinary save of whichever game the day
/// landed on; its date rides in the seed.
const String dailySlotId = 'daily';

/// Where the daily's Sudoku comes from: always the plain generator, never the
/// pack-first source the app root wires in.
///
/// The packs are random pre-generated stock — handing the next one out would
/// give every player a different "today's puzzle" and break the one promise
/// the daily makes. A provider of its own so tests can inject a fixed puzzle
/// without touching the ordinary source.
final Provider<SudokuPuzzleSource> dailySudokuSourceProvider =
    Provider<SudokuPuzzleSource>(
      (Ref ref) => generateSudokuOffThread,
      name: 'dailySudokuSource',
    );

/// Where the daily's Stars comes from. See [dailySudokuSourceProvider].
final Provider<StarsPuzzleSource> dailyStarsSourceProvider =
    Provider<StarsPuzzleSource>(
      (Ref ref) => generateStarsOffThread,
      name: 'dailyStarsSource',
    );

/// Where the daily's Duo comes from. See [dailySudokuSourceProvider].
final Provider<DuoPuzzleSource> dailyDuoSourceProvider =
    Provider<DuoPuzzleSource>(
      (Ref ref) => generateDuoOffThread,
      name: 'dailyDuoSource',
    );

/// The route into today's puzzle, started fresh.
///
/// The identity in [daily] is captured here, so the puzzle is pinned the
/// moment it is opened: crossing midnight mid-solve never swaps the board.
Route<void> dailyStartRoute(WidgetRef ref, DailyPuzzle daily) {
  return switch (daily.game) {
    DailyGame.sudokuClassic => _sudokuRoute(
      ref.read(dailySudokuSourceProvider),
      daily,
      null,
    ),
    DailyGame.stars => _starsRoute(
      ref.read(dailyStarsSourceProvider),
      daily,
      null,
    ),
    DailyGame.duo => _duoRoute(ref.read(dailyDuoSourceProvider), daily, null),
  };
}

/// A daily save resolved to what the card needs and how to reopen it.
///
/// The daily's small cousin of the Continue card's `ResumableGame`: the store
/// hands back a game-agnostic row, and this is it read as [DailyPuzzle]'s own
/// game, ready to be resumed exactly as it was left.
@immutable
class DailyResume {
  const DailyResume({
    required this.elapsed,
    required this.progress,
    required this.route,
  });

  /// How long today's puzzle has been played for.
  final Duration elapsed;

  /// How far along it is, from 0 to 1, by the game's own measure.
  final double progress;

  /// A route back into the puzzle, built when the card is tapped.
  final Route<void> Function() route;
}

/// Reads [save] as today's puzzle in progress, or `null` if it is not that.
///
/// Not that covers a lot, deliberately: a row in another slot, a daily from an
/// earlier date (the seed is the date), and a payload this build cannot read
/// back as the game today's rotation names. Each of those means the card
/// offers a fresh start instead of a resume it could not honour.
DailyResume? dailyResume(WidgetRef ref, DailyPuzzle daily, SavedGame save) {
  if (save.gameId != dailySlotId || save.seed != daily.seed) {
    return null;
  }
  switch (daily.game) {
    case DailyGame.sudokuClassic:
      final SudokuSave? read = SudokuSave.readAs(save, SudokuVariant.classic);
      if (read == null) {
        return null;
      }
      return DailyResume(
        elapsed: read.elapsed,
        progress: read.progress,
        route: () =>
            _sudokuRoute(ref.read(dailySudokuSourceProvider), daily, read),
      );
    case DailyGame.stars:
      final StarsSave? read = StarsSave.readAs(save, StarsVariant.standard);
      if (read == null) {
        return null;
      }
      return DailyResume(
        elapsed: read.elapsed,
        progress: read.progress,
        route: () =>
            _starsRoute(ref.read(dailyStarsSourceProvider), daily, read),
      );
    case DailyGame.duo:
      final DuoSave? read = DuoSave.readAs(save, DuoVariant.standard);
      if (read == null) {
        return null;
      }
      return DailyResume(
        elapsed: read.elapsed,
        progress: read.progress,
        route: () => _duoRoute(ref.read(dailyDuoSourceProvider), daily, read),
      );
  }
}

// Each route below opens the game's ordinary page inside a scope that makes it
// the daily: the puzzle source is the plain generator handed in, the seed is
// pinned to the date's, the save goes to the daily slot, and "another puzzle"
// jumps to an ordinary game — regenerating in place would deal today's puzzle
// twice. The game id is left alone on purpose, so the solve lands in the
// game's normal statistics row.
//
// A resumed daily keeps the tier its save was started at, even if the ramp has
// moved between versions: resuming means exactly the puzzle that was left.

Route<void> _sudokuRoute(
  SudokuPuzzleSource source,
  DailyPuzzle daily,
  SudokuSave? resume,
) {
  final PuzzleDifficulty tier = resume?.difficulty ?? daily.difficulty;
  return MaterialPageRoute<void>(
    builder: (BuildContext context) => ProviderScope(
      overrides: [
        sudokuPuzzleSourceProvider.overrideWithValue(source),
        sudokuSeedSourceProvider.overrideWithValue(() => daily.seed),
        saveSlotProvider.overrideWithValue(dailySlotId),
        completionAnotherProvider.overrideWithValue(
          () => Navigator.of(
            context,
          ).pushReplacement(SudokuGamePage.route(SudokuVariant.classic, tier)),
        ),
      ],
      child: SudokuGamePage(
        variant: SudokuVariant.classic,
        difficulty: tier,
        resume: resume,
      ),
    ),
  );
}

Route<void> _starsRoute(
  StarsPuzzleSource source,
  DailyPuzzle daily,
  StarsSave? resume,
) {
  final PuzzleDifficulty tier = resume?.difficulty ?? daily.difficulty;
  return MaterialPageRoute<void>(
    builder: (BuildContext context) => ProviderScope(
      overrides: [
        starsPuzzleSourceProvider.overrideWithValue(source),
        starsSeedSourceProvider.overrideWithValue(() => daily.seed),
        saveSlotProvider.overrideWithValue(dailySlotId),
        completionAnotherProvider.overrideWithValue(
          () => Navigator.of(
            context,
          ).pushReplacement(StarsGamePage.route(StarsVariant.standard, tier)),
        ),
      ],
      child: StarsGamePage(
        variant: StarsVariant.standard,
        difficulty: tier,
        resume: resume,
      ),
    ),
  );
}

Route<void> _duoRoute(
  DuoPuzzleSource source,
  DailyPuzzle daily,
  DuoSave? resume,
) {
  final PuzzleDifficulty tier = resume?.difficulty ?? daily.difficulty;
  return MaterialPageRoute<void>(
    builder: (BuildContext context) => ProviderScope(
      overrides: [
        duoPuzzleSourceProvider.overrideWithValue(source),
        duoSeedSourceProvider.overrideWithValue(() => daily.seed),
        saveSlotProvider.overrideWithValue(dailySlotId),
        completionAnotherProvider.overrideWithValue(
          () => Navigator.of(context)
              .pushReplacement(DuoGamePage.route(DuoVariant.standard, tier)),
        ),
      ],
      child: DuoGamePage(
        variant: DuoVariant.standard,
        difficulty: tier,
        resume: resume,
      ),
    ),
  );
}
