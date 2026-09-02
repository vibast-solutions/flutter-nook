import 'package:flutter_test/flutter_test.dart';
import 'package:nook/chrome/move_history.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';

/// A save with recognisable values in every field, so a round trip that drops
/// one is a failed expectation rather than a plausible-looking row.
SavedGame sampleSave({
  String gameId = 'sudoku-mini',
  String difficulty = 'gentle',
  Duration elapsed = const Duration(minutes: 3, seconds: 7),
  DateTime? updatedAt,
}) {
  return SavedGame(
    gameId: gameId,
    difficulty: difficulty,
    seed: 4242,
    givens: <int>[1, 0, 0, 4, 0, 0, 1, 0, 0, 1, 0, 0, 4, 0, 0, 1],
    solution: <int>[1, 2, 3, 4, 3, 4, 1, 2, 2, 1, 4, 3, 4, 3, 2, 1],
    cells: <int>[1, 2, 0, 4, 0, 0, 1, 0, 0, 1, 0, 0, 4, 0, 0, 1],
    notes: <int>[0, 0, 6, 0, 0, 0, 0, 0, 0, 0, 12, 0, 0, 0, 0, 0],
    history: MoveHistory(
      moves: const <BoardMove>[
        BoardMove(index: 1, before: 0, after: 2, notesBefore: 3, notesAfter: 0),
        BoardMove(index: 2, before: 0, after: 0, notesBefore: 0, notesAfter: 6),
      ],
    ),
    notesMode: true,
    elapsed: elapsed,
    updatedAt: updatedAt ?? DateTime.utc(2026, 9, 2, 10, 30),
  );
}

void main() {
  late NookDatabase database;
  late SavedGameStore store;

  setUp(() {
    database = NookDatabase.memory();
    store = SavedGameStore(database);
  });

  tearDown(() => database.close());

  test('a save comes back exactly as it went in', () async {
    final SavedGame written = sampleSave();
    await store.save(written);

    final List<SavedGame> saves = await store.watchAll().first;
    expect(saves, hasLength(1));
    final SavedGame read = saves.single;
    expect(read.gameId, written.gameId);
    expect(read.difficulty, written.difficulty);
    expect(read.seed, written.seed);
    expect(read.givens, written.givens);
    expect(read.solution, written.solution);
    expect(read.cells, written.cells);
    expect(read.notes, written.notes);
    expect(read.history.moves, written.history.moves);
    expect(read.notesMode, isTrue);
    expect(read.elapsed, written.elapsed);
    expect(read.updatedAt, written.updatedAt);
  });

  test('a game keeps one save, however often it is written', () async {
    await store.save(sampleSave(elapsed: const Duration(seconds: 5)));
    await store.save(sampleSave(elapsed: const Duration(seconds: 40)));

    final List<SavedGame> saves = await store.watchAll().first;
    expect(saves, hasLength(1));
    expect(saves.single.elapsed, const Duration(seconds: 40));
  });

  test('saves come back most recently played first', () async {
    await store.save(
      sampleSave(gameId: 'sudoku-classic', updatedAt: DateTime.utc(2026, 9, 1)),
    );
    await store.save(
      sampleSave(gameId: 'sudoku-light', updatedAt: DateTime.utc(2026, 9, 2)),
    );

    final List<SavedGame> saves = await store.watchAll().first;
    expect(saves.map((SavedGame save) => save.gameId), <String>[
      'sudoku-light',
      'sudoku-classic',
    ]);
  });

  test('discarding leaves the other games alone', () async {
    await store.save(sampleSave(gameId: 'sudoku-mini'));
    await store.save(sampleSave(gameId: 'sudoku-light'));

    await store.discard('sudoku-mini');

    final List<SavedGame> saves = await store.watchAll().first;
    expect(saves.map((SavedGame save) => save.gameId), <String>[
      'sudoku-light',
    ]);
  });

  test('discarding a game with no save is not an error', () async {
    await expectLater(store.discard('sudoku-classic'), completes);
  });

  test('progress counts the blanks the player has filled', () {
    // Ten blanks in the sample, one of them filled in.
    final SavedGame save = sampleSave();
    expect(save.blanksTotal, 10);
    expect(save.blanksLeft, 9);
    expect(save.progress, closeTo(0.1, 0.0001));
  });
}
