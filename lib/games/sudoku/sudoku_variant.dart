import 'package:flutter/foundation.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// One of Nook's three Sudoku sizes, as the player meets it.
///
/// The engine only knows box shapes; this is the layer that gives a shape a
/// name, a description and a place in the game list.
@immutable
class SudokuVariant {
  const SudokuVariant({
    required this.id,
    required this.title,
    required this.spec,
  });

  /// A stable identifier, used for routing and (later) saves and statistics.
  final String id;

  /// The name shown to the player.
  final String title;

  /// The grid shape handed to the engine.
  final SudokuSpec spec;

  /// Sudoku Mini — 4x4.
  static const SudokuVariant mini = SudokuVariant(
    id: 'sudoku-mini',
    title: 'Sudoku Mini',
    spec: SudokuSpec.mini,
  );

  /// Sudoku Light — 6x6. Not playable yet; VIB-73 turns it on.
  static const SudokuVariant light = SudokuVariant(
    id: 'sudoku-light',
    title: 'Sudoku Light',
    spec: SudokuSpec.light,
  );

  /// Sudoku Classic — 9x9. Not playable yet; VIB-73 turns it on.
  static const SudokuVariant classic = SudokuVariant(
    id: 'sudoku-classic',
    title: 'Sudoku Classic',
    spec: SudokuSpec.classic,
  );

  /// `4x4`, `6x6`, `9x9` — the grid size in words.
  String get sizeLabel => '${spec.size}x${spec.size}';

  @override
  bool operator ==(Object other) => other is SudokuVariant && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SudokuVariant($id)';
}
