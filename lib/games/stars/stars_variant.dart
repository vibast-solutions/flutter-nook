import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// Nook's Stars game, as the player meets it.
///
/// The engine only knows grid shapes; this is the layer that gives one an
/// identity and a place in the game list. It carries no words — the name a
/// player reads is translated, and lives in `stars_naming.dart`.
///
/// One variant for now, [standard]. The class exists rather than a bare
/// constant so that a second — a 10x10 two-star board, say — is a constant
/// added here and nothing else changed.
@immutable
class StarsVariant {
  const StarsVariant({required this.id, required this.spec});

  /// The identifier of [standard]. A constant so naming and (later) saves can
  /// switch on it without repeating a bare string.
  static const String starsId = 'stars';

  /// A stable identifier, used for routing and (later) saves and statistics.
  ///
  /// Never shown to a player and never translated — a save written on an
  /// English phone has to still be readable after a language switch.
  final String id;

  /// The grid shape handed to the engine.
  final StarsSpec spec;

  /// The 8x8 board Nook ships.
  static const StarsVariant standard = StarsVariant(
    id: starsId,
    spec: StarsSpec.standard,
  );

  /// Every Stars variant. One for now.
  static const List<StarsVariant> values = <StarsVariant>[standard];

  /// The variant with this [id], or `null` if no Stars game has it.
  ///
  /// `null` rather than a throw, like Sudoku's: an id can come off disk written
  /// by a build with a variant this one lacks, and a save nobody can read is a
  /// card that stays hidden rather than a crash on the home screen.
  static StarsVariant? byId(String id) {
    for (final StarsVariant variant in values) {
      if (variant.id == id) {
        return variant;
      }
    }
    return null;
  }

  /// The difficulties this game offers, easiest first.
  ///
  /// A measurement, not a wish: [StarsRater.tiersFor] says which tiers the grid
  /// can actually produce. The 8x8 spans the whole ladder.
  List<PuzzleDifficulty> get tiers => StarsRater.tiersFor(spec);

  @override
  bool operator ==(Object other) => other is StarsVariant && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StarsVariant($id)';
}
