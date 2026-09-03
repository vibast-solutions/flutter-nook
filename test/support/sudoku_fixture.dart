import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/board/number_pad.dart';
import 'package:nook/board/sudoku_board.dart';
import 'package:nook/chrome/action_row.dart';
import 'package:nook/chrome/move_history.dart';
import 'package:nook/chrome/note_marks.dart';
import 'package:nook/chrome/play_clock.dart';
import 'package:nook/design/theme.dart';
import 'package:nook/design/tokens.dart';
import 'package:nook/games/sudoku/sudoku_controller.dart';
import 'package:nook/games/sudoku/sudoku_save.dart';
import 'package:nook/games/sudoku/sudoku_screen.dart';
import 'package:nook/games/sudoku/sudoku_state.dart';
import 'package:nook/home/home_screen.dart';
import 'package:nook/games/sudoku/sudoku_variant.dart';
import 'package:nook/l10n/app_localizations.dart';
import 'package:nook/store/game_stats.dart';
import 'package:nook/store/nook_database.dart';
import 'package:nook/store/saved_game.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// The English strings, for a test that wants to say what a screen should show
/// without writing the words out a second time.
///
/// English is what the app ships, so the assertions below still read as plain
/// sentences; going through the lookup is what keeps them honest if a word
/// changes in the `.arb` and nowhere else.
final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

/// A 4x4 puzzle with a known solution, so a test can say what it expects.
///
/// Six givens, which is the minimal set that still pins this solution — the
/// state tests assert that, so a careless edit here is caught rather than
/// quietly weakening every test that depends on it.
SudokuPuzzle fixedMiniPuzzle() {
  return SudokuPuzzle(
    spec: SudokuSpec.mini,
    seed: 0,
    difficulty: PuzzleDifficulty.gentle,
    givens: <int>[
      0, 0, 0, 0, //
      0, 0, 1, 2, //
      0, 1, 0, 3, //
      0, 3, 2, 0, //
    ],
    solution: <int>[
      1, 2, 3, 4, //
      3, 4, 1, 2, //
      2, 1, 4, 3, //
      4, 3, 2, 1, //
    ],
  );
}

/// The fixture 4x4 with a solution that is not its own.
///
/// A deliberately inconsistent puzzle, and the point of it: anything on the
/// board that is supposed to read only the grid and the rules has to behave
/// identically whatever the solution says. A test that swaps the solution and
/// sees the board change has caught a reading that should not be there.
SudokuPuzzle miniWithAnotherSolution() {
  final SudokuPuzzle real = fixedMiniPuzzle();
  return SudokuPuzzle(
    spec: real.spec,
    seed: real.seed,
    difficulty: real.difficulty,
    givens: real.givens,
    solution: real.solution.reversed.toList(),
  );
}

/// A puzzle for [variant], the same one every run.
///
/// The 6x6 and 9x9 grids are generated rather than written out: the engine is
/// deterministic, so a seed names a puzzle as precisely as eighty-one digits
/// would, and a test that says what it wants beats a wall of numbers nobody
/// can check by eye. The 4x4 keeps its handwritten one, which several tests
/// assert exact answers against.
SudokuPuzzle fixedPuzzle(SudokuVariant variant) {
  if (variant == SudokuVariant.mini) {
    return fixedMiniPuzzle();
  }
  return SudokuGenerator(variant.spec)
      .generateAt(PuzzleDifficulty.gentle, 2026);
}

/// The three Sudokus, for a test that has to hold for all of them.
const List<SudokuVariant> allVariants = SudokuVariant.values;

/// A clock the test winds on by hand.
///
/// Time is the one thing a puzzle depends on that a test cannot wait for: a
/// timer test that slept for its assertions would take as long as the durations
/// it is checking.
class TestClock {
  TestClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 9, 2, 9);

  DateTime _now;

  /// The current instant, as [nowProvider] wants it.
  DateTime call() => _now;

  /// Moves the world forward.
  void advance(Duration by) => _now = _now.add(by);
}

/// A database that lives in memory and goes away with the test.
///
/// The real schema and the real SQL, so a test that saves a game exercises
/// what the app will run rather than a stand-in that always agrees with it.
NookDatabase memoryDatabase() {
  // Every test makes its own, which is exactly what the warning is about and
  // exactly what a test should do.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final NookDatabase database = NookDatabase.memory();
  addTearDown(database.close);
  return database;
}

/// The marks a part-played fixture pencils into one cell.
final NoteMarks pencilledMarks = NoteMarks.of(<int>[2, 3]);

/// A part-played Sudoku Mini, written exactly as the app would write it.
///
/// One answer entered, one cell pencilled in, and both moves still in the
/// history — so a test reading it back can tell which of the three came home
/// and which did not.
SavedGame partPlayedMiniSave({
  Duration elapsed = const Duration(minutes: 1, seconds: 30),
  DateTime? at,
}) {
  final SudokuPuzzle puzzle = fixedMiniPuzzle();
  final SudokuGameState game = SudokuGameState(
    variant: SudokuVariant.mini,
    puzzle: puzzle,
    cells: List<int>.of(puzzle.givens)..[0] = 1,
    notes: List<int>.filled(puzzle.givens.length, 0)..[4] = pencilledMarks.mask,
    history: MoveHistory(
      moves: <BoardMove>[
        const BoardMove(index: 0, before: 0, after: 1),
        BoardMove(
          index: 4,
          before: 0,
          after: 0,
          notesAfter: pencilledMarks.mask,
        ),
      ],
    ),
  );
  return savedGameFor(
    game,
    difficulty: PuzzleDifficulty.gentle,
    elapsed: elapsed,
    at: at ?? DateTime.utc(2026, 9, 2, 9),
  );
}

/// Fills in every blank on the board correctly, finishing the puzzle.
///
/// Tapped cell by cell the way a player would, so a test that finishes a
/// puzzle exercises the same path a real one takes rather than writing a
/// solved state into the controller.
Future<void> solvePuzzle(WidgetTester tester, SudokuPuzzle puzzle) async {
  for (int index = 0; index < puzzle.givens.length; index++) {
    if (puzzle.givens[index] != 0 || digitIn(tester, index) != null) {
      continue;
    }
    await tapCell(tester, index);
    await tapDigit(tester, puzzle.solution[index]);
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

/// The save [database] holds for [gameId], or `null` if it holds none.
///
/// Read outside the test's fake clock: a query is real work on a real
/// database, and it has to be allowed to take the time it takes rather than
/// waiting for a frame that is never pumped.
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

/// Wraps [child] in what every Nook screen needs under test: a puzzle that is
/// already made, a database in memory, and a clock the test owns.
///
/// Pass [source] instead of relying on [puzzle] to watch what the generator is
/// asked for. The database matters even to a test that never mentions saving:
/// a screen that reads the real one would go looking for a file that a test
/// has no business having.
Widget nookScope({
  required SudokuPuzzle puzzle,
  required Widget child,
  SudokuPuzzleSource? source,
  NookDatabase? database,
  TestClock? clock,
}) {
  return ProviderScope(
    overrides: [
      sudokuPuzzleSourceProvider.overrideWithValue(
        source ??
            (SudokuSpec spec, PuzzleDifficulty tier, int seed) async => puzzle,
      ),
      nookDatabaseProvider.overrideWithValue(database ?? memoryDatabase()),
      nowProvider.overrideWithValue((clock ?? TestClock()).call),
    ],
    child: child,
  );
}

/// Gives the test a phone-shaped window, so a board and its pad both fit and
/// taps are not swallowed by an off-screen scroll position.
///
/// [width] defaults to a common phone; pass [kSmallestSupportedWidth] to check
/// the layout where it is tightest.
Future<void> setPhoneSurface(WidgetTester tester, {double width = 400}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Taps the board cell at [index].
Future<void> tapCell(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(SudokuBoard.cellKey(index)));
  await tester.pump();
}

/// Taps the number-pad key for [digit].
Future<void> tapDigit(WidgetTester tester, int digit) async {
  await tester.tap(find.byKey(NumberPad.keyFor(digit)));
  await tester.pump();
}

/// Lets the hint control's pacing run out, so it can be used again.
///
/// The wait is four seconds of a clock the test owns, not four seconds of
/// anybody's life.
Future<void> settleHintPacing(WidgetTester tester) async {
  await tester.pump(kHintPacing);
  await tester.pumpAndSettle();
}

/// Taps the hint control and waits out the pacing that follows it.
Future<void> tapHint(WidgetTester tester) async {
  await tapAction(tester, 'hint');
  await settleHintPacing(tester);
}

/// Pencils [digits] into the cell at [index], leaving the pad in answer mode.
Future<void> pencilInto(
  WidgetTester tester,
  int index,
  List<int> digits,
) async {
  await tapCell(tester, index);
  await tapAction(tester, 'notes');
  for (final int digit in digits) {
    await tapDigit(tester, digit);
  }
  await tapAction(tester, 'notes');
}

/// Writes [digit] into the cell at [index].
Future<void> answer(WidgetTester tester, int index, int digit) async {
  await tapCell(tester, index);
  await tapDigit(tester, digit);
}

/// Taps the action-row control with the id [id].
///
/// Controls are found by id rather than by the word on them: the word is
/// translated, and a test that hunted for it would only pass in English.
Future<void> tapAction(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(BoardActionRow.keyFor(id)));
  await tester.pump();
}

/// The colour the action-row control with the id [id] is filled with.
Color actionBackground(WidgetTester tester, String id) {
  return tester.widget<Material>(find.byKey(BoardActionRow.keyFor(id))).color!;
}

/// Every digit on the board, with `null` for an empty cell.
List<String?> boardDigits(WidgetTester tester) {
  return <String?>[for (int i = 0; i < 16; i++) digitIn(tester, i)];
}

/// The digit currently drawn in the cell at [index], or `null` if it is empty.
String? digitIn(WidgetTester tester, int index) {
  final Finder text = find.byKey(SudokuBoard.valueKey(index));
  if (text.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<Text>(text).data;
}

/// The pencil marks drawn in the cell at [index], smallest first.
List<int> notesIn(WidgetTester tester, int index) {
  final Finder marks = find.descendant(
    of: find.byKey(SudokuBoard.notesKey(index)),
    matching: find.byType(Text),
  );
  return <int>[
    for (final Text mark in tester.widgetList<Text>(marks))
      int.parse(mark.data!),
  ];
}

Future<void> pumpHome(
  WidgetTester tester, {
  SudokuVariant variant = SudokuVariant.mini,
  NookDatabase? database,
  TestClock? clock,
}) async {
  await setPhoneSurface(tester);
  final SudokuPuzzle fixed = fixedPuzzle(variant);
  await tester.pumpWidget(
    nookScope(
      puzzle: fixed,
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

/// Pumps the Sudoku screen with a puzzle already generated.
///
/// Generation is replaced rather than awaited: the tests here are about what
/// happens once a player has a board, and the real generator has its own
/// exhaustive tests in the engine package.
Future<void> pumpSudokuGame(
  WidgetTester tester, {
  SudokuVariant variant = SudokuVariant.mini,
  PuzzleDifficulty difficulty = PuzzleDifficulty.gentle,
  SudokuPuzzle? puzzle,
  SudokuSave? resume,
  NookDatabase? database,
  TestClock? clock,
  double width = 400,
  double textScale = 1,
  bool disableAnimations = false,
}) async {
  final SudokuPuzzle fixed = puzzle ?? fixedPuzzle(variant);
  await setPhoneSurface(tester, width: width);
  await tester.pumpWidget(
    nookScope(
      puzzle: fixed,
      database: database,
      clock: clock,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: buildNookTheme(NookColors.softClay),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child!,
        ),
        home: SudokuGamePage(
          variant: variant,
          difficulty: difficulty,
          resume: resume,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
