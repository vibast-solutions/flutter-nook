import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/daily/daily_card.dart';
import 'package:nook/daily/daily_launch.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/sudoku/sudoku_controller.dart';
import 'package:nook/games/sudoku/sudoku_naming.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:nook/home/home_screen.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

/// The daily on a Sudoku day — Tuesday 2026-09-01, an easy Sudoku Classic.
///
/// The rules the games share are exercised on Duo in `daily_card_test.dart`;
/// this checks what is Sudoku's own: the wiring that opens *this* game from
/// the card, from the daily source and never the ordinary one, saving into
/// the daily slot.
void main() {
  testWidgets('a Sudoku day opens Sudoku Classic from the daily source', (
    WidgetTester tester,
  ) async {
    final NookDatabase database = memoryDatabase();
    final SudokuPuzzle puzzle = fixedPuzzle(SudokuVariant.classic);
    await setPhoneSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dailySudokuSourceProvider.overrideWithValue(
            (SudokuSpec spec, PuzzleDifficulty tier, int seed) async => puzzle,
          ),
          // The ordinary source — the pack-first one in the real app — must
          // never be asked for the daily, so asking it is the test failing.
          sudokuPuzzleSourceProvider.overrideWithValue(
            (SudokuSpec spec, PuzzleDifficulty tier, int seed) =>
                throw StateError('the daily must not use the ordinary source'),
          ),
          nookDatabaseProvider.overrideWithValue(database),
          nowProvider.overrideWithValue(
            TestClock(DateTime.utc(2026, 9, 1, 9)).call,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildNookTheme(NookColors.softClay),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The card names the day's game and the ramp's tier for a Tuesday.
    expect(
      find.text(en.dailyDetails(DateTime.utc(2026, 9, 1), en.difficultyEasy)),
      findsOneWidget,
    );

    await tester.tap(find.byKey(dailyCardKey));
    await tester.pumpAndSettle();

    expect(find.byType(SudokuBoard), findsOneWidget);
    expect(
      find.text(
        en.gameSubtitle(SudokuVariant.classic.sizeLabel(en), en.difficultyEasy),
      ),
      findsOneWidget,
    );

    // Opening it writes the in-progress board to the daily slot, and Sudoku
    // Classic's own slot stays untouched.
    final SavedGame? daily = await storedSave(tester, database, dailySlotId);
    expect(daily, isNotNull);
    expect(await storedSave(tester, database, SudokuVariant.classicId), isNull);
  });
}
