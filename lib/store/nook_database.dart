import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../chrome/move_history.dart';
import '../chrome/play_clock.dart';
import 'daily_streak.dart';
import 'game_stats.dart';
import 'saved_game.dart';

part 'nook_database.g.dart';

/// The unfinished puzzles, at most one per game.
///
/// The generated row class is named `SavedGameRow` rather than taking the
/// singular of the table, so that [SavedGame] — the type the rest of the app
/// passes around — keeps its name.
///
/// The grids and the move history are stored as JSON text rather than as
/// columns of their own: they are opaque to every query this app will ever run
/// — a save is only ever fetched whole — and a nested table would buy
/// structure nobody reads at the price of a join per resume.
@DataClassName('SavedGameRow')
class SavedGames extends Table {
  /// The game's stable identifier, which is also what makes the save unique.
  TextColumn get gameId => text()();

  /// The tier, as its identifier rather than a name a player reads.
  TextColumn get difficulty => text()();

  /// The seed the puzzle was generated from.
  IntColumn get seed => integer()();

  /// The starting grid.
  TextColumn get givens => text().map(const _DigitsConverter())();

  /// The one solution.
  TextColumn get solution => text().map(const _DigitsConverter())();

  /// The grid as the player left it.
  TextColumn get cells => text().map(const _DigitsConverter())();

  /// The pencil marks, one bitmask per cell.
  TextColumn get notes => text().map(const _DigitsConverter())();

  /// The region each cell belongs to, or null for a board without regions.
  ///
  /// Nullable and added in version 4 (VIB-89): a Sudoku leaves it null and is
  /// drawn from [givens]; a Stars puzzle *is* its regions and stores them here.
  /// One nullable column keeps every Sudoku row untouched and the migration a
  /// single statement.
  TextColumn get regions => text().map(const _DigitsConverter()).nullable()();

  /// The constraint badges between cells, or null for a board without badges.
  ///
  /// Nullable and added in version 6 (VIB-96), the way [regions] was for Stars:
  /// Duo's `=`/`x` badges are half its puzzle and nothing else in the row could
  /// hold them. Encoded as flat integer triples — two cell indices and a
  /// relation — because the store carries lists of small integers, not any one
  /// game's types. Sudoku and Stars leave it null and are untouched.
  TextColumn get badges => text().map(const _DigitsConverter()).nullable()();

  /// The moves still to take back.
  TextColumn get history => text().map(const _HistoryConverter())();

  /// The cells that were given away by a hint.
  TextColumn get hints =>
      text().map(const _DigitsConverter()).withDefault(const Constant('[]'))();

  /// Whether the puzzle was ever hinted, whatever is on the board now.
  BoolColumn get wasHinted => boolean().withDefault(const Constant(false))();

  /// Whether the pad was left writing pencil marks.
  BoolColumn get notesMode => boolean().withDefault(const Constant(false))();

  /// How long the puzzle has been played for.
  IntColumn get elapsed => integer().map(const _DurationConverter())();

  /// When this save was last written; the newest is the one Continue offers.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{gameId};
}

/// What has been finished, one row per game and tier.
///
/// The whole of Nook's statistics: a count and a best time. Nothing is kept
/// about an individual solve — not when it was, not how long it took, not
/// which puzzle it was — because nothing on any screen asks, and a puzzle
/// diary nobody reads is a record of somebody's evenings sitting on their
/// phone for no reason.
///
/// The generated row class is named `GameStatsRow` so that [GameStats], the
/// type the rest of the app passes around, keeps its name.
@DataClassName('GameStatsRow')
class Statistics extends Table {
  /// Which game, as the same stable identifier a save uses.
  TextColumn get gameId => text()();

  /// Which tier of it, as an identifier rather than a name a player reads.
  TextColumn get difficulty => text()();

  /// How many puzzles have been finished here.
  IntColumn get solved => integer().withDefault(const Constant(0))();

  /// The fastest hint-free solve, or null if there has not been one.
  IntColumn get bestTime =>
      integer().map(const _DurationConverter()).nullable()();

  /// A game and a tier name one set of figures between them.
  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{gameId, difficulty};
}

/// How far into each bundled pack the player has been served.
///
/// A pack is an ordered list of pre-generated puzzles shipped in the app so the
/// first tap after a cold launch is instant (VIB-78). Handing them out in order
/// and remembering how many have gone is the whole of "a puzzle already played
/// is not served again while unplayed ones remain": [served] is the index of the
/// next one to give, so a puzzle is handed out at most once until the pack is
/// spent and the app falls back to generating on the device.
///
/// Deliberately not a save and not a statistic — it is neither the puzzle nor
/// its result, only a bookmark into shipped content — but it lives in the same
/// database because it is the same kind of thing: a small durable fact about
/// what the player has seen, that has to survive the app being closed.
class PackProgress extends Table {
  /// The pack's identity, `game-tier`, matching its asset file name.
  TextColumn get packId => text()();

  /// How many of the pack's puzzles have been handed out — the index of the
  /// next one to serve.
  IntColumn get served => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{packId};
}

/// One row per solved daily puzzle, keyed on the date it was the daily for.
///
/// The daily is the same puzzle for everybody on a given calendar day, and this
/// remembers the days a player has finished it. v1 only ever reads today's row —
/// to know whether the streak counts today — but the whole history is kept, one
/// row per solved date, so a future calendar screen can light up solved days
/// without another migration (the 2026-09-03 planning decision: prepare for a
/// calendar, not just the streak pair).
///
/// The generated row class is named `DailySolveRow` to leave the noun free.
@DataClassName('DailySolveRow')
class DailySolves extends Table {
  /// The **local** calendar date this was the daily for, as `yyyy-MM-dd`. The
  /// daily lives in the player's own day, so this is never a UTC date; it is
  /// also the primary key, which is what makes solving one day's daily twice a
  /// single row rather than two.
  TextColumn get date => text()();

  /// Which game the day landed on, as the same stable id a statistic uses.
  TextColumn get gameId => text()();

  /// The tier it was played at, as an identifier rather than a name a player
  /// reads.
  TextColumn get difficulty => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{date};
}

/// The daily streak: a single row holding the current run and the last day it
/// counted.
///
/// Stored rather than derived from [DailySolves], per Business Logic: the streak
/// must survive months of the app being closed, and reading it must not walk a
/// year of solved-day rows. The reset — a date passing with the daily unsolved
/// takes it to zero — happens at read time against the clock, so nothing has to
/// run in the background to break a streak.
///
/// One row, enforced by a fixed key. The generated row class is named
/// `DailyStreakRow` so the noun stays free for the value type the app passes
/// around.
@DataClassName('DailyStreakRow')
class DailyStreak extends Table {
  /// A fixed key: there is only ever one streak, so every write lands on the
  /// same row.
  IntColumn get id => integer().withDefault(const Constant(0))();

  /// The current run of consecutive solved days.
  IntColumn get count => integer().withDefault(const Constant(0))();

  /// The last local date whose daily was solved, as `yyyy-MM-dd`, or null before
  /// any daily has been solved. What the read rule measures "today or yesterday"
  /// against.
  TextColumn get lastSolvedDate => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Everything Nook keeps on the device.
///
/// One database for saves and statistics: they are the same data seen twice —
/// a puzzle in progress, and what was left of it once it was finished — and a
/// result is only interesting next to the ones before it.
@DriftDatabase(
  tables: <Type>[
    SavedGames,
    Statistics,
    PackProgress,
    DailySolves,
    DailyStreak,
  ],
)
class NookDatabase extends _$NookDatabase {
  NookDatabase(super.e);

  /// A database in memory, which is what a test wants: the real schema and the
  /// real SQL, gone when the test ends.
  ///
  /// Its query streams stop the instant their last listener does. Drift
  /// normally waits an event loop before letting go, to spare a rebuilding
  /// widget a second query — and a timer outliving a widget test is exactly
  /// what the test framework fails a test for.
  NookDatabase.memory()
    : super(
        DatabaseConnection(
          NativeDatabase.memory(),
          closeStreamsSynchronously: true,
        ),
      );

  @override
  int get schemaVersion => 7;

  /// Version 2 added the two hint columns (VIB-76); version 3 the statistics
  /// table (VIB-77); version 4 the nullable `regions` column, which is what
  /// lets a game whose puzzle is a region map — Stars — be saved (VIB-89);
  /// version 5 the `pack_progress` table, the bookmark into each bundled pack
  /// (VIB-78). An upgrading player starts every pack from the beginning, which
  /// is exactly right — they have seen none of these puzzles. Version 6 added
  /// the nullable `badges` column, which is what lets a game whose puzzle
  /// carries constraint badges — Duo — be saved (VIB-96); every earlier row
  /// has no badges and keeps none. Version 7 added the two daily tables — the
  /// per-date record of solved dailies and the single streak row (VIB-99); an
  /// upgrading player has solved no dailies yet, so both start empty and the
  /// streak reads as zero, which is exactly right.
  ///
  /// A save from version 1 is a puzzle nobody was helped with, which is
  /// exactly what the column defaults say. A player who arrives at version 3
  /// has solved puzzles Nook was not counting, and those are gone: there is
  /// nothing on disk to count them from, and inventing a number would be
  /// worse than starting from none. A Sudoku save from any earlier version has
  /// no regions and keeps none — the column stays null and the board is still
  /// drawn from its givens. A player mid-puzzle keeps their board through all
  /// of it.
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) => m.createAll(),
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(savedGames, savedGames.hints);
          await m.addColumn(savedGames, savedGames.wasHinted);
        }
        if (from < 3) {
          await m.createTable(statistics);
        }
        if (from < 4) {
          await m.addColumn(savedGames, savedGames.regions);
        }
        if (from < 5) {
          await m.createTable(packProgress);
        }
        if (from < 6) {
          await m.addColumn(savedGames, savedGames.badges);
        }
        if (from < 7) {
          await m.createTable(dailySolves);
          await m.createTable(dailyStreak);
        }
      },
    );
  }

  /// Timestamps are stored as ISO-8601 text rather than as unix seconds.
  ///
  /// Seconds would round a save's time to the nearest second and hand it back
  /// in whatever zone the phone is in now, so a player who crosses a time zone
  /// could see two saves swap places in the Continue card. Text keeps the
  /// instant exactly as it was written.
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

/// Opens the database file, creating it on first launch.
///
/// Lazily, and on a background isolate: opening SQLite reads from disk, and
/// the first frame must not wait for it.
QueryExecutor openNookDatabase() {
  return LazyDatabase(() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    return NativeDatabase.createInBackground(
      File(p.join(directory.path, 'nook.sqlite')),
    );
  });
}

/// Reading and writing saved games.
///
/// The only way the app touches the database, so the shape of a save is
/// decided in one place and the screens never learn any SQL.
class SavedGameStore {
  const SavedGameStore(this._db);

  final NookDatabase _db;

  /// Writes [game], replacing whatever was saved for the same game.
  ///
  /// One row per game is the rule, and letting the database enforce it means a
  /// bug can lose a save but can never quietly grow a second one.
  Future<void> save(SavedGame game) {
    return _db.into(_db.savedGames).insertOnConflictUpdate(_rowOf(game));
  }

  /// Throws away the save for [gameId], if there is one.
  Future<void> discard(String gameId) {
    return (_db.delete(
      _db.savedGames,
    )..where(($SavedGamesTable row) => row.gameId.equals(gameId))).go();
  }

  /// Every unfinished puzzle, most recently played first.
  ///
  /// One stream for the whole set rather than a query per screen: there is at
  /// most one save per game and Nook has a handful of games, so fetching them
  /// all costs less than the bookkeeping of fetching them one at a time — and
  /// the Continue card and the In-progress card can then never disagree about
  /// what is saved.
  Stream<List<SavedGame>> watchAll() {
    return (_db.select(_db.savedGames)
          ..orderBy(<OrderingTerm Function($SavedGamesTable)>[
            ($SavedGamesTable row) => OrderingTerm.desc(row.updatedAt),
          ]))
        .map(_savedGameOf)
        .watch();
  }

  SavedGamesCompanion _rowOf(SavedGame game) {
    return SavedGamesCompanion.insert(
      gameId: game.gameId,
      difficulty: game.difficulty,
      seed: game.seed,
      givens: game.givens,
      solution: game.solution,
      cells: game.cells,
      notes: game.notes,
      regions: Value<List<int>?>(game.regions),
      badges: Value<List<int>?>(game.badges),
      history: game.history,
      hints: Value<List<int>>(game.hints),
      wasHinted: Value<bool>(game.wasHinted),
      notesMode: Value<bool>(game.notesMode),
      elapsed: game.elapsed,
      updatedAt: game.updatedAt,
    );
  }

  SavedGame _savedGameOf(SavedGameRow row) {
    return SavedGame(
      gameId: row.gameId,
      difficulty: row.difficulty,
      seed: row.seed,
      givens: row.givens,
      solution: row.solution,
      cells: row.cells,
      notes: row.notes,
      regions: row.regions,
      badges: row.badges,
      history: row.history,
      hints: row.hints,
      wasHinted: row.wasHinted,
      notesMode: row.notesMode,
      elapsed: row.elapsed,
      updatedAt: row.updatedAt,
    );
  }
}

/// Reading and writing what has been solved.
///
/// Separate from [SavedGameStore] because the two tables are written at
/// opposite moments — one as a puzzle is played, the other once it is over —
/// and a class that did both would be the only place in the app where
/// finishing and saving met.
class GameStatsStore {
  const GameStatsStore(this._db);

  final NookDatabase _db;

  /// Counts a finished puzzle and says what it did to the figures.
  ///
  /// The read and the write are one transaction: [SolveOutcome.previousBest]
  /// is the number the player has just beaten, and it stops existing the
  /// instant the new best is stored.
  ///
  /// [hinted] is the whole of the personal-best rule. A hinted puzzle counts
  /// as solved and keeps its time; it just never becomes the time to beat,
  /// because a best that a hint could set would mean nothing.
  Future<SolveOutcome> record({
    required String gameId,
    required String difficulty,
    required Duration time,
    required bool hinted,
  }) {
    return _db.transaction(() async {
      final GameStatsRow? before =
          await (_db.select(_db.statistics)..where(
                ($StatisticsTable row) =>
                    row.gameId.equals(gameId) &
                    row.difficulty.equals(difficulty),
              ))
              .getSingleOrNull();
      final Duration? previousBest = before?.bestTime;
      final bool isPersonalBest =
          !hinted && (previousBest == null || time < previousBest);
      final int solved = (before?.solved ?? 0) + 1;

      await _db
          .into(_db.statistics)
          .insertOnConflictUpdate(
            StatisticsCompanion.insert(
              gameId: gameId,
              difficulty: difficulty,
              solved: Value<int>(solved),
              bestTime: Value<Duration?>(isPersonalBest ? time : previousBest),
            ),
          );

      return SolveOutcome(
        time: time,
        previousBest: previousBest,
        solved: solved,
        wasHinted: hinted,
        isPersonalBest: isPersonalBest,
      );
    });
  }

  /// Every figure Nook holds, for every game and tier.
  ///
  /// One stream for the whole set, like saved games and for the same reason:
  /// there are a handful of rows in total, and a screen that showed five tiers
  /// would otherwise open five queries to fill in five lines.
  Stream<List<GameStats>> watchAll() {
    return (_db.select(_db.statistics)
          ..orderBy(<OrderingTerm Function($StatisticsTable)>[
            ($StatisticsTable row) => OrderingTerm(expression: row.gameId),
            ($StatisticsTable row) => OrderingTerm(expression: row.difficulty),
          ]))
        .map(_statsOf)
        .watch();
  }

  GameStats _statsOf(GameStatsRow row) {
    return GameStats(
      gameId: row.gameId,
      difficulty: row.difficulty,
      solved: row.solved,
      bestTime: row.bestTime,
    );
  }
}

/// Claiming puzzles out of the bundled packs, in order and each at most once.
///
/// The one place the served-cursor is read and moved, so "a puzzle already
/// played is not served again while unplayed ones remain" is enforced in a
/// single transaction rather than trusted to every caller.
class PackProgressStore {
  const PackProgressStore(this._db);

  final NookDatabase _db;

  /// Claims the next unused puzzle of [packId], given the pack holds [count] of
  /// them, and returns its index — or `null` when the pack is spent.
  ///
  /// Read and write are one transaction: two starts in quick succession can
  /// never claim the same index, and a `null` is the caller's cue to generate on
  /// the device instead. The cursor only ever moves forward, so a puzzle handed
  /// out is never handed out again while any remain.
  Future<int?> claimNext(String packId, int count) {
    return _db.transaction(() async {
      final PackProgressData? row =
          await (_db.select(_db.packProgress)
                ..where(($PackProgressTable r) => r.packId.equals(packId)))
              .getSingleOrNull();
      final int served = row?.served ?? 0;
      if (served >= count) {
        return null;
      }
      await _db
          .into(_db.packProgress)
          .insertOnConflictUpdate(
            PackProgressCompanion.insert(
              packId: packId,
              served: Value<int>(served + 1),
            ),
          );
      return served;
    });
  }
}

/// Recording solved dailies and reading the streak they add up to.
///
/// Separate from the other stores because the daily is its own thing: the same
/// puzzle for every player on a given day, counted towards a streak that no
/// ordinary solve ever touches. Written at one moment — when a daily is solved
/// (VIB-98's page calls [recordSolve] on the discard-the-save seam) — and read
/// wherever the streak shows, the home card and the finished-puzzle screen.
///
/// Every date it handles is a **local** calendar date: the daily's own date is
/// which day it was the puzzle for, and `today` is the device's own day. Both
/// are compared as `yyyy-MM-dd` text, so two dates meet by calendar day and
/// never by clock.
class DailyStore {
  const DailyStore(this._db);

  final NookDatabase _db;

  /// The one row the streak ever occupies.
  static const int _streakRowId = 0;

  /// Records that the daily for [date] was solved, and advances the streak when
  /// that date is [today].
  ///
  /// The row for [date] is written either way — a stale daily (opened before
  /// midnight, finished after) is still a solved day the calendar will want.
  /// The streak only moves for a daily finished on its own day: solving today's
  /// takes the run to `count + 1` when yesterday was solved, or to 1 otherwise,
  /// and solving it a second time does nothing because the last date is already
  /// today. The row-write and the streak-write are one transaction, so a solve
  /// can never leave a counted day without the streak that follows from it.
  Future<void> recordSolve({
    required DateTime date,
    required DateTime today,
    required String gameId,
    required String difficulty,
  }) {
    final String dateKey = _dateKey(date);
    final String todayKey = _dateKey(today);
    return _db.transaction(() async {
      await _db
          .into(_db.dailySolves)
          .insertOnConflictUpdate(
            DailySolvesCompanion.insert(
              date: dateKey,
              gameId: gameId,
              difficulty: difficulty,
            ),
          );
      // A stale daily is recorded for the calendar but leaves the streak alone:
      // the run is about the player's own days, and this puzzle was not today's.
      if (dateKey != todayKey) {
        return;
      }
      final DailyStreakRow? current = await _db
          .select(_db.dailyStreak)
          .getSingleOrNull();
      final String? last = current?.lastSolvedDate;
      // Already counted today. Solving the same daily again changes nothing.
      if (last == todayKey) {
        return;
      }
      final int nextCount = last == _dateKey(_dayBefore(today))
          ? (current?.count ?? 0) + 1
          : 1;
      await _db
          .into(_db.dailyStreak)
          .insertOnConflictUpdate(
            // The key is written explicitly, not left to default: an
            // `INTEGER PRIMARY KEY` is SQLite's rowid, and an absent value makes
            // it auto-increment rather than take the default — which would grow
            // a second streak row instead of replacing the one there is.
            DailyStreakCompanion.insert(
              id: const Value<int>(_streakRowId),
              count: Value<int>(nextCount),
              lastSolvedDate: Value<String?>(todayKey),
            ),
          );
    });
  }

  /// The streak as a screen needs it, recomputed against [now] on every change.
  ///
  /// [now] is a function so the value tracks the clock a test owns; it is read
  /// at each emission, which is where the reset lives — a stored run whose last
  /// day is neither today nor yesterday reads as zero, with nothing having run
  /// in the background to zero it.
  Stream<DailyStreakStatus> watch(DateTime Function() now) {
    return _db
        .select(_db.dailyStreak)
        .watchSingleOrNull()
        .map((DailyStreakRow? row) => _statusOf(row, now()));
  }

  /// The stored run read against [now]: the number to show, and whether today's
  /// daily is among the solved days.
  ///
  /// The streak keeps its full count while its last day is today **or**
  /// yesterday — yesterday still counts because today is not over, and a day
  /// only breaks a streak once it has passed unsolved. `solvedToday` is exactly
  /// "today's daily has been solved": the only way the last day becomes today
  /// is [recordSolve] finishing today's daily, which writes today's row in the
  /// same transaction, so the two never disagree.
  DailyStreakStatus _statusOf(DailyStreakRow? row, DateTime now) {
    final String? last = row?.lastSolvedDate;
    if (row == null || last == null) {
      return const DailyStreakStatus(streak: 0, solvedToday: false);
    }
    final String todayKey = _dateKey(now);
    final bool solvedToday = last == todayKey;
    final bool current = solvedToday || last == _dateKey(_dayBefore(now));
    return DailyStreakStatus(
      streak: current ? row.count : 0,
      solvedToday: solvedToday,
    );
  }
}

/// A calendar date as `yyyy-MM-dd`, from its day fields alone.
///
/// Only the year, month and day are read, so the same key comes out whether the
/// instant is held in the device's zone or in UTC — which is what lets the
/// daily's UTC-midnight date and a local `now` be compared as the same kind of
/// thing.
String _dateKey(DateTime date) {
  final String year = date.year.toString().padLeft(4, '0');
  final String month = date.month.toString().padLeft(2, '0');
  final String day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// The calendar day before [date].
///
/// Rebuilt in UTC before subtracting a day so the arithmetic is exact: taking a
/// day off a local midnight would come up a daylight-saving hour short twice a
/// year and could land on the wrong calendar date.
DateTime _dayBefore(DateTime date) {
  return DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).subtract(const Duration(days: 1));
}

/// The database itself. Overridden in tests with an in-memory one.
final Provider<NookDatabase> nookDatabaseProvider = Provider<NookDatabase>((
  Ref ref,
) {
  final NookDatabase database = NookDatabase(openNookDatabase());
  ref.onDispose(database.close);
  return database;
}, name: 'nookDatabase');

/// Saved games, read and written.
final Provider<SavedGameStore> savedGameStoreProvider =
    Provider<SavedGameStore>(
      (Ref ref) => SavedGameStore(ref.watch(nookDatabaseProvider)),
      name: 'savedGameStore',
    );

/// Every unfinished puzzle, most recently played first.
///
/// The Continue card takes the first of these; a game screen looks for its own
/// game id. Empty means nothing is in progress.
final StreamProvider<List<SavedGame>> savedGamesProvider =
    StreamProvider<List<SavedGame>>(
      (Ref ref) => ref.watch(savedGameStoreProvider).watchAll(),
      name: 'savedGames',
    );

/// Solved counts and best times, read and written.
final Provider<GameStatsStore> gameStatsStoreProvider =
    Provider<GameStatsStore>(
      (Ref ref) => GameStatsStore(ref.watch(nookDatabaseProvider)),
      name: 'gameStatsStore',
    );

/// The bookmark into each bundled pack, read and moved.
final Provider<PackProgressStore> packProgressStoreProvider =
    Provider<PackProgressStore>(
      (Ref ref) => PackProgressStore(ref.watch(nookDatabaseProvider)),
      name: 'packProgressStore',
    );

/// Solved dailies and the streak, read and written.
final Provider<DailyStore> dailyStoreProvider = Provider<DailyStore>(
  (Ref ref) => DailyStore(ref.watch(nookDatabaseProvider)),
  name: 'dailyStore',
);

/// The daily streak as the screens show it, recomputed against the clock.
///
/// The home card and the finished-puzzle screen both read this: the number is
/// the same in both places, and the reset is evaluated here rather than by
/// anything running in the background.
final StreamProvider<DailyStreakStatus> dailyStreakProvider =
    StreamProvider<DailyStreakStatus>(
      (Ref ref) => ref.watch(dailyStoreProvider).watch(ref.watch(nowProvider)),
      name: 'dailyStreak',
    );

/// What has been solved, for every game and tier.
///
/// The difficulty screen reads its own game's rows out of this; the finished
/// screen is told its numbers by the write that produced them instead, because
/// it needs the best time as it was a moment ago.
final StreamProvider<List<GameStats>> gameStatsProvider =
    StreamProvider<List<GameStats>>(
      (Ref ref) => ref.watch(gameStatsStoreProvider).watchAll(),
      name: 'gameStats',
    );

/// A list of small integers, as one text column.
class _DigitsConverter extends TypeConverter<List<int>, String> {
  const _DigitsConverter();

  @override
  List<int> fromSql(String fromDb) {
    return <int>[
      for (final Object? value in jsonDecode(fromDb) as List<Object?>)
        value! as int,
    ];
  }

  @override
  String toSql(List<int> value) => jsonEncode(value);
}

/// A move history, as one text column.
class _HistoryConverter extends TypeConverter<MoveHistory, String> {
  const _HistoryConverter();

  @override
  MoveHistory fromSql(String fromDb) =>
      MoveHistory.fromJson(jsonDecode(fromDb) as List<Object?>);

  @override
  String toSql(MoveHistory value) => jsonEncode(value.toJson());
}

/// A duration, stored as whole milliseconds.
class _DurationConverter extends TypeConverter<Duration, int> {
  const _DurationConverter();

  @override
  Duration fromSql(int fromDb) => Duration(milliseconds: fromDb);

  @override
  int toSql(Duration value) => value.inMilliseconds;
}
