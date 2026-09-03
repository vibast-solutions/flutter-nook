import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/chrome/continue_card.dart';
import 'package:nook/chrome/move_history.dart';
import 'package:nook/games/stars/stars_save.dart';
import 'package:nook/games/stars/stars_state.dart';
import 'package:nook/games/stars/stars_variant.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/stars_fixture.dart';

/// Taps the control with this [id] in the row under the board.
Future<void> tapAction(WidgetTester tester, String id) async {
  final Finder tile = find.byKey(BoardActionRow.keyFor(id));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pump();
}

/// Sends the app to the background, and optionally brings it back.
Future<void> background(WidgetTester tester, {bool andReturn = false}) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
  if (andReturn) {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
  }
}

/// The first cell that holds no star in [puzzle]'s solution.
///
/// A dot here can be laid down and cleared without touching the answer, and
/// leaving it on the board never blocks a solve, since a dot is not a star.
int nonSolutionCell(StarsPuzzle puzzle) {
  for (int index = 0; index < puzzle.spec.cellCount; index++) {
    if (!puzzle.solution.contains(index)) {
      return index;
    }
  }
  throw StateError('every cell is a star, which no Stars board is');
}

/// A minimal saved Sudoku Mini, valid enough for the home screen to offer it.
///
/// Built by hand rather than through the sudoku fixture, which would clash with
/// this one on half a dozen shared names. A sudoku save is a save with no region
/// map — that is the whole of what tells the two games apart on the way in.
SavedGame sudokuSaveRow({DateTime? updatedAt}) {
  return SavedGame(
    gameId: 'sudoku-mini',
    difficulty: PuzzleDifficulty.gentle.name,
    seed: 4242,
    givens: const <int>[1, 0, 0, 4, 0, 0, 1, 0, 0, 1, 0, 0, 4, 0, 0, 1],
    solution: const <int>[1, 2, 3, 4, 3, 4, 1, 2, 2, 1, 4, 3, 4, 3, 2, 1],
    cells: const <int>[1, 2, 0, 4, 0, 0, 1, 0, 0, 1, 0, 0, 4, 0, 0, 1],
    notes: const <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    history: const MoveHistory.empty(),
    elapsed: const Duration(seconds: 20),
    updatedAt: updatedAt ?? DateTime.utc(2026, 9, 3, 9),
  );
}

void main() {
  group('a Stars puzzle in progress is on disk', () {
    testWidgets('with its marks, its history, its tier and its seed', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpStarsGame(tester, database: database);

      // A star at cell 0 (two taps) and a ruled-out dot at cell 1.
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 1);
      await tester.pump();

      final SavedGame? save = await storedSave(
        tester,
        database,
        StarsVariant.starsId,
      );
      expect(save, isNotNull);
      expect(save!.cells[0], StarsMark.star.index);
      expect(save.cells[1], StarsMark.ruledOut.index);
      // The region map is the puzzle, and it goes to disk in full.
      expect(save.regions, fixedStarsPuzzle().regions);
      expect(save.solution, fixedStarsPuzzle().solution);
      expect(save.givens, isEmpty);
      // One move per tap, each separately undoable and each written down.
      expect(save.history.moves, hasLength(3));
      expect(save.difficulty, PuzzleDifficulty.gentle.name);
      expect(save.seed, fixedStarsPuzzle().seed);
    });

    testWidgets('with the time it has actually been played for', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await pumpStarsGame(tester, database: database, clock: clock);

      await tapStarsCell(tester, 0);
      clock.advance(const Duration(minutes: 2, seconds: 5));
      await background(tester);

      final SavedGame save = (await storedSave(
        tester,
        database,
        StarsVariant.starsId,
      ))!;
      expect(save.elapsed, const Duration(minutes: 2, seconds: 5));
    });

    testWidgets('until it is solved, and then not at all', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final StarsPuzzle puzzle = fixedStarsPuzzle();
      await pumpStarsGame(tester, puzzle: puzzle, database: database);

      // A dot on a cell the solution leaves empty, so it makes a save without
      // getting in the way of solving the board.
      await tapStarsCell(tester, nonSolutionCell(puzzle));
      expect(
        await storedSave(tester, database, StarsVariant.starsId),
        isNotNull,
      );

      await solveStars(tester, puzzle);
      expect(find.text(en.gameSolved), findsOneWidget);
      expect(
        await storedSave(tester, database, StarsVariant.starsId),
        isNull,
        reason: 'a solved puzzle is a result, not something to come back to',
      );
    });
  });

  group('coming back to a Stars puzzle', () {
    testWidgets('brings the marks, the moves and the clock back', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database).save(partPlayedStarsSave());
      final StarsSave resume = StarsSave.read(
        (await storedSave(tester, database, StarsVariant.starsId))!,
      )!;

      await pumpStarsGame(tester, resume: resume, database: database);

      expect(starMarkAt(tester, 0), StarsMark.star);
      expect(starMarkAt(tester, 1), StarsMark.ruledOut);
      expect(starMarkAt(tester, 2), StarsMark.ruledOut);
      expect(find.text('01:15'), findsOneWidget);

      // The undo history came back too: the last dot can still be taken back,
      // which is the part of a save nothing else on screen would show.
      await tapAction(tester, 'undo');
      expect(starMarkAt(tester, 2), StarsMark.empty);
      await tapAction(tester, 'undo');
      expect(starMarkAt(tester, 1), StarsMark.empty);
    });

    testWidgets('carries the clock on from where it stopped', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await SavedGameStore(database).save(partPlayedStarsSave());
      final StarsSave resume = StarsSave.read(
        (await storedSave(tester, database, StarsVariant.starsId))!,
      )!;

      await pumpStarsGame(
        tester,
        resume: resume,
        database: database,
        clock: clock,
      );

      expect(find.text('01:15'), findsOneWidget);
      clock.advance(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:35'), findsOneWidget);
    });

    testWidgets('undoes a Clear marks made before the app was closed', (
      WidgetTester tester,
    ) async {
      // The strongest thing a save carries: a move that touched cells it did not
      // name. Clear marks wipes every dot at once, and undoing it after a resume
      // has to bring all of them back — which only works if the move's swept
      // cells rode to disk with it.
      final NookDatabase database = memoryDatabase();
      await pumpStarsGame(tester, database: database);

      // A star and two dots, then wipe the dots in one move.
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 0);
      await tapStarsCell(tester, 1);
      await tapStarsCell(tester, 2);
      await tapAction(tester, 'clear-marks');
      expect(starMarkAt(tester, 1), StarsMark.empty);
      expect(starMarkAt(tester, 2), StarsMark.empty);

      final StarsSave resume = StarsSave.read(
        (await storedSave(tester, database, StarsVariant.starsId))!,
      )!;
      await pumpStarsGame(tester, resume: resume, database: database);

      // The board comes back cleared, and one undo brings both dots back at
      // once — across the resume, exactly as if the app had never closed.
      expect(starMarkAt(tester, 1), StarsMark.empty);
      expect(starMarkAt(tester, 2), StarsMark.empty);
      expect(starMarkAt(tester, 0), StarsMark.star);
      await tapAction(tester, 'undo');
      expect(starMarkAt(tester, 1), StarsMark.ruledOut);
      expect(starMarkAt(tester, 2), StarsMark.ruledOut);
    });

    testWidgets('does not hand the same puzzle back for a new one', (
      WidgetTester tester,
    ) async {
      // Resuming and then asking for a new puzzle has to generate: the screen
      // was opened with a saved game, and a rebuild that read it again would
      // put the player straight back into the one they just finished with.
      final NookDatabase database = memoryDatabase();
      final StarsPuzzle puzzle = fixedStarsPuzzle();
      final int dot = nonSolutionCell(puzzle);
      final StarsGameState marked = StarsGameState(
        variant: StarsVariant.standard,
        puzzle: puzzle,
        cells: List<StarsMark>.filled(puzzle.spec.cellCount, StarsMark.empty)
          ..[dot] = StarsMark.ruledOut,
        history: MoveHistory(
          moves: <BoardMove>[BoardMove(index: dot, before: 0, after: 1)],
        ),
      );
      final StarsSave resume = StarsSave.read(
        savedStarsGame(
          marked,
          difficulty: PuzzleDifficulty.gentle,
          elapsed: const Duration(seconds: 30),
          at: DateTime.utc(2026, 9, 3, 9),
        ),
      )!;
      await pumpStarsGame(tester, resume: resume, database: database);
      expect(starMarkAt(tester, dot), StarsMark.ruledOut);

      await solveStars(tester, puzzle);
      expect(find.text(en.gameSolved), findsOneWidget);
      await tester.tap(find.text(en.completionAnother(en.difficultyGentle)));
      await tester.pumpAndSettle();

      expect(
        starMarkAt(tester, dot),
        StarsMark.empty,
        reason: 'the new puzzle came back with the old marks in it',
      );
    });
  });

  group('a Stars save and a Sudoku save on the home screen', () {
    testWidgets('the Continue card offers the more recent, and it is Stars', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database)
          .save(sudokuSaveRow(updatedAt: DateTime.utc(2026, 9, 3, 8)));
      await SavedGameStore(database)
          .save(partPlayedStarsSave(at: DateTime.utc(2026, 9, 3, 9)));

      await pumpStarsHome(tester, database: database);

      expect(find.byKey(ContinueCard.cardKey), findsOneWidget);
      await tester.tap(find.byKey(ContinueCard.cardKey));
      await tester.pumpAndSettle();

      expect(
        find.byType(StarsBoard),
        findsOneWidget,
        reason: 'the more recent save was the Stars one',
      );
      expect(find.byType(SudokuBoard), findsNothing);
    });

    testWidgets('and resumes into Sudoku when that is the more recent', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database)
          .save(partPlayedStarsSave(at: DateTime.utc(2026, 9, 3, 8)));
      await SavedGameStore(database)
          .save(sudokuSaveRow(updatedAt: DateTime.utc(2026, 9, 3, 9)));

      await pumpStarsHome(tester, database: database);

      await tester.tap(find.byKey(ContinueCard.cardKey));
      await tester.pumpAndSettle();

      expect(find.byType(SudokuBoard), findsOneWidget);
      expect(find.byType(StarsBoard), findsNothing);
    });
  });
}
