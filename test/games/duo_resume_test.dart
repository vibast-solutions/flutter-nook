import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/duo_board.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/chrome/continue_card.dart';
import 'package:nook/chrome/difficulty_page.dart';
import 'package:nook/chrome/discard_dialog.dart';
import 'package:nook/chrome/move_history.dart';
import 'package:nook/games/duo/duo_save.dart';
import 'package:nook/games/duo/duo_state.dart';
import 'package:nook/games/duo/duo_variant.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/duo_fixture.dart';

/// Taps the control with this [id] in the row under the board.
Future<void> tapAction(WidgetTester tester, String id) async {
  final Finder tile = find.byKey(BoardActionRow.keyFor(id));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pump();
}

/// Sends the app to the background.
Future<void> background(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  await tester.pump();
}

/// The first two cells of the fixed puzzle the player gets to fill.
List<int> freeCells(DuoPuzzle puzzle) => <int>[
  for (int index = 0; index < puzzle.spec.cellCount; index++)
    if (!puzzle.isGiven(index)) index,
];

/// A minimal saved Sudoku Mini, valid enough for the home screen to offer it.
///
/// Built by hand rather than through the sudoku fixture, which would clash with
/// this one on half a dozen shared names. A sudoku save is a save with no
/// region map and no badges — that is the whole of what tells the games apart
/// on the way in.
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

/// A minimal saved Stars puzzle, valid enough for the home screen to offer it.
///
/// A Stars save is the one that carries a region map: one region index per cell
/// of the 8x8, a mark per cell, and no givens. The map is a banded one — a
/// region per pair of columns and half — which is not a playable puzzle, but a
/// reader checks shape, not quality.
SavedGame starsSaveRow({DateTime? updatedAt}) {
  const int size = 8;
  return SavedGame(
    gameId: 'stars',
    difficulty: PuzzleDifficulty.gentle.name,
    seed: 99,
    givens: const <int>[],
    solution: <int>[for (int i = 0; i < size; i++) i * size],
    cells: List<int>.filled(size * size, 0)..[0] = 2,
    notes: const <int>[],
    regions: <int>[
      for (int i = 0; i < size * size; i++)
        (i % size) ~/ 2 + (i ~/ (size * 4)) * 4,
    ],
    history: const MoveHistory.empty(),
    elapsed: const Duration(seconds: 30),
    updatedAt: updatedAt ?? DateTime.utc(2026, 9, 3, 9),
  );
}

void main() {
  final DuoPuzzle puzzle = fixedDuoPuzzle();
  final List<int> free = freeCells(puzzle);

  group('a Duo puzzle in progress is on disk', () {
    testWidgets('with its symbols, its badges, its history and its seed', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpDuoGame(tester, database: database);

      // A circle on the first free cell (one tap) and a square on the second
      // (two taps).
      await tapDuoCell(tester, free[0]);
      await tapDuoCell(tester, free[1]);
      await tapDuoCell(tester, free[1]);
      await tester.pump();

      final SavedGame? save = await storedSave(
        tester,
        database,
        DuoVariant.duoId,
      );
      expect(save, isNotNull);
      expect(save!.cells[free[0]], DuoCell.circle.index);
      expect(save.cells[free[1]], DuoCell.square.index);
      // The badges are half the puzzle, and they go to disk in full: each one
      // as its edge's two cells and its relation.
      expect(save.badges, <int>[
        for (final DuoBadge badge in puzzle.badges) ...<int>[
          badge.a,
          badge.b,
          badge.relation.index,
        ],
      ]);
      // The givens and the solution ride along too, as symbols by index, so a
      // generator change can never move the entries onto different givens.
      expect(save.givens[free[0]], 0);
      expect(save.solution, <int>[
        for (final DuoSymbol symbol in puzzle.solution)
          DuoCell.of(symbol).index,
      ]);
      // One move per tap, each separately undoable and each written down.
      expect(save.history.moves, hasLength(3));
      expect(save.difficulty, PuzzleDifficulty.gentle.name);
      expect(save.seed, puzzle.seed);
      expect(save.regions, isNull, reason: 'a Duo board has no regions');
    });

    testWidgets('with the time it has actually been played for', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await pumpDuoGame(tester, database: database, clock: clock);

      await tapDuoCell(tester, free[0]);
      clock.advance(const Duration(minutes: 2, seconds: 5));
      await background(tester);

      final SavedGame save = (await storedSave(
        tester,
        database,
        DuoVariant.duoId,
      ))!;
      expect(save.elapsed, const Duration(minutes: 2, seconds: 5));
    });

    testWidgets('until it is solved, and then not at all', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await pumpDuoGame(tester, database: database);

      await tapDuoCell(tester, free[0]);
      expect(await storedSave(tester, database, DuoVariant.duoId), isNotNull);

      await solveDuo(tester, puzzle);
      expect(find.text(en.gameSolved), findsOneWidget);
      expect(
        await storedSave(tester, database, DuoVariant.duoId),
        isNull,
        reason: 'a solved puzzle is a result, not something to come back to',
      );
    });
  });

  group('coming back to a Duo puzzle', () {
    testWidgets('brings the symbols, the moves and the clock back', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database).save(partPlayedDuoSave());
      final DuoSave resume = DuoSave.read(
        (await storedSave(tester, database, DuoVariant.duoId))!,
      )!;

      await pumpDuoGame(tester, resume: resume, database: database);

      expect(duoCellAt(tester, free[0]), DuoCell.circle);
      expect(duoCellAt(tester, free[1]), DuoCell.square);
      expect(find.text('01:15'), findsOneWidget);

      // The undo history came back too: the last cycle can still be taken
      // back, which is the part of a save nothing else on screen would show.
      await tapAction(tester, 'undo');
      expect(duoCellAt(tester, free[1]), DuoCell.circle);
      await tapAction(tester, 'undo');
      expect(duoCellAt(tester, free[1]), DuoCell.empty);
      await tapAction(tester, 'undo');
      expect(duoCellAt(tester, free[0]), DuoCell.empty);
    });

    testWidgets('carries the clock on from where it stopped', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      final TestClock clock = TestClock();
      await SavedGameStore(database).save(partPlayedDuoSave());
      final DuoSave resume = DuoSave.read(
        (await storedSave(tester, database, DuoVariant.duoId))!,
      )!;

      await pumpDuoGame(
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

    testWidgets('does not hand the same puzzle back for a new one', (
      WidgetTester tester,
    ) async {
      // Resuming and then asking for a new puzzle has to generate: the screen
      // was opened with a saved game, and a rebuild that read it again would
      // put the player straight back into the one they just finished with.
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database).save(partPlayedDuoSave());
      final DuoSave resume = DuoSave.read(
        (await storedSave(tester, database, DuoVariant.duoId))!,
      )!;
      await pumpDuoGame(tester, resume: resume, database: database);
      expect(duoCellAt(tester, free[0]), DuoCell.circle);

      await solveDuo(tester, puzzle);
      expect(find.text(en.gameSolved), findsOneWidget);
      await tester.tap(find.text(en.completionAnother(en.difficultyGentle)));
      await tester.pumpAndSettle();

      // The stubbed source hands the same fixed puzzle back, whose free cells
      // start empty — so a symbol here means the resumed board leaked through.
      expect(
        duoCellAt(tester, free[1]),
        DuoCell.empty,
        reason: 'the new puzzle came back with the old symbols in it',
      );
    });
  });

  group('starting over a saved Duo puzzle', () {
    testWidgets('asks first, and keeping the puzzle keeps it', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database).save(partPlayedDuoSave());
      await pumpDuoHome(tester, database: database);
      // The saved game puts a Continue card saying "Duo" on the home screen
      // too, so the game row is reached by its own subtitle.
      await tester.tap(find.text(en.duoSubtitle));
      await tester.pumpAndSettle();

      // The difficulty screen owns up to the puzzle already under way.
      expect(find.byKey(ContinueCard.cardKey), findsOneWidget);

      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.gentle)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(DiscardDialog.confirmKey), findsOneWidget);

      await tester.tap(find.byKey(DiscardDialog.keepKey));
      await tester.pumpAndSettle();

      expect(find.byType(DuoBoard), findsNothing);
      final SavedGame? kept = await storedSave(
        tester,
        database,
        DuoVariant.duoId,
      );
      expect(kept!.history.moves, hasLength(3), reason: 'the save was touched');
    });

    testWidgets('and discards only on confirmation', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database).save(partPlayedDuoSave());
      await pumpDuoHome(tester, database: database);
      // The saved game puts a Continue card saying "Duo" on the home screen
      // too, so the game row is reached by its own subtitle.
      await tester.tap(find.text(en.duoSubtitle));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(DifficultyPage.tierKey(PuzzleDifficulty.gentle)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(DiscardDialog.confirmKey));
      await tester.pumpAndSettle();

      // A fresh board opened, and the save now on disk is the new puzzle's —
      // an untouched one — not the part-played board that was discarded.
      expect(find.byType(DuoBoard), findsOneWidget);
      final SavedGame? now = await storedSave(
        tester,
        database,
        DuoVariant.duoId,
      );
      expect(now?.history.moves ?? const <BoardMove>[], isEmpty);
    });

    testWidgets('the in-progress card resumes instead of asking', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database).save(partPlayedDuoSave());
      await pumpDuoHome(tester, database: database);
      // The saved game puts a Continue card saying "Duo" on the home screen
      // too, so the game row is reached by its own subtitle.
      await tester.tap(find.text(en.duoSubtitle));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ContinueCard.cardKey));
      await tester.pumpAndSettle();

      expect(find.byType(DuoBoard), findsOneWidget);
      expect(duoCellAt(tester, free[0]), DuoCell.circle);
      expect(find.text('01:15'), findsOneWidget);
    });
  });

  group('a Duo save beside the other games on the home screen', () {
    testWidgets('the Continue card offers the most recent, and it is Duo', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database)
          .save(sudokuSaveRow(updatedAt: DateTime.utc(2026, 9, 3, 8)));
      await SavedGameStore(database)
          .save(starsSaveRow(updatedAt: DateTime.utc(2026, 9, 3, 8, 30)));
      await SavedGameStore(database)
          .save(partPlayedDuoSave(at: DateTime.utc(2026, 9, 3, 9)));

      await pumpDuoHome(tester, database: database);

      expect(find.byKey(ContinueCard.cardKey), findsOneWidget);
      await tester.tap(find.byKey(ContinueCard.cardKey));
      await tester.pumpAndSettle();

      expect(
        find.byType(DuoBoard),
        findsOneWidget,
        reason: 'the most recent save was the Duo one',
      );
      expect(find.byType(StarsBoard), findsNothing);
      expect(find.byType(SudokuBoard), findsNothing);
    });

    testWidgets('and resumes into Sudoku when that is the most recent', (
      WidgetTester tester,
    ) async {
      final NookDatabase database = memoryDatabase();
      await SavedGameStore(database)
          .save(partPlayedDuoSave(at: DateTime.utc(2026, 9, 3, 8)));
      await SavedGameStore(database)
          .save(sudokuSaveRow(updatedAt: DateTime.utc(2026, 9, 3, 9)));

      await pumpDuoHome(tester, database: database);

      await tester.tap(find.byKey(ContinueCard.cardKey));
      await tester.pumpAndSettle();

      expect(find.byType(SudokuBoard), findsOneWidget);
      expect(find.byType(DuoBoard), findsNothing);
    });
  });
}
