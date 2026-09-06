import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// Nook's Snake game, as the player meets it.
///
/// The engine only knows board shapes; this is the layer that gives one an
/// identity and a place in the game list, the same way [SnakeVariant]'s
/// siblings do for Sudoku, Stars and Duo. It carries no words — the name a
/// player reads is translated, and lives in `snake_naming.dart`.
///
/// One variant for now, [standard]. The class exists rather than a bare constant
/// so that a second — a wider board, say — is a constant added here and nothing
/// else changed.
@immutable
class SnakeVariant {
  const SnakeVariant({required this.id, required this.spec});

  /// The identifier of [standard]. A constant so naming and routing can switch
  /// on it without repeating a bare string.
  static const String snakeId = 'snake';

  /// A stable identifier, used for routing.
  ///
  /// Never shown to a player and never translated. Snake keeps no saves in this
  /// story, but the id is here so it slots into the same routing and (later)
  /// statistics machinery as the other games.
  final String id;

  /// The board shape handed to the engine.
  final SnakeSpec spec;

  /// The portrait board Nook ships.
  static const SnakeVariant standard = SnakeVariant(
    id: snakeId,
    spec: SnakeSpec.standard,
  );

  /// Every Snake variant. One for now.
  static const List<SnakeVariant> values = <SnakeVariant>[standard];

  /// The variant with this [id], or `null` if no Snake game has it.
  ///
  /// `null` rather than a throw, like every other game's `byId`: an id can come
  /// from a build with a variant this one lacks, and the caller decides what to
  /// do about it rather than crashing.
  static SnakeVariant? byId(String id) {
    for (final SnakeVariant variant in values) {
      if (variant.id == id) {
        return variant;
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) => other is SnakeVariant && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SnakeVariant($id)';
}
