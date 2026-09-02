# Nook

A free puzzle collection for iOS and Android. No ads, no tracking, no account — and nothing that affects play is ever behind a payment.

## Stack

- **Flutter / Dart.** One codebase, both platforms.
- **No backend, no network.** Puzzles are generated on the device; the daily puzzle is derived from the date. The only network traffic is the app store's own purchase flow.
- **No third-party SDKs.** No analytics, no attribution, no crash reporting. Every dependency is reviewed individually.

## Layout

```
packages/puzzle_engine/   pure Dart, no Flutter — solvers, generators, difficulty rating
  bin/generate.dart       CLI: batch-produce bundled starter packs (not built yet)
lib/                      the app
  design/                 tokens, themes, typography
  board/                  shared board widgets, selection, gestures
  chrome/                 controls around a board: undo, erase and notes, later timer/hints
  games/                  per-game state and screens (thin)
  home/                   the game list
  l10n/                   app_en.arb (the words) + the generated AppLocalizations
  store/                  persistence (Drift/SQLite) (not built yet)
  content/                bundled pack loading (not built yet)
assets/fonts/             Nunito + Fredoka, bundled
assets/packs/             generated starter packs (not built yet)
```

Directories marked "not built yet" are in the plan but have no code; create them
when the ticket that needs them comes up, not before.

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
- **A cell shows an answer or its pencil marks, never both.** Both are kept, so
  an undo can bring the marks back, but an answer is what the cell draws.
- Generation runs on a background isolate; the UI never blocks.
- Region colours are always paired with a texture, so colour-blind players can read the board.
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

## Commands

```
flutter analyze && flutter test          # the app
dart analyze && dart test                # from packages/puzzle_engine
flutter gen-l10n                         # after editing lib/l10n/*.arb
```

CI also runs `dart format --output=none --set-exit-if-changed`, so format
before pushing.

Never launch the app from an agent session — build, test and lint only.
