import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// Nook's Duo game, as the player meets it.
///
/// The engine only knows grid shapes; this is the layer that gives one an
/// identity and a place in the game list. It carries no words — the name a
/// player reads is translated, and lives in `duo_naming.dart`.
///
/// One variant for now, [standard]. The class exists rather than a bare constant
/// so that a second — an 8x8 board, say — is a constant added here and nothing
/// else changed.
@immutable
class DuoVariant {
  const DuoVariant({required this.id, required this.spec});

  /// The identifier of [standard]. A constant so naming and (later) saves can
  /// switch on it without repeating a bare string.
  static const String duoId = 'duo';

  /// A stable identifier, used for routing and (later) saves and statistics.
  ///
  /// Never shown to a player and never translated — a save written on an English
  /// phone has to still be readable after a language switch.
  final String id;

  /// The grid shape handed to the engine.
  final DuoSpec spec;

  /// The 6x6 board Nook ships.
  static const DuoVariant standard = DuoVariant(
    id: duoId,
    spec: DuoSpec.standard,
  );

  /// Every Duo variant. One for now.
  static const List<DuoVariant> values = <DuoVariant>[standard];

  /// The variant with this [id], or `null` if no Duo game has it.
  ///
  /// `null` rather than a throw, like Sudoku's and Stars's: an id can come off
  /// disk written by a build with a variant this one lacks, and a save nobody
  /// can read is a card that stays hidden rather than a crash on the home
  /// screen.
  static DuoVariant? byId(String id) {
    for (final DuoVariant variant in values) {
      if (variant.id == id) {
        return variant;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is DuoVariant && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DuoVariant($id)';
}
