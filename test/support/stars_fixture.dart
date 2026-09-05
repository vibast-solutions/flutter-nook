import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/chrome/move_history.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/stars/stars_controller.dart';
import 'package:nook/games/stars/stars_save.dart';
import 'package:nook/games/stars/stars_screen.dart';
import 'package:nook/games/stars/stars_state.dart';
import 'package:nook/games/stars/stars_variant.dart';
import 'package:nook/home/home_screen.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// The English strings, so a test can say what a screen should show without
/// writing the words out a second time.
final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

/// A Stars puzzle, the same one every run.
///
/// The engine is deterministic, so a seed names a puzzle as precisely as its
/// sixty-four region entries would, and a test that says what it wants beats a
/// wall of numbers nobody can check by eye. Its [StarsPuzzle.solution] is the
/// eight star cells a test drives the board to.
StarsPuzzle fixedStarsPuzzle() =>
    StarsGenerator(StarsSpec.standard).generate(2026);

/// The Stars variants, for a test that has to hold for all of them. One today.
const List<StarsVariant> allStarsVariants = StarsVariant.values;

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

/// Wraps [child] in what every Stars screen needs under test: a puzzle already
/// made, a database in memory, and a clock the test owns.
Widget starsScope({
  required StarsPuzzle puzzle,
  required Widget child,
  StarsPuzzleSource? source,
  NookDatabase? database,
  TestClock? clock,
}) {
  return ProviderScope(
    overrides: [
      starsPuzzleSourceProvider.overrideWithValue(
        source ??
            (StarsSpec spec, PuzzleDifficulty tier, int seed) async => puzzle,
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

/// Pumps the home screen wired to a fixed Stars puzzle.
Future<void> pumpStarsHome(
  WidgetTester tester, {
  NookDatabase? database,
  TestClock? clock,
}) async {
  await setPhoneSurface(tester);
  await tester.pumpWidget(
    starsScope(
      puzzle: fixedStarsPuzzle(),
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

/// Pumps the Stars screen with a puzzle already generated.
///
/// Pass [resume] to open a saved game instead of a new one, exactly as the
/// Continue card does.
Future<void> pumpStarsGame(
  WidgetTester tester, {
  StarsPuzzle? puzzle,
  StarsSave? resume,
  NookDatabase? database,
  TestClock? clock,
  double width = 400,
  bool disableAnimations = false,
}) async {
  final StarsPuzzle fixed = puzzle ?? fixedStarsPuzzle();
  await setPhoneSurface(tester, width: width);
  await tester.pumpWidget(
    starsScope(
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
        home: StarsGamePage(
          variant: StarsVariant.standard,
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

/// A part-played Stars puzzle, written exactly as the app would write it.
///
/// A star placed and two ruled-out dots down, with every move still in the
/// history — so a test reading it back can tell the marks, the clock and the
/// undo stack all came home. The moves are the ones the controller records for
/// those taps, so undo across a resume walks the same path a live board would.
SavedGame partPlayedStarsSave({
  Duration elapsed = const Duration(minutes: 1, seconds: 15),
  DateTime? at,
}) {
  final StarsPuzzle puzzle = fixedStarsPuzzle();
  final List<StarsMark> cells =
      List<StarsMark>.filled(puzzle.spec.cellCount, StarsMark.empty)
        ..[0] = StarsMark.star
        ..[1] = StarsMark.ruledOut
        ..[2] = StarsMark.ruledOut;
  final StarsGameState game = StarsGameState(
    variant: StarsVariant.standard,
    puzzle: puzzle,
    cells: cells,
    history: MoveHistory(
      moves: <BoardMove>[
        // Cell 0 cycled empty → dot → star: two moves, each undoable.
        const BoardMove(index: 0, before: 0, after: 1),
        const BoardMove(index: 0, before: 1, after: 2),
        // Two dots laid down.
        const BoardMove(index: 1, before: 0, after: 1),
        const BoardMove(index: 2, before: 0, after: 1),
      ],
    ),
  );
  return savedStarsGame(
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

/// Taps the board cell at [index].
Future<void> tapStarsCell(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(StarsBoard.cellKey(index)));
  await tester.pump();
}

/// The mark drawn in the cell at [index]: a star, a ruled-out cross, or empty.
StarsMark starMarkAt(WidgetTester tester, int index) {
  final Finder mark = find.byKey(StarsBoard.markKey(index));
  if (mark.evaluate().isEmpty) {
    return StarsMark.empty;
  }
  // Both a star and a ruling-out are icons now (a star and a small cross), so
  // they are told apart by which glyph, not by widget type.
  final Widget widget = tester.widget(mark);
  return widget is Icon && widget.icon == Icons.star_rounded
      ? StarsMark.star
      : StarsMark.ruledOut;
}

/// Drives the board to the puzzle's solution: two taps on each star cell
/// (empty → ruled out → star), the others left empty.
///
/// Tapped the way a player would rather than written into the controller, so a
/// test that finishes a puzzle exercises the same path a real one takes.
Future<void> solveStars(WidgetTester tester, StarsPuzzle puzzle) async {
  for (final int cell in puzzle.solution) {
    await tester.ensureVisible(find.byKey(StarsBoard.cellKey(cell)));
    await tapStarsCell(tester, cell);
    await tapStarsCell(tester, cell);
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
