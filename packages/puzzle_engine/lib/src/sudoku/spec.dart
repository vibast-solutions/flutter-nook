import 'package:meta/meta.dart';

/// The shape of a Sudoku grid, expressed as the shape of one of its boxes.
///
/// A box is [boxWidth] cells wide and [boxHeight] cells tall, and the grid is
/// [size] x [size] where `size == boxWidth * boxHeight`. Every variant Nook
/// ships is therefore one constant: 4x4 is 2x2 boxes, 6x6 is 3x2, 9x9 is 3x3.
/// Nothing in the solver or the generator is written for a particular size.
@immutable
class SudokuSpec {
  const SudokuSpec({required this.boxWidth, required this.boxHeight});

  /// Cells across one box.
  final int boxWidth;

  /// Cells down one box.
  final int boxHeight;

  /// Sudoku Mini — 4x4 with 2x2 boxes.
  static const SudokuSpec mini = SudokuSpec(boxWidth: 2, boxHeight: 2);

  /// Sudoku Light — 6x6 with 3x2 boxes.
  static const SudokuSpec light = SudokuSpec(boxWidth: 3, boxHeight: 2);

  /// Sudoku Classic — 9x9 with 3x3 boxes.
  static const SudokuSpec classic = SudokuSpec(boxWidth: 3, boxHeight: 3);

  /// The side length of the grid, and the largest digit it uses.
  int get size => boxWidth * boxHeight;

  /// The total number of cells.
  int get cellCount => size * size;

  /// Boxes across the grid.
  int get boxesAcross => size ~/ boxWidth;

  /// Boxes down the grid.
  int get boxesDown => size ~/ boxHeight;

  /// The row of the cell at [index].
  int rowOf(int index) => index ~/ size;

  /// The column of the cell at [index].
  int columnOf(int index) => index % size;

  /// The box of the cell at [index], numbered left to right, top to bottom.
  int boxOf(int index) {
    final int row = index ~/ size;
    final int column = index % size;
    return (row ~/ boxHeight) * boxesAcross + (column ~/ boxWidth);
  }

  /// Throws if this spec could not describe a Sudoku grid.
  void validate() {
    if (boxWidth < 1 || boxHeight < 1) {
      throw ArgumentError(
        'Box dimensions must be positive, got '
        '${boxWidth}x$boxHeight.',
      );
    }
    if (size > 32) {
      throw ArgumentError(
        'Grids larger than 32x32 are not supported, got '
        '${size}x$size.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SudokuSpec &&
      other.boxWidth == boxWidth &&
      other.boxHeight == boxHeight;

  @override
  int get hashCode => Object.hash(boxWidth, boxHeight);

  @override
  String toString() =>
      'SudokuSpec(${size}x$size, boxes ${boxWidth}x$boxHeight)';
}
