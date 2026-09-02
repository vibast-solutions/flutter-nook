import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';

/// The saved-games table exactly as schema version 1 created it, before hints
/// (VIB-76) added two columns to it.
///
/// Written out rather than generated, because that is the point: it is a
/// record of what is already on players' phones, and it must not change when
/// the current schema does.
const String version1Table = '''
CREATE TABLE saved_games (
  game_id TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  seed INTEGER NOT NULL,
  givens TEXT NOT NULL,
  solution TEXT NOT NULL,
  cells TEXT NOT NULL,
  notes TEXT NOT NULL,
  history TEXT NOT NULL,
  notes_mode INTEGER NOT NULL DEFAULT 0 CHECK (notes_mode IN (0, 1)),
  elapsed INTEGER NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (game_id)
);
''';

/// One unfinished 4x4, saved by a build that had never heard of a hint.
const String version1Row = '''
INSERT INTO saved_games VALUES (
  'sudoku-mini',
  'gentle',
  4242,
  '[1,0,0,4,0,0,1,0,0,1,0,0,4,0,0,1]',
  '[1,2,3,4,3,4,1,2,2,1,4,3,4,3,2,1]',
  '[1,2,0,4,0,0,1,0,0,1,0,0,4,0,0,1]',
  '[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]',
  '[]',
  0,
  187000,
  '2026-09-02T10:30:00.000Z'
);
''';

/// A database holding [version1Row] under the version 1 schema, opened through
/// the current app code — so the migration runs on the way in.
NookDatabase databaseFromVersion1() {
  return NookDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        // The raw handle is a `sqlite3` database, which the app does not
        // depend on directly and is not going to start depending on for a
        // test. Three `execute` calls are all this needs from it.
        setup: (dynamic raw) {
          raw.execute(version1Table);
          raw.execute(version1Row);
          // What tells drift there is a migration to run at all.
          raw.execute('PRAGMA user_version = 1;');
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
}

void main() {
  test('a save from before hints survives the upgrade', () async {
    final NookDatabase database = databaseFromVersion1();
    addTearDown(database.close);

    final List<SavedGame> saves = await SavedGameStore(database)
        .watchAll()
        .first;

    expect(saves, hasLength(1), reason: 'the upgrade lost a saved puzzle');
    final SavedGame save = saves.single;
    // The board the player left is the whole point: an upgrade that kept the
    // row but forgot the puzzle would be no better than dropping it.
    expect(save.gameId, 'sudoku-mini');
    expect(save.cells[1], 2);
    expect(save.elapsed, const Duration(minutes: 3, seconds: 7));
    expect(save.updatedAt, DateTime.utc(2026, 9, 2, 10, 30));
    // A puzzle saved before hints existed is a puzzle nobody was helped with.
    expect(save.hints, isEmpty);
    expect(save.wasHinted, isFalse);
  });

  test('and can be written back with hints on it', () async {
    final NookDatabase database = databaseFromVersion1();
    addTearDown(database.close);
    final SavedGameStore store = SavedGameStore(database);
    final SavedGame save = (await store.watchAll().first).single;

    await store.save(
      SavedGame(
        gameId: save.gameId,
        difficulty: save.difficulty,
        seed: save.seed,
        givens: save.givens,
        solution: save.solution,
        cells: save.cells,
        notes: save.notes,
        history: save.history,
        hints: <int>[2, 5],
        wasHinted: true,
        elapsed: save.elapsed,
        updatedAt: save.updatedAt,
      ),
    );

    final SavedGame written = (await store.watchAll().first).single;
    expect(written.hints, <int>[2, 5]);
    expect(written.wasHinted, isTrue);
  });
}
