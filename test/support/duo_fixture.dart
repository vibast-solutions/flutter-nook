import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/duo_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/duo/duo_controller.dart';
import 'package:nook/games/duo/duo_screen.dart';
import 'package:nook/games/duo/duo_state.dart';
import 'package:nook/games/duo/duo_variant.dart';
import 'package:nook/home/home_screen.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';
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
Future<void> pumpDuoGame(
  WidgetTester tester, {
  DuoPuzzle? puzzle,
  NookDatabase? database,
  TestClock? clock,
  double width = 400,
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
        home: DuoGamePage(
          variant: DuoVariant.standard,
          difficulty: PuzzleDifficulty.gentle,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

/// Drives the board to the puzzle's solution: each player cell tapped up to its
/// solution symbol (once for a circle, twice for a square), the givens left be.
///
/// Tapped the way a player would rather than written into the controller, so a
/// test that finishes a puzzle exercises the same path a real one takes.
Future<void> solveDuo(WidgetTester tester, DuoPuzzle puzzle) async {
  for (int index = 0; index < puzzle.spec.cellCount; index++) {
    if (puzzle.isGiven(index)) {
      continue;
    }
    final int taps = puzzle.solution[index] == DuoSymbol.circle ? 1 : 2;
    await tester.ensureVisible(find.byKey(DuoBoard.cellKey(index)));
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
