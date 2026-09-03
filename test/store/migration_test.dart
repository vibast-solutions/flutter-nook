import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/chrome/move_history.dart';
import 'package:nook/store/daily_streak.dart';
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

/// The saved-games and statistics tables exactly as schema version 3 created
/// them: version 2 plus the statistics table, and still no `regions` column —
/// that is what version 4 added for Stars (VIB-89).
///
/// A third record beside the two above, for the same reason. A player upgrading
/// to version 4 with a Sudoku in progress is coming from here, and this is the
/// schema their puzzle is sitting in.
const String version3Tables = '''
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
CREATE TABLE statistics (
  game_id TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  solved INTEGER NOT NULL DEFAULT 0,
  best_time INTEGER,
  PRIMARY KEY (game_id, difficulty)
);
''';

/// The same unfinished 4x4, saved by a build that had a statistics table but no
/// notion of a region map.
const String version3Row = '''
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

/// A database holding [version3Row] under the version 3 schema, opened through
/// the current app code — so the version 4 migration runs on the way in.
NookDatabase databaseFromVersion3() {
  return NookDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (dynamic raw) {
          raw.execute(version3Tables);
          raw.execute(version3Row);
          raw.execute('PRAGMA user_version = 3;');
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
}

/// The tables exactly as schema version 4 created them: version 3 plus the
/// nullable `regions` column, and still no `pack_progress` table — that is what
/// version 5 added for the bundled packs (VIB-78).
///
/// A fourth record beside the three above. A player upgrading to version 5 with
/// a puzzle in progress is coming from here.
const String version4Tables = '''
CREATE TABLE saved_games (
  game_id TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  seed INTEGER NOT NULL,
  givens TEXT NOT NULL,
  solution TEXT NOT NULL,
  cells TEXT NOT NULL,
  notes TEXT NOT NULL,
  regions TEXT,
  history TEXT NOT NULL,
  hints TEXT NOT NULL DEFAULT '[]',
  was_hinted INTEGER NOT NULL DEFAULT 0 CHECK (was_hinted IN (0, 1)),
  notes_mode INTEGER NOT NULL DEFAULT 0 CHECK (notes_mode IN (0, 1)),
  elapsed INTEGER NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (game_id)
);
CREATE TABLE statistics (
  game_id TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  solved INTEGER NOT NULL DEFAULT 0,
  best_time INTEGER,
  PRIMARY KEY (game_id, difficulty)
);
''';

/// The same unfinished 4x4, saved by a build that had regions but had never
/// heard of a bundled pack.
const String version4Row = '''
INSERT INTO saved_games (
  game_id, difficulty, seed, givens, solution, cells, notes, history,
  hints, was_hinted, notes_mode, elapsed, updated_at
) VALUES (
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

/// A database holding [version4Row] under the version 4 schema, opened through
/// the current app code — so the version 5 migration runs on the way in.
NookDatabase databaseFromVersion4() {
  return NookDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (dynamic raw) {
          raw.execute(version4Tables);
          raw.execute(version4Row);
          raw.execute('PRAGMA user_version = 4;');
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
}

/// The tables exactly as schema version 5 created them: version 4 plus the
/// `pack_progress` table, and still no `badges` column — that is what version 6
/// added for Duo (VIB-96).
///
/// A fifth record beside the four above. A player upgrading to version 6 with a
/// puzzle in progress is coming from here.
const String version5Tables = '''
CREATE TABLE saved_games (
  game_id TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  seed INTEGER NOT NULL,
  givens TEXT NOT NULL,
  solution TEXT NOT NULL,
  cells TEXT NOT NULL,
  notes TEXT NOT NULL,
  regions TEXT,
  history TEXT NOT NULL,
  hints TEXT NOT NULL DEFAULT '[]',
  was_hinted INTEGER NOT NULL DEFAULT 0 CHECK (was_hinted IN (0, 1)),
  notes_mode INTEGER NOT NULL DEFAULT 0 CHECK (notes_mode IN (0, 1)),
  elapsed INTEGER NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (game_id)
);
CREATE TABLE statistics (
  game_id TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  solved INTEGER NOT NULL DEFAULT 0,
  best_time INTEGER,
  PRIMARY KEY (game_id, difficulty)
);
CREATE TABLE pack_progress (
  pack_id TEXT NOT NULL,
  served INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (pack_id)
);
''';

/// The same unfinished 4x4, saved by a build that had packs but had never heard
/// of a constraint badge.
const String version5SudokuRow = '''
INSERT INTO saved_games (
  game_id, difficulty, seed, givens, solution, cells, notes, history,
  hints, was_hinted, notes_mode, elapsed, updated_at
) VALUES (
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

/// A tiny Stars puzzle in progress beside it, written the way version 5 wrote
/// one: its region map in `regions`, no givens and no notes.
const String version5StarsRow = '''
INSERT INTO saved_games (
  game_id, difficulty, seed, givens, solution, cells, notes, regions, history,
  hints, was_hinted, notes_mode, elapsed, updated_at
) VALUES (
  'stars',
  'gentle',
  99,
  '[]',
  '[0,5]',
  '[2,0,1,0,0,2]',
  '[]',
  '[0,0,1,1,2,2]',
  '[]',
  '[]',
  0,
  0,
  30000,
  '2026-09-03T08:00:00.000Z'
);
''';

/// A database holding a Sudoku and a Stars save under the version 5 schema,
/// opened through the current app code — so the version 6 migration runs on the
/// way in.
NookDatabase databaseFromVersion5() {
  return NookDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (dynamic raw) {
          raw.execute(version5Tables);
          raw.execute(version5SudokuRow);
          raw.execute(version5StarsRow);
          raw.execute('PRAGMA user_version = 5;');
        },
      ),
      closeStreamsSynchronously: true,
    ),
  );
}

/// The tables exactly as schema version 6 created them: version 5 plus the
/// nullable `badges` column, and still neither daily table — those are what
/// version 7 added for the streak (VIB-99).
///
/// A sixth record beside the five above. A player upgrading to version 7 with a
/// puzzle in progress and figures to their name is coming from here, and this is
/// the schema both are sitting in.
const String version6Tables = '''
CREATE TABLE saved_games (
  game_id TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  seed INTEGER NOT NULL,
  givens TEXT NOT NULL,
  solution TEXT NOT NULL,
  cells TEXT NOT NULL,
  notes TEXT NOT NULL,
  regions TEXT,
  badges TEXT,
  history TEXT NOT NULL,
  hints TEXT NOT NULL DEFAULT '[]',
  was_hinted INTEGER NOT NULL DEFAULT 0 CHECK (was_hinted IN (0, 1)),
  notes_mode INTEGER NOT NULL DEFAULT 0 CHECK (notes_mode IN (0, 1)),
  elapsed INTEGER NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (game_id)
);
CREATE TABLE statistics (
  game_id TEXT NOT NULL,
  difficulty TEXT NOT NULL,
  solved INTEGER NOT NULL DEFAULT 0,
  best_time INTEGER,
  PRIMARY KEY (game_id, difficulty)
);
CREATE TABLE pack_progress (
  pack_id TEXT NOT NULL,
  served INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (pack_id)
);
''';

/// The same unfinished 4x4, saved by a build that had every column but the two
/// daily tables.
const String version6SudokuRow = '''
INSERT INTO saved_games (
  game_id, difficulty, seed, givens, solution, cells, notes, history,
  hints, was_hinted, notes_mode, elapsed, updated_at
) VALUES (
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

/// A figure the player has already earned, so the upgrade has statistics to
/// carry as well as a save.
const String version6StatsRow = '''
INSERT INTO statistics (game_id, difficulty, solved, best_time)
VALUES ('sudoku-mini', 'gentle', 3, 120000);
''';

/// A database holding a save and a statistics row under the version 6 schema,
/// opened through the current app code — so the version 7 migration runs on the
/// way in.
NookDatabase databaseFromVersion6() {
  return NookDatabase(
    DatabaseConnection(
      NativeDatabase.memory(
        setup: (dynamic raw) {
          raw.execute(version6Tables);
          raw.execute(version6SudokuRow);
          raw.execute(version6StatsRow);
          raw.execute('PRAGMA user_version = 6;');
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

  test('a sudoku save from before regions survives the upgrade', () async {
    // The version that added regions is the one that made the store stop being
    // sudoku's (VIB-89). A Sudoku already on a player's phone must come through
    // it untouched: it has no region map and keeps none.
    final NookDatabase database = databaseFromVersion3();
    addTearDown(database.close);

    final List<SavedGame> saves = await SavedGameStore(database)
        .watchAll()
        .first;

    expect(saves, hasLength(1), reason: 'the upgrade lost a saved puzzle');
    final SavedGame save = saves.single;
    expect(save.gameId, 'sudoku-mini');
    expect(save.givens, <int>[
      1,
      0,
      0,
      4,
      0,
      0,
      1,
      0,
      0,
      1,
      0,
      0,
      4,
      0,
      0,
      1,
    ], reason: 'the board a player left is the whole point of keeping the row');
    expect(save.cells[1], 2);
    expect(save.hints, <int>[7]);
    expect(save.wasHinted, isTrue);
    expect(save.elapsed, const Duration(minutes: 3, seconds: 7));
    expect(save.updatedAt, DateTime.utc(2026, 9, 2, 10, 30));
    // The new column is null for a Sudoku, which is what says "drawn from
    // givens, not from a region map".
    expect(save.regions, null);
  });

  test('and can be written back beside a Stars save', () async {
    // The point of the column: a Sudoku from an old build and a Stars puzzle
    // written after the upgrade sit in the same table, each with its own shape.
    final NookDatabase database = databaseFromVersion3();
    addTearDown(database.close);
    final SavedGameStore store = SavedGameStore(database);

    await store.save(
      SavedGame(
        gameId: 'stars',
        difficulty: 'gentle',
        seed: 99,
        givens: const <int>[],
        solution: const <int>[0, 5],
        cells: const <int>[2, 0, 1, 0, 0, 2],
        notes: const <int>[],
        regions: const <int>[0, 0, 1, 1, 2, 2],
        history: const MoveHistory.empty(),
        elapsed: const Duration(seconds: 30),
        updatedAt: DateTime.utc(2026, 9, 3, 8),
      ),
    );

    final List<SavedGame> saves = await store.watchAll().first;
    expect(saves, hasLength(2));
    final SavedGame stars = saves.firstWhere(
      (SavedGame save) => save.gameId == 'stars',
    );
    expect(stars.regions, <int>[0, 0, 1, 1, 2, 2]);
    final SavedGame sudoku = saves.firstWhere(
      (SavedGame save) => save.gameId == 'sudoku-mini',
    );
    expect(sudoku.regions, null, reason: 'the Sudoku row stayed a Sudoku');
  });

  test('a save from before packs survives the upgrade', () async {
    // The version that added pack progress (VIB-78) touches nothing a player
    // already has: a puzzle in progress must come through the upgrade exactly
    // as it was left.
    final NookDatabase database = databaseFromVersion4();
    addTearDown(database.close);

    final List<SavedGame> saves = await SavedGameStore(database)
        .watchAll()
        .first;

    expect(saves, hasLength(1), reason: 'the upgrade lost a saved puzzle');
    final SavedGame save = saves.single;
    expect(save.gameId, 'sudoku-mini');
    expect(save.cells[1], 2);
    expect(save.hints, <int>[7]);
    expect(save.wasHinted, isTrue);
    expect(save.elapsed, const Duration(minutes: 3, seconds: 7));
    expect(save.regions, null);
  });

  test('and the new pack-progress table is there to be claimed against', () async {
    // The point of the migration: after it runs, the bookmark into the bundled
    // packs exists and hands puzzles out in order. A player upgrading has seen
    // none of them, so the first claim is index 0.
    final NookDatabase database = databaseFromVersion4();
    addTearDown(database.close);
    final PackProgressStore store = PackProgressStore(database);

    expect(await store.claimNext('sudoku-classic-hard', 3), 0);
    expect(await store.claimNext('sudoku-classic-hard', 3), 1);
    expect(await store.claimNext('sudoku-classic-hard', 3), 2);
    // Spent: the next claim gives nothing, which is the cue to generate on the
    // device.
    expect(await store.claimNext('sudoku-classic-hard', 3), null);
  });

  test('a Stars and a sudoku save from before badges survive the upgrade', () async {
    // The version that added badges is the one that let Duo be saved (VIB-96).
    // A Sudoku and a Stars puzzle already on a player's phone must come through
    // it untouched: neither has badges and neither gains any.
    final NookDatabase database = databaseFromVersion5();
    addTearDown(database.close);

    final List<SavedGame> saves = await SavedGameStore(database)
        .watchAll()
        .first;

    expect(saves, hasLength(2), reason: 'the upgrade lost a saved puzzle');
    final SavedGame sudoku = saves.firstWhere(
      (SavedGame save) => save.gameId == 'sudoku-mini',
    );
    expect(sudoku.givens, <int>[
      1,
      0,
      0,
      4,
      0,
      0,
      1,
      0,
      0,
      1,
      0,
      0,
      4,
      0,
      0,
      1,
    ], reason: 'the board a player left is the whole point of keeping the row');
    expect(sudoku.cells[1], 2);
    expect(sudoku.hints, <int>[7]);
    expect(sudoku.wasHinted, isTrue);
    expect(sudoku.elapsed, const Duration(minutes: 3, seconds: 7));
    expect(sudoku.regions, null);
    expect(sudoku.badges, null);

    final SavedGame stars = saves.firstWhere(
      (SavedGame save) => save.gameId == 'stars',
    );
    expect(stars.regions, <int>[0, 0, 1, 1, 2, 2]);
    expect(stars.cells, <int>[2, 0, 1, 0, 0, 2]);
    expect(stars.solution, <int>[0, 5]);
    expect(stars.elapsed, const Duration(seconds: 30));
    // The new column is null for both, which is what says "no badges here" —
    // and what keeps each row the game it always was.
    expect(stars.badges, null);
  });

  test('and a Duo save can be written in beside them', () async {
    // The point of the column: the two old saves and a Duo puzzle written after
    // the upgrade sit in the same table, each with its own shape.
    final NookDatabase database = databaseFromVersion5();
    addTearDown(database.close);
    final SavedGameStore store = SavedGameStore(database);

    await store.save(
      SavedGame(
        gameId: 'duo',
        difficulty: 'gentle',
        seed: 7,
        givens: const <int>[1, 0, 0, 2],
        solution: const <int>[1, 2, 2, 1],
        cells: const <int>[1, 2, 0, 2],
        notes: const <int>[],
        badges: const <int>[0, 1, 1, 2, 3, 0],
        history: const MoveHistory.empty(),
        elapsed: const Duration(seconds: 45),
        updatedAt: DateTime.utc(2026, 9, 3, 10),
      ),
    );

    final List<SavedGame> saves = await store.watchAll().first;
    expect(saves, hasLength(3));
    final SavedGame duo = saves.firstWhere(
      (SavedGame save) => save.gameId == 'duo',
    );
    expect(duo.badges, <int>[0, 1, 1, 2, 3, 0]);
    expect(duo.regions, null);
    final SavedGame sudoku = saves.firstWhere(
      (SavedGame save) => save.gameId == 'sudoku-mini',
    );
    expect(sudoku.badges, null, reason: 'the Sudoku row stayed a Sudoku');
    final SavedGame stars = saves.firstWhere(
      (SavedGame save) => save.gameId == 'stars',
    );
    expect(stars.badges, null, reason: 'the Stars row stayed Stars');
  });

  test('a save and its statistics survive the upgrade to the daily tables', () async {
    // The version that added the daily tables (VIB-99) touches neither saves nor
    // statistics: a puzzle in progress and the figures a player has earned must
    // both come through the upgrade exactly as they were.
    final NookDatabase database = databaseFromVersion6();
    addTearDown(database.close);

    final SavedGame save = (await SavedGameStore(
      database,
    ).watchAll().first).single;
    expect(save.gameId, 'sudoku-mini');
    expect(save.cells[1], 2);
    expect(save.hints, <int>[7]);
    expect(save.wasHinted, isTrue);
    expect(save.elapsed, const Duration(minutes: 3, seconds: 7));

    final GameStats stats = (await GameStatsStore(
      database,
    ).watchAll().first).single;
    expect(stats.solved, 3, reason: 'the figures a player earned came through');
    expect(stats.bestTime, const Duration(minutes: 2));
  });

  test('and the new daily tables are there, empty, to be counted into', () async {
    // The point of the migration: after it runs, the streak exists and starts at
    // nothing. An upgrading player has solved no dailies, so the streak reads as
    // zero — with no row invented for them — and the first solve counts as one.
    final NookDatabase database = databaseFromVersion6();
    addTearDown(database.close);
    final DailyStore store = DailyStore(database);

    DateTime today() => DateTime.utc(2026, 9, 3, 9);
    expect((await store.watch(today).first).streak, 0);
    expect((await store.watch(today).first).solvedToday, isFalse);

    await store.recordSolve(
      date: DateTime.utc(2026, 9, 3),
      today: today(),
      gameId: 'duo',
      difficulty: 'medium',
    );

    final DailyStreakStatus status = await store.watch(today).first;
    expect(status.streak, 1);
    expect(status.solvedToday, isTrue);
  });
}
