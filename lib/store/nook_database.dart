import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../chrome/move_history.dart';
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

  /// The moves still to take back.
  TextColumn get history => text().map(const _HistoryConverter())();

  /// Whether the pad was left writing pencil marks.
  BoolColumn get notesMode => boolean().withDefault(const Constant(false))();

  /// How long the puzzle has been played for.
  IntColumn get elapsed => integer().map(const _DurationConverter())();

  /// When this save was last written; the newest is the one Continue offers.
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{gameId};
}

/// Everything Nook keeps on the device.
///
/// One database for saves and, later, statistics (VIB-77) — they are the same
/// data seen twice, and a puzzle's result is only interesting next to the ones
/// before it.
@DriftDatabase(tables: <Type>[SavedGames])
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
  int get schemaVersion => 1;

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
      history: game.history,
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
      history: row.history,
      notesMode: row.notesMode,
      elapsed: row.elapsed,
      updatedAt: row.updatedAt,
    );
  }
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
