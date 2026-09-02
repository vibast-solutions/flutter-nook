import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/store/game_stats.dart';
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

/// The saved-games table exactly as schema version 2 created it: version 1
/// plus the two hint columns, and still no statistics table (VIB-77).
///
/// A second record beside [version1Table], for the same reason. Most players
/// upgrading to version 3 are coming from here rather than from version 1.
const String version2Table = '''
CREATE TABLE saved_games (
  game_id TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  seed INTEGER NOT NULL,
  givens TEXT NOT NULL,
  solution TEXT NOT NULL,
  cells TEXT NOT NULL,
  notes TEXT NOT NULL,
  history TEXT NOT NULL,
  hints TEXT NOT NULL DEFAULT '[]',
  was_hinted INTEGER NOT NULL DEFAULT 0 CHECK (was_hinted IN (0, 1)),
  notes_mode INTEGER NOT NULL DEFAULT 0 CHECK (notes_mode IN (0, 1)),
  elapsed INTEGER NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (game_id)
);
''';

/// The same unfinished 4x4, saved by a build that counted nothing.
const String version2Row = '''
INSERT INTO saved_games VALUES (
  'sudoku-mini',
  'gentle',
  4242,
  '[1,0,0,4,0,0,1,0,0,1,0,0,4,0,0,1]',
  '[1,2,3,4,3,4,1,2,2,1,4,3,4,3,2,1]',
  '[1,2,0,4,0,0,1,0,0,1,0,0,4,0,0,1]',
  '[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]',
  '[]',
  '[7]',
  1,
  0,
  187000,
  '2026-09-02T10:30:00.000Z'
);
''';

/// A database holding [version2Row] under the version 2 schema, opened through
/// the current app code.
NookDatabase databaseFromVersion2() {
  return NookDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (dynamic raw) {
          raw.execute(version2Table);
          raw.execute(version2Row);
          raw.execute('PRAGMA user_version = 2;');
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

  test('a save from before statistics survives the upgrade', () async {
    final NookDatabase database = databaseFromVersion2();
    addTearDown(database.close);

    final List<SavedGame> saves = await SavedGameStore(database)
        .watchAll()
        .first;

    expect(saves, hasLength(1), reason: 'the upgrade lost a saved puzzle');
    final SavedGame save = saves.single;
    expect(save.cells[1], 2);
    // The hint columns version 2 introduced come through untouched.
    expect(save.hints, <int>[7]);
    expect(save.wasHinted, isTrue);
  });

  test('and starts counting from nothing rather than from a guess', () async {
    // Nook was not keeping figures before this version, so there is nothing on
    // disk to work them out from. A player who has solved fifty puzzles starts
    // at none, which is the only honest number available.
    final NookDatabase database = databaseFromVersion2();
    addTearDown(database.close);
    final GameStatsStore store = GameStatsStore(database);

    expect(await store.watchAll().first, isEmpty);

    final SolveOutcome outcome = await store.record(
      gameId: 'sudoku-mini',
      difficulty: 'gentle',
      time: const Duration(minutes: 2),
      hinted: false,
    );

    expect(outcome.solved, 1);
    expect(outcome.isPersonalBest, isTrue);
    expect((await store.watchAll().first).single.bestTime, outcome.time);
  });

  test('a database from version 1 gets the statistics table too', () async {
    // Two upgrades in one open, which is what a player who skipped a release
    // gets. The second must not be skipped because the first ran.
    final NookDatabase database = databaseFromVersion1();
    addTearDown(database.close);
    final GameStatsStore store = GameStatsStore(database);

    await store.record(
      gameId: 'sudoku-mini',
      difficulty: 'gentle',
      time: const Duration(minutes: 4),
      hinted: false,
    );

    expect((await store.watchAll().first).single.solved, 1);
  });
}
