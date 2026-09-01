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
lib/                      the app
  design/                 tokens, themes, typography
  board/                  shared board widgets, selection, gestures
  chrome/                 timer, undo, notes, hints
  games/                  per-game screens (thin)
  store/                  persistence (Drift/SQLite)
  content/                bundled pack loading
assets/packs/             generated starter packs
```

## Rules that matter

- **`puzzle_engine` must not import `package:flutter`**, touch the filesystem, or read the clock. All randomness comes from a seeded generator passed in by the caller — the same seed must always produce the same puzzle, on every platform.
- **Every generated puzzle has exactly one solution and is solvable without guessing.** This is verified in tests, not assumed.
- **Difficulty is rated by the techniques a human solver needs**, never by clue count.
- **Boards are built from widgets, not CustomPainter** — accessibility semantics, hit testing and per-cell animation come free.
- Generation runs on a background isolate; the UI never blocks.
- Region colours are always paired with a texture, so colour-blind players can read the board.
- Hit targets are never below 44 logical pixels.

## Commands

```
flutter analyze && flutter test          # the app
dart analyze && dart test                # from packages/puzzle_engine
```

Never launch the app from an agent session — build, test and lint only.
