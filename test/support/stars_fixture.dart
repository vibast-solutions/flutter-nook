import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/stars_board.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/stars/stars_controller.dart';
import 'package:nook/games/stars/stars_screen.dart';
import 'package:nook/games/stars/stars_state.dart';
import 'package:nook/games/stars/stars_variant.dart';
import 'package:nook/home/home_screen.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';
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
Future<void> pumpStarsGame(
  WidgetTester tester, {
  StarsPuzzle? puzzle,
  NookDatabase? database,
  TestClock? clock,
  double width = 400,
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
        home: const StarsGamePage(
          variant: StarsVariant.standard,
          difficulty: PuzzleDifficulty.gentle,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Taps the board cell at [index].
Future<void> tapStarsCell(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(StarsBoard.cellKey(index)));
  await tester.pump();
}

/// The mark drawn in the cell at [index]: a star, a ruled-out dot, or empty.
StarsMark starMarkAt(WidgetTester tester, int index) {
  final Finder mark = find.byKey(StarsBoard.markKey(index));
  if (mark.evaluate().isEmpty) {
    return StarsMark.empty;
  }
  return tester.widget(mark) is Icon ? StarsMark.star : StarsMark.ruledOut;
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
