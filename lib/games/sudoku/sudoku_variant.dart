import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// One of Nook's three Sudoku sizes, as the player meets it.
///
/// The engine only knows box shapes; this is the layer that gives a shape an
/// identity and a place in the game list. It deliberately carries no words:
/// the name a player reads is translated, and lives in `sudoku_naming.dart`.
@immutable
class SudokuVariant {
  const SudokuVariant({required this.id, required this.spec});

  /// The identifier of [mini]. A constant so that naming and (later) saves can
  /// switch on it without repeating a bare string.
  static const String miniId = 'sudoku-mini';

  /// The identifier of [light].
  static const String lightId = 'sudoku-light';

  /// The identifier of [classic].
  static const String classicId = 'sudoku-classic';

  /// A stable identifier, used for routing and (later) saves and statistics.
  ///
  /// Never shown to a player, and never translated — a save written on an
  /// English phone has to still be readable after the player switches
  /// language.
  final String id;

  /// The grid shape handed to the engine.
  final SudokuSpec spec;

  /// Sudoku Mini — 4x4.
  static const SudokuVariant mini = SudokuVariant(
    id: miniId,
    spec: SudokuSpec.mini,
  );

  /// Sudoku Light — 6x6.
  static const SudokuVariant light = SudokuVariant(
    id: lightId,
    spec: SudokuSpec.light,
  );

  /// Sudoku Classic — 9x9.
  static const SudokuVariant classic = SudokuVariant(
    id: classicId,
    spec: SudokuSpec.classic,
  );

  /// The three Sudokus, smallest first.
  static const List<SudokuVariant> values = <SudokuVariant>[
    mini,
    light,
    classic,
  ];

  /// The variant with this [id], or `null` if no Sudoku has it.
  ///
  /// `null` rather than a throw: an id can come off disk, written by a build
  /// that had a variant this one does not, and a save nobody can read is a card
  /// that stays hidden rather than a crash on the home screen.
  static SudokuVariant? byId(String id) {
    for (final SudokuVariant variant in values) {
      if (variant.id == id) {
        return variant;
      }
    }
    return null;
  }

  /// The difficulties this grid can actually produce, easiest first.
  ///
  /// Not every size spans the whole ladder — the engine measured which ones do
  /// — and a tier that cannot be generated is one the screen must not offer.
  List<SudokuDifficulty> get tiers => SudokuRater.tiersFor(spec);

  @override
  bool operator ==(Object other) => other is SudokuVariant && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SudokuVariant($id)';
}
