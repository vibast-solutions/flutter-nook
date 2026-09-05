# Nook

A free puzzle collection for iOS and Android. No ads, no tracking, no account — and nothing that affects play is ever behind a payment.

## Stack

- **Flutter / Dart.** One codebase, both platforms.
- **No backend, no network.** Puzzles are generated on the device; the daily puzzle is derived from the date. The only network traffic is the app store's own purchase flow.
- **No third-party SDKs.** No analytics, no attribution, no crash reporting. Every dependency is reviewed individually.

## Layout

```
packages/puzzle_engine/   pure Dart, no Flutter — solvers, generators, difficulty rating
  bin/generate.dart       CLI: batch-produce bundled starter packs
  lib/src/pack/           the pack format (shared by the CLI and the app)
lib/                      the app
  design/                 tokens, themes, typography
  board/                  shared board widgets, selection, gestures
  chrome/                 the furniture around a game: undo, erase, notes, the
                          clock, the Continue card, the discard question
  games/                  per-game state and screens (thin)
  home/                   the game list
  l10n/                   app_en.arb (the words) + the generated AppLocalizations
  store/                  persistence: the Drift database, saved games,
                          the solved counts and best times, and the pack cursor
  content/                bundled pack loading, and the pack-first puzzle source
assets/fonts/             Nunito + Fredoka, bundled
assets/packs/             generated starter packs (regenerated, never hand-edited)
```

## Rules that matter

- **`puzzle_engine` must not import `package:flutter`**, touch the filesystem, or read the clock. All randomness comes from a seeded generator passed in by the caller — the same seed must always produce the same puzzle, on every platform.
- **Every generated puzzle has exactly one solution and is solvable without guessing.** This is verified in tests, not assumed.
- **Two solvers, two jobs.** `SudokuSolver` searches and backtracks, and exists
  to answer "how many solutions?" for the uniqueness guarantee.
  `SudokuLogicSolver` only makes deductions a person could make and **never
  guesses or backtracks** — which is what makes its verdict a measure of human
  difficulty. Never reach for the searching one to rate a puzzle.
- **Difficulty is rated by the techniques a human solver needs**, never by clue
  count. A puzzle the technique solver cannot finish is **discarded, never
  promoted to a harder tier** — that is the whole of the no-guessing guarantee.
- **Tier boundaries live in one place** (`DifficultyBoundaries`) because they
  are expected to move. The committed corpus in
  `packages/puzzle_engine/test/sudoku/difficulty_corpus.dart` makes any move
  show up as a diff that has to be looked at, so retuning can never be quiet.
- **A grid only offers the tiers it can actually generate**, and which those are
  is a measurement rather than a decision — `SudokuRater.tiersFor`. A 4x4 is
  Gentle however hard you carve it, and a 6x6 has no middle to its ladder.
  Offering five buttons that hand back the same puzzle would be worse than a
  short list.
- **Boards are built from widgets, not CustomPainter** — accessibility semantics, hit testing and per-cell animation come free. Purely decorative chrome with nothing to hit or read out (the dashed rule on the difficulty screen's guarantee card) may still paint.
- **Every move a player makes goes through one write** that records it in the
  shared `MoveHistory` (`chrome/move_history.dart`). A game never grows an undo
  stack of its own, and a move is a handful of plain integers — which cell, what
  it held, and the pencil marks around it as a `NoteMarks` bitmask — because it
  has to survive being written to disk when a game is saved and resumed.
- **Undo is the strict inverse of one move, and every control obeys that.** One
  move is one thing the player did, even when it changed cells they never
  touched: writing a digit **rubs that digit out of the pencil marks of every
  cell in its row, column and box**, and the cells it took them from ride along
  on the move in `BoardMove.clearedNotes` so undo can put them back exactly.
  That tidying reads the digit the player claimed and the shape of the grid,
  never `puzzle.solution` — a wrong digit tidies exactly as a right one does,
  because the app is applying the claim rather than the truth. Erase and
  clearing a cell by re-tapping its digit are moves *forward*: they take the
  digit out and leave the tidying alone, because a control that reversed a move
  it did not make would make undo the only thing nobody could predict.
- **The board marks a repeated digit, and only ever a repeated digit.** A cell
  conflicts when another cell in its row, column or box holds the same digit;
  both halves are marked, givens included, because deciding which of the two is
  the intruder would mean knowing the answer. A digit that disagrees with the
  solution but repeats nothing is silent. The same reasoning sets the trigger
  for the completed-unit pulse: *full and free of repeats*, never *correct*.
  Both are computed on `SudokuGameState` from the grid alone, and the tests
  swap the puzzle's solution for a different one and assert that nothing on the
  board changes — which is the guard that no solution reading ever creeps in.
- **Colour never carries a meaning by itself.** A conflicting cell is hatched
  as well as washed (`_ConflictHatch`), the way region colours are, so the
  board is readable without reading colour.
- **Motion is optional and the words are not.** Anything that moves — the
  completed-unit pulse, the cross a hint draws over a wrong digit, the hint
  control's colour wiping back in — checks `MediaQuery.disableAnimations` and
  simply does not draw. What a screen reader is told never depends on that
  setting: a cell a hint emptied says so either way.
- **A hint is the player's next move, not a reveal.** With a wrong digit on the
  board it **takes one away** — the most recently entered, crossed out in red
  and faded off — and reveals nothing; with none, it fills in a cell the player
  could have deduced, chosen by the same technique solver that measures
  difficulty (`SudokuHinter`), never at random. Removing first is what stops
  the app contradicting itself: a digit revealed into a unit already poisoned
  by a mistake would be marked as a conflict by the same board that had just
  given it. Inside the engine a mistake is still reasoned *around* rather than
  reasoned *from* — one wrong digit makes the rest of the grid unsolvable, so a
  solver fed it would deduce a run of wrong cells — and the hinter never writes
  over a filled cell; what to do about a mistake is the app's decision, made
  before it asks. Either kind of hint counts as help, so the puzzle sets no
  personal best.
- **This is the only place Nook judges an entry against the solution, and it
  happens because the player asked.** The board never volunteers it: no "check
  my work", no wrong-digit marking, no correctness animation. Nothing is
  protected by that — unlimited hints could always reveal any cell — but a
  board that graded silently would be an oracle to brute-force rather than a
  puzzle to solve.
- **Hints are unlimited and free**: nothing is gated, sold, counted, spent or
  rationed, and none of that is ever to be added. The control does **pace**
  itself — it waits `kHintPacing` (four seconds) after each one, greyed with
  its colour wiping back in from the left. That is the room a hint needs to
  land, and what stops removal-by-hint becoming a guess-and-check rhythm; it is
  the same wait for everybody, every time, for ever. It lives on `BoardAction`
  in `chrome/action_row.dart` so every game inherits it.
- **Finishing is the one moment Nook never spends.** The finished-puzzle
  screen asks nothing: no rating prompt, no tip, no "enjoying Nook?", no
  promotion of anything. It says what the player did, offers another puzzle,
  and gets out of the way. This is a feature, not a gap waiting to be filled,
  and `test/games/sudoku_completion_test.dart` counts the controls on it so
  that a third one cannot appear quietly.
- **A finished puzzle takes the whole screen.** The board it was played on has
  nothing left to do and the clock has stopped, so both give way rather than
  sitting there greyed out — and the next puzzle starts on a clock at zero
  (`PlayClock.restart`), because a new puzzle is a new time.
- **Statistics are a count and a best time, per game and per tier, and
  nothing else.** No record is kept of an individual solve, there is no
  failure statistic anywhere (an abandoned puzzle is simply not recorded), and
  nothing is ever compared with anybody else — the only thing a player is
  measured against is themselves, last time. **A hinted puzzle counts as
  solved, keeps its time, and never sets a best**, which is what
  `SavedGame.wasHinted` is for.
- **The screen is told its figures by the write that produced them.** The time
  a player has just beaten stops existing the moment the new best is stored,
  so `GameStatsStore.record` reads and writes in one transaction and hands
  back a `SolveOutcome`. Only the difficulty screen, which is looking at
  history rather than at a result, reads the figures back.
- **A cell shows an answer or its pencil marks, never both.** Both are kept, so
  an undo can bring the marks back, but an answer is what the cell draws.
- Generation runs on a background isolate; the UI never blocks.
- **Bundled packs are a cache, not content (VIB-78).** The first tap after a
  cold launch is instant because a few dozen pre-generated puzzles per slow
  game and tier ship as gzipped assets in `assets/packs/`. A game start takes
  the next unused pack puzzle and **falls back to on-device generation** when
  the pack is spent or absent — and the fallback is the normal state after the
  first few games, never an error path, so nothing may break if `assets/packs/`
  is empty. Only the grids and tiers a player would actually wait for are
  packed (measured in VIB-78: 9×9 medium/hard/fiendish and Stars
  easy/medium/hard/fiendish); the instant ones generate on the device, where a
  pack would be pure cost.
- **The pack format lives in the engine, so the CLI and the app share one
  implementation** (`packages/puzzle_engine/lib/src/pack/`). A record is its
  seed, its givens (or region map), and the techniques the solver needed — the
  solution is *not* stored, because every pack puzzle is guess-free and the app
  recovers the one solution with the same solver that proved it unique. The
  text is line-oriented (one puzzle per line, sorted by seed) so a pack change
  reviews as "these puzzles changed"; gzipping happens at the edges because the
  engine stays free of `dart:io`.
- **Packs are regenerated, never hand-edited, and byte-identical from a fixed
  seed.** `dart run puzzle_engine:generate` writes them; a CI job of its own
  reruns it and fails if a byte differs, which both keeps the committed packs
  honest and exercises the CLI so it cannot rot as the engine changes.
  `test/content/packs_test.dart` loads every shipped pack and asserts each
  puzzle is unique and rates at its stated tier — a pack that ships a wrong
  puzzle fails CI.
- **A puzzle handed out from a pack is never handed out again while unplayed
  ones remain.** `pack_progress` (schema v5) is a per-pack served-cursor: the
  packs are handed out in order and the cursor only moves forward, so the rule
  costs one small durable integer per pack. The pack-first puzzle source is
  wired in at the app root (`main.dart`); tests build their own scope and keep
  the plain generator unless they ask for the packs.
- **A Stars region's identity is carried by its heavy boundary, not its colour.** Each region is walled off from its neighbours by the `boardRule` (the same rule as the board's frame), so a player who cannot tell the fills apart still reads every region by tracing its walls — colour and fill are decorative over that. The board used to also print a per-region texture as a second colour-free cue; it was removed (polish, 2026-09) because eight hatches at once buried the fills and read as noise. The one-texture-per-region mapping (`regionTextureFor`, `RegionTexture`) is kept and still tested so a future theme can draw it again, but nothing paints it today. (The conflict/breach hatch is unrelated and stays — colour never carries *that* meaning alone.)
- **Hit targets are never below 44 logical pixels** (`kMinTapTarget`), measured
  at `kSmallestSupportedWidth`. Board cells are the one exception, and only
  because nine of them across a phone cannot each be 44 wide — they take as
  much of the width as the page can spare instead.
- **A board sizes its own type and ignores the system text scale.** Every glyph
  on it is a fraction of a cell and a cell is a fraction of the screen, so
  scaling it again only pushes digits out of the squares that hold them.
  Everything outside a board scales normally.
- **No network requests, including fonts.** Nunito and Fredoka are bundled
  assets, not `google_fonts` downloads. Both are variable fonts, so a weight is
  set through `fontVariations` as well as `fontWeight` — use `nookText` /
  `NookType` rather than a bare `TextStyle`, or every weight renders the same.
  A bundled font is a subset of Unicode, so `test/design/font_coverage_test.dart`
  reads the `cmap` of each one and checks it against the characters the `.arb`
  actually ships. Fredoka has no Latin Extended-A and so cannot set Czech or
  Romanian; that is recorded as an equality in the same test, so swapping a
  font is loud in either direction. What to do about it is VIB-82.
- **Every word a player can read lives in `lib/l10n/app_en.arb`**, including
  the `Semantics` labels — those are player-facing even though they never
  appear on screen. Screens resolve them through
  `AppLocalizations.of(context)`. This is enforced rather than trusted: every
  string literal in `lib/` has to be either a translated message or on the
  allowlist in `test/l10n/no_untranslated_strings_test.dart`, which is the
  complete inventory of strings that are not words. English is the only locale
  filled in; a new language is one `.arb` file.
- **A label with something in the middle of it is one ICU message with
  placeholders**, never translated fragments glued together — where a number
  or a name falls in a sentence is a property of the language. Anything with a
  count in it is an ICU `plural`, even where English needs only one form.
  After editing an `.arb`, run `flutter gen-l10n`; the generated files are
  committed so a checkout analyses without a build step.
- **`puzzle_engine` carries no words.** Its enums are nameless and the app
  names them in `games/sudoku/sudoku_naming.dart` — a name a player reads has
  to be translated, and the package cannot import Flutter. The engine's own
  strings (`toString`, exceptions) use `.name`, which is an identifier.
- **Widget keys and saved-game ids are never built from a label.** A key made
  of translated text changes with the player's language, so a test that looked
  for it would pass or fail by locale. `BoardAction` carries an `id` for this.
- **Screens never write a literal colour.** They read tokens from
  `Theme.of(context).nook`, so adding a theme means adding a `NookColors`
  instance and touching no screen.
- A Riverpod provider that reads a scoped provider (one overridden by a
  `ProviderScope` further down the tree) must declare it in `dependencies:`.
  Without that it resolves in the root container and silently gets the wrong
  value — see `sudokuControllerProvider`.
- **A provider may not be written to while the widget tree is.** `initState`
  and `dispose` are both build lifecycles, so anything a screen has to start
  or stop there must not publish state — see `PlayClock`, where only the tick
  and an explicit pause do, and a resumed puzzle's starting time arrives
  through a scoped provider rather than being written in after the fact.
- **A saved game stores the grids, not just the seed.** A puzzle is
  reproducible from its seed, but restoring one that way would make every save
  in the world depend on the generator behaving identically for ever: one
  change to the carving order and a player's entries come back sitting on
  somebody else's givens. The seed is kept as provenance.
- **`lib/store/` knows nothing about any one game.** A `SavedGame` holds a game
  id, a tier name and lists of small integers, because that describes a saved
  Sudoku, Stars and Duo alike. `games/sudoku/sudoku_save.dart` is where those
  identifiers become types again, and it returns `null` rather than throwing
  for anything it cannot read: a save can outlive the build that wrote it.
- **Progress is saved as it happens, by `SudokuSession`.** Every change is
  written, so there is no such thing as an unsaved move and nothing depends on
  the app being closed politely. Solving discards the save instead of writing
  it. Persistence lives beside the screen rather than in the controller,
  because the controller is a pure transformation of state and is tested
  without pumping a frame.
- **A hinted cell is marked while it holds its digit; a hinted puzzle stays
  hinted for ever.** `SudokuGameState.hints` is the cells still showing a hint,
  and anything written into one — including an undo — hands the cell back to
  the player. `wasHinted` is sticky, because a revealed cell cannot be
  un-revealed by taking it back: it is what tells statistics (VIB-77) that the
  time still counts but the personal best does not.
- **Elapsed time is accumulated from intervals, never measured from a start
  timestamp.** A puzzle opened before bed and finished at breakfast has been
  played for four minutes, not nine hours.
- **A tier that has been played talks about the player; one that has not
  talks about the puzzle.** The line under a difficulty is the best time and
  the count once there is one, and what the tier feels like before that —
  "not solved yet" is true and tells a player choosing a tier for the first
  time nothing at all.
- **A schema change ships with its migration and a test that runs it.**
  `test/store/migration_test.dart` writes the old schema out by hand, puts a
  row in it and opens the database through the app's own code, because the
  thing being protected is a puzzle already on somebody's phone. The old DDL
  in that test is a record of what shipped and does not get updated when the
  current schema moves.
- **A widget test that touches the database uses `NookDatabase.memory()`**
  (through `nookScope` in the fixture), which closes its query streams
  synchronously. Drift normally waits an event loop before letting a stream
  go, and a timer outliving a widget test is what the test framework fails a
  test for. Reads from a test go through `storedSave`, which runs outside the
  fake clock.

## Commands

```
flutter analyze && flutter test          # the app
dart analyze && dart test                # from packages/puzzle_engine
flutter gen-l10n                         # after editing lib/l10n/*.arb
dart run build_runner build              # after editing lib/store/*.dart
dart run puzzle_engine:generate          # regenerate assets/packs (from the
                                         # engine dir, or with --out; never edit
                                         # a pack by hand)
```

The Drift mapping (`lib/store/nook_database.g.dart`) is generated and
committed, like the localisations, so a checkout analyses without a build
step. Change a table, run `build_runner`, commit both files.

CI also runs `dart format --output=none --set-exit-if-changed`, so format
before pushing.

Never launch the app from an agent session — build, test and lint only.
