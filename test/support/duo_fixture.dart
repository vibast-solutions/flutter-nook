import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/duo_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/chrome/move_history.dart';
import 'package:nook/games/duo/duo_controller.dart';
import 'package:nook/games/duo/duo_save.dart';
import 'package:nook/games/duo/duo_screen.dart';
import 'package:nook/games/duo/duo_state.dart';
import 'package:nook/games/duo/duo_variant.dart';
import 'package:nook/home/home_screen.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// The English strings, so a test can say what a screen should show without
/// writing the words out a second time.
final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

/// A Duo puzzle, the same one every run.
///
/// The engine is deterministic, so a seed names a puzzle as precisely as its
/// givens and badges would, and a test that says what it wants beats a wall of
/// symbols nobody can check by eye. Its [DuoPuzzle.solution] is what a test
/// drives the board to.
DuoPuzzle fixedDuoPuzzle() => DuoGenerator(DuoSpec.standard).generate(2026);

/// The Duo variants, for a test that has to hold for all of them. One today.
const List<DuoVariant> allDuoVariants = DuoVariant.values;

/// A clock the test winds on by hand.
class TestClock {
  TestClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 9, 3, 9);

  DateTime _now;

  /// The current instant, as [nowProvider] wants it.
  DateTime call() => _now;

  /// Moves the world forward.
  void advance(Duration by) => _now = _now.add(by);
}

/// A database that lives in memory and goes away with the test.
NookDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final NookDatabase database = NookDatabase.memory();
  addTearDown(database.close);
  return database;
}

/// Wraps [child] in what every Duo screen needs under test: a puzzle already
/// made, a database in memory, and a clock the test owns.
Widget duoScope({
  required DuoPuzzle puzzle,
  required Widget child,
  DuoPuzzleSource? source,
  NookDatabase? database,
  TestClock? clock,
}) {
  return ProviderScope(
    overrides: [
      duoPuzzleSourceProvider.overrideWithValue(
        source ??
            (DuoSpec spec, PuzzleDifficulty tier, int seed) async => puzzle,
      ),
      nookDatabaseProvider.overrideWithValue(database ?? memoryDatabase()),
      nowProvider.overrideWithValue((clock ?? TestClock()).call),
    ],
    child: child,
  );
}

/// Gives the test a phone-shaped window so the board fits and taps are not
/// swallowed by an off-screen scroll position.
Future<void> setPhoneSurface(WidgetTester tester, {double width = 400}) async {
  await tester.binding.setSurfaceSize(Size(width, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Pumps the home screen wired to a fixed Duo puzzle.
Future<void> pumpDuoHome(
  WidgetTester tester, {
  NookDatabase? database,
  TestClock? clock,
}) async {
  await setPhoneSurface(tester);
  await tester.pumpWidget(
    duoScope(
      puzzle: fixedDuoPuzzle(),
      database: database,
      clock: clock,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildNookTheme(NookColors.softClay),
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the Duo screen with a puzzle already generated.
///
/// Pass [resume] to open a saved game instead of a new one, exactly as the
/// Continue card does.
Future<void> pumpDuoGame(
  WidgetTester tester, {
  DuoPuzzle? puzzle,
  DuoSave? resume,
  NookDatabase? database,
  TestClock? clock,
  double width = 400,
  bool disableAnimations = false,
}) async {
  final DuoPuzzle fixed = puzzle ?? fixedDuoPuzzle();
  await setPhoneSurface(tester, width: width);
  await tester.pumpWidget(
    duoScope(
      puzzle: fixed,
      database: database,
      clock: clock,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildNookTheme(NookColors.softClay),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: disableAnimations),
          child: child!,
        ),
        home: DuoGamePage(
          variant: DuoVariant.standard,
          difficulty: PuzzleDifficulty.gentle,
          resume: resume,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Lets the hint control's pacing run out, so it can be used again.
///
/// The wait is four seconds of a clock the test owns, not four seconds of
/// anybody's life.
Future<void> settleHintPacing(WidgetTester tester) async {
  await tester.pump(kHintPacing);
  await tester.pumpAndSettle();
}

/// The colour the action-row control with the id [id] is filled with.
Color actionBackground(WidgetTester tester, String id) {
  return tester.widget<Material>(find.byKey(BoardActionRow.keyFor(id))).color!;
}

/// A part-played Duo puzzle, written exactly as the app would write it.
///
/// A circle and a square down on the first two free cells, with every move
/// still in the history — so a test reading it back can tell the symbols, the
/// clock and the undo stack all came home. The moves are the ones the
/// controller records for those taps, so undo across a resume walks the same
/// path a live board would.
SavedGame partPlayedDuoSave({
  Duration elapsed = const Duration(minutes: 1, seconds: 15),
  DateTime? at,
}) {
  final DuoPuzzle puzzle = fixedDuoPuzzle();
  final List<int> free = <int>[
    for (int index = 0; index < puzzle.spec.cellCount; index++)
      if (!puzzle.isGiven(index)) index,
  ];
  final List<DuoCell> cells = <DuoCell>[
    for (int index = 0; index < puzzle.spec.cellCount; index++)
      puzzle.givens[index] == null
          ? DuoCell.empty
          : DuoCell.of(puzzle.givens[index]!),
  ];
  cells[free[0]] = DuoCell.circle;
  cells[free[1]] = DuoCell.square;
  final DuoGameState game = DuoGameState(
    variant: DuoVariant.standard,
    puzzle: puzzle,
    cells: cells,
    history: MoveHistory(
      moves: <BoardMove>[
        // The first free cell tapped once: a circle.
        BoardMove(index: free[0], before: 0, after: 1),
        // The second cycled circle → square: two moves, each undoable.
        BoardMove(index: free[1], before: 0, after: 1),
        BoardMove(index: free[1], before: 1, after: 2),
      ],
    ),
  );
  return savedDuoGame(
    game,
    difficulty: PuzzleDifficulty.gentle,
    elapsed: elapsed,
    at: at ?? DateTime.utc(2026, 9, 3, 9),
  );
}

/// The save [database] holds for [gameId], or `null` if it holds none.
///
/// Read outside the test's fake clock: a query is real work on a real database
/// and has to be allowed to take the time it takes rather than waiting for a
/// frame that is never pumped.
Future<SavedGame?> storedSave(
  WidgetTester tester,
  NookDatabase database,
  String gameId,
) async {
  return tester.runAsync<SavedGame?>(() async {
    final List<SavedGame> saves = await SavedGameStore(database)
        .watchAll()
        .first;
    for (final SavedGame save in saves) {
      if (save.gameId == gameId) {
        return save;
      }
    }
    return null;
  });
}

/// Whether the action-row control with the id [id] can be used.
bool actionEnabled(WidgetTester tester, String id) {
  return tester
          .widget<InkWell>(
            find.descendant(
              of: find.byKey(BoardActionRow.keyFor(id)),
              matching: find.byType(InkWell),
            ),
          )
          .onTap !=
      null;
}

/// Taps the board cell at [index].
Future<void> tapDuoCell(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(DuoBoard.cellKey(index)));
  await tester.pump();
}

/// The symbol drawn in the cell at [index]: a circle, a square, or empty.
DuoCell duoCellAt(WidgetTester tester, int index) {
  final Finder mark = find.byKey(DuoBoard.markKey(index));
  if (mark.evaluate().isEmpty) {
    return DuoCell.empty;
  }
  return (tester.widget(mark) as Icon).icon == DuoBoard.circleIcon
      ? DuoCell.circle
      : DuoCell.square;
}

/// Drives the board to the puzzle's solution: each player cell cycled from
/// whatever it holds to its solution symbol, the givens left be.
///
/// Tapped the way a player would rather than written into the controller, so a
/// test that finishes a puzzle exercises the same path a real one takes. Read
/// off the board rather than assumed empty, so a resumed puzzle with symbols
/// already down solves the same way a fresh one does.
Future<void> solveDuo(WidgetTester tester, DuoPuzzle puzzle) async {
  for (int index = 0; index < puzzle.spec.cellCount; index++) {
    if (puzzle.isGiven(index)) {
      continue;
    }
    final DuoCell target = DuoCell.of(puzzle.solution[index]);
    await tester.ensureVisible(find.byKey(DuoBoard.cellKey(index)));
    // Counted before tapping rather than checked after each tap: the last tap
    // of the last cell solves the board, and the board is gone — replaced by
    // the finished screen — before a re-check could see the symbol land.
    final DuoCell current = duoCellAt(tester, index);
    final int taps = (target.index - current.index) % DuoCell.values.length;
    for (int t = 0; t < taps; t++) {
      await tapDuoCell(tester, index);
    }
  }
  await tester.pumpAndSettle();
}

/// Everything [database] has counted, read outside the test's fake clock.
Future<List<GameStats>> storedStats(
  WidgetTester tester,
  NookDatabase database,
) async {
  return (await tester.runAsync<List<GameStats>>(
    () => GameStatsStore(database).watchAll().first,
  ))!;
}
