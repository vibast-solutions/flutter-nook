# Nook

A free puzzle collection for iOS and Android.

**No ads. No tracking. No account. Ever.** Nothing that affects play is ever
behind a payment, and the app makes no network requests — puzzles are generated
on your device.

Built with Flutter.

## What is here

| Path | What it holds |
| --- | --- |
| `packages/puzzle_engine/` | The rules: solvers and generators. Pure Dart, no Flutter. |
| `lib/design/` | Colour tokens, type ramp, themes. |
| `lib/board/` | Board and number-pad widgets, shared across games. |
| `lib/games/` | Per-game state and screens. |
| `lib/home/` | The game list. |
| `assets/fonts/` | Nunito and Fredoka, bundled rather than fetched. |

## Guarantees

Two promises hold for every puzzle in Nook, and both are checked by tests
rather than assumed:

- **Exactly one solution.** You will never have to guess, because there is
  never more than one answer.
- **Reproducible from a seed.** The same seed produces the same puzzle on every
  platform and every run, which is what will let the daily puzzle be identical
  worldwide without a server.

## Working on it

```bash
flutter pub get
flutter analyze && flutter test              # the app
cd packages/puzzle_engine
dart pub get && dart analyze && dart test    # the rules
```

`dart format` is enforced in CI for both.

## Fonts

Nunito and Fredoka are used under the SIL Open Font License. The licence texts
are in `assets/fonts/` next to the font files.
