import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/chrome/continue_card.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/chrome/note_marks.dart';
import 'package:nook/games/sudoku/sudoku_save.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/sudoku_fixture.dart';

/// Sends the app to the background, and optionally brings it back.
Future<void> background(WidgetTester tester, {bool andReturn = false}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  if (andReturn) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }
}

/// Plays the two moves [partPlayedMiniSave] describes, on a live board.
Future<void> playTwoMoves(WidgetTester tester) async {
  await tapCell(tester, 0);
  await tapDigit(tester, 1);
  await tapAction(tester, 'notes');
  await tapCell(tester, 4);
  for (final int digit in pencilledMarks.digits) {
    await tapDigit(tester, digit);
  }
}

void main() {
  group('a puzzle in progress is on disk', () {
    testWidgets('before anything is closed or backed out of', (
      WidgetTester tester,
    ) async {
      // The app can be killed by the operating system without being told, so
      // there is no moment at which it is safe to be the only copy of a
      // puzzle. This asserts the save exists while the board is still on
      // screen and nothing has been disposed.
      final NookDatabase database = memoryDatabase();
      await pumpSudokuGame(
        tester,
        puzzle: fixedMiniPuzzle(),
        database: database,
      );

      await playTwoMoves(tester);
      await tester.pump();

      final SavedGame? save = await storedSave(
        tester,
        database,
        SudokuVariant.miniId,
      );
      expect(save, isNotNull);
      expect(save!.cells[0], 1);
      expect(NoteMarks(save.notes[4]).digits, pencilledMarks.digits);
      // One move for the answer and one per pencil mark: each is separately
      // undoable, and each has to survive being written down.
      expect(save.history.moves, hasLength(1 + pencilledMarks.digits.length));
      expect(save.difficulty, PuzzleDifficulty.gentle.name);
      expect(save.seed, fixedMiniPuzzle().seed);
      expect(save.notesMode, isTrue);
    });

    testWidgets('with the time it has actually been played for', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await pumpSudokuGame(
        tester,
        puzzle: fixedMiniPuzzle(),
        database: database,
        clock: clock,
      );

      await tapCell(tester, 0);
      await tapDigit(tester, 1);
      clock.advance(const Duration(minutes: 1, seconds: 30));
      // Leaving the app writes what the clock has counted since the last move.
      await background(tester);

      final SavedGame save = (await storedSave(
        tester,
        database,
        SudokuVariant.miniId,
      ))!;
      expect(save.elapsed, const Duration(minutes: 1, seconds: 30));
    });

    testWidgets('until it is solved, and then not at all', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final SudokuPuzzle puzzle = fixedMiniPuzzle();
      await pumpSudokuGame(tester, puzzle: puzzle, database: database);

      await tapCell(tester, 0);
      await tapDigit(tester, puzzle.solution[0]);
      expect(
        await storedSave(tester, database, SudokuVariant.miniId),
        isNotNull,
      );

      for (int i = 1; i < puzzle.givens.length; i++) {
        if (puzzle.givens[i] == 0) {
          await tapCell(tester, i);
          await tapDigit(tester, puzzle.solution[i]);
        }
      }
      await tester.pumpAndSettle();

      expect(find.text(en.gameSolved), findsOneWidget);
      expect(
        await storedSave(tester, database, SudokuVariant.miniId),
        isNull,
        reason: 'a solved puzzle is a result, not something to come back to',
      );
    });
  });

  group('coming back to a puzzle', () {
    testWidgets('brings the board, the notes, the moves and the clock back', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database).save(partPlayedMiniSave());

      // A cold launch: the app is built again over the database it left.
      await pumpHome(tester, database: database);
      await tester.tap(find.byKey(ContinueCard.cardKey));
      await tester.pumpAndSettle();

      expect(digitIn(tester, 0), '1');
      expect(notesIn(tester, 4), pencilledMarks.digits);
      expect(find.text('01:30'), findsOneWidget);

      // The undo history came back too, so the last move can still be taken
      // back — which is the part of a save nothing else on screen would show.
      await tapAction(tester, 'undo');
      expect(notesIn(tester, 4), isEmpty);
      await tapAction(tester, 'undo');
      expect(digitIn(tester, 0), isNull);
    });

    testWidgets('carries the clock on from where it stopped', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await SavedGameStore(database).save(partPlayedMiniSave());
      final SudokuSave resume = SudokuSave.read(
        (await storedSave(tester, database, SudokuVariant.miniId))!,
      )!;

      await pumpSudokuGame(
        tester,
        puzzle: fixedMiniPuzzle(),
        database: database,
        clock: clock,
        resume: resume,
      );

      expect(find.text('01:30'), findsOneWidget);
      clock.advance(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:50'), findsOneWidget);
    });

    testWidgets('does not hand the same puzzle back for a new one', (
      WidgetTester tester,
    ) async {
      // Resuming and then asking for a new puzzle has to generate: the screen
      // was opened with a saved game, and a rebuild that read it again would
      // put the player straight back into the one they just finished with.
      final NookDatabase database = memoryDatabase();
      final SudokuPuzzle puzzle = fixedMiniPuzzle();
      final SudokuSave resume = SudokuSave.read(partPlayedMiniSave())!;
      await pumpSudokuGame(
        tester,
        puzzle: puzzle,
        database: database,
        resume: resume,
      );
      expect(digitIn(tester, 0), '1');

      for (int i = 0; i < puzzle.givens.length; i++) {
        if (puzzle.givens[i] == 0 && digitIn(tester, i) == null) {
          await tapCell(tester, i);
          await tapDigit(tester, puzzle.solution[i]);
        }
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.completionAnother(en.difficultyGentle)));
      await tester.pumpAndSettle();

      expect(
        digitIn(tester, 0),
        isNull,
        reason: 'the new puzzle came back with the old answers in it',
      );
    });
  });

  group('the clock on the screen', () {
    testWidgets('counts while the puzzle is in front of the player', (
      WidgetTester tester,
    ) async {
      final TestClock clock = TestClock();
      await pumpSudokuGame(
        tester,
        puzzle: fixedMiniPuzzle(),
        database: memoryDatabase(),
        clock: clock,
      );

      expect(find.text('00:00'), findsOneWidget);
      clock.advance(const Duration(seconds: 10));
      await tester.pump(PlayClock.tick);
      expect(find.text('00:10'), findsOneWidget);
    });

    testWidgets('stops while the app is in the background', (
      WidgetTester tester,
    ) async {
      final TestClock clock = TestClock();
      await pumpSudokuGame(
        tester,
        puzzle: fixedMiniPuzzle(),
        database: memoryDatabase(),
        clock: clock,
      );
      clock.advance(const Duration(seconds: 10));
      await tester.pump(PlayClock.tick);

      // Away for an hour, back to the second it was left on.
      await background(tester);
      clock.advance(const Duration(hours: 1));
      await background(tester, andReturn: true);
      await tester.pump(PlayClock.tick);
      expect(find.text('00:10'), findsOneWidget);

      // And counting again now the player is back.
      clock.advance(const Duration(seconds: 5));
      await tester.pump(PlayClock.tick);
      expect(find.text('00:15'), findsOneWidget);
    });

    testWidgets('stops on the time the puzzle was solved in', (
      WidgetTester tester,
    ) async {
      final TestClock clock = TestClock();
      final SudokuPuzzle puzzle = fixedMiniPuzzle();
      await pumpSudokuGame(
        tester,
        puzzle: puzzle,
        database: memoryDatabase(),
        clock: clock,
      );

      clock.advance(const Duration(seconds: 20));
      for (int i = 0; i < puzzle.givens.length; i++) {
        if (puzzle.givens[i] == 0) {
          await tapCell(tester, i);
          await tapDigit(tester, puzzle.solution[i]);
        }
      }
      await tester.pumpAndSettle();
      expect(find.text(en.gameSolved), findsOneWidget);

      clock.advance(const Duration(minutes: 5));
      await tester.pump(PlayClock.tick);
      expect(
        find.text('00:20'),
        findsOneWidget,
        reason: 'the clock kept running after the puzzle was finished',
      );
    });
  });

  group('a save this build cannot read', () {
    test('is ignored rather than opened', () {
      final SavedGame written = partPlayedMiniSave();
      SavedGame withGameId(String gameId) => SavedGame(
        gameId: gameId,
        difficulty: written.difficulty,
        seed: written.seed,
        givens: written.givens,
        solution: written.solution,
        cells: written.cells,
        notes: written.notes,
        history: written.history,
        elapsed: written.elapsed,
        updatedAt: written.updatedAt,
      );

      expect(SudokuSave.read(withGameId(SudokuVariant.miniId)), isNotNull);
      expect(
        SudokuSave.read(withGameId('sudoku-enormous')),
        isNull,
        reason: 'a game this build does not have is not a Sudoku it can open',
      );
    });

    test('is ignored when its tier no longer exists', () {
      final SavedGame written = partPlayedMiniSave();
      expect(
        SudokuSave.read(
          SavedGame(
            gameId: written.gameId,
            difficulty: 'impossible',
            seed: written.seed,
            givens: written.givens,
            solution: written.solution,
            cells: written.cells,
            notes: written.notes,
            history: written.history,
            elapsed: written.elapsed,
            updatedAt: written.updatedAt,
          ),
        ),
        isNull,
      );
    });

    test('is ignored when its grid is the wrong size', () {
      final SavedGame written = partPlayedMiniSave();
      expect(
        SudokuSave.read(
          SavedGame(
            gameId: SudokuVariant.classicId,
            difficulty: written.difficulty,
            seed: written.seed,
            givens: written.givens,
            solution: written.solution,
            cells: written.cells,
            notes: written.notes,
            history: written.history,
            elapsed: written.elapsed,
            updatedAt: written.updatedAt,
          ),
        ),
        isNull,
        reason: 'sixteen cells are not a 9x9, whatever the row says',
      );
    });
  });
}
