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

  /// Sudoku Light — 6x6.
  static const SudokuVariant light = SudokuVariant(
    id: 'sudoku-light',
    title: 'Sudoku Light',
    spec: SudokuSpec.light,
  );

  /// Sudoku Classic — 9x9.
  static const SudokuVariant classic = SudokuVariant(
    id: 'sudoku-classic',
    title: 'Sudoku Classic',
    spec: SudokuSpec.classic,
  );

  /// `4x4`, `6x6`, `9x9` — the grid size in words.
  String get sizeLabel => '${spec.size}x${spec.size}';

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
