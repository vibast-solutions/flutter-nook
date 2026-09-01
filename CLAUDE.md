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
  chrome/                 controls around a board: undo and erase, later timer/notes/hints
  games/                  per-game state and screens (thin)
  home/                   the game list
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
- **Difficulty is rated by the techniques a human solver needs**, never by clue count.
- **Boards are built from widgets, not CustomPainter** — accessibility semantics, hit testing and per-cell animation come free.
- **Every move a player makes goes through one write** that records it in the
  shared `MoveHistory` (`chrome/move_history.dart`). A game never grows an undo
  stack of its own, and a move is three plain integers — it has to survive
  being written to disk when a game is saved and resumed.
- Generation runs on a background isolate; the UI never blocks.
- Region colours are always paired with a texture, so colour-blind players can read the board.
- Hit targets are never below 44 logical pixels (`kMinTapTarget`).
- **No network requests, including fonts.** Nunito and Fredoka are bundled
  assets, not `google_fonts` downloads. Both are variable fonts, so a weight is
  set through `fontVariations` as well as `fontWeight` — use `nookText` /
  `NookType` rather than a bare `TextStyle`, or every weight renders the same.
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
```

Never launch the app from an agent session — build, test and lint only.
