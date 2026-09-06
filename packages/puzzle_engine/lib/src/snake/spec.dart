import 'package:meta/meta.dart';

/// A direction the snake can travel, on a grid whose rows count downward.
///
/// Nameless on purpose, like every other engine enum: a name a player reads has
/// to be translated, and this package is pure Dart. The app names them where it
/// needs to. The declaration order is stable because it is what a queued input
/// records.
enum SnakeDirection {
  /// One row up: toward row zero.
  up,

  /// One row down.
  down,

  /// One column left: toward column zero.
  left,

  /// One column right.
  right;

  /// The change in row this direction makes: `-1` up, `+1` down, else `0`.
  int get dRow => switch (this) {
    SnakeDirection.up => -1,
    SnakeDirection.down => 1,
    SnakeDirection.left => 0,
    SnakeDirection.right => 0,
  };

  /// The change in column this direction makes: `-1` left, `+1` right, else `0`.
  int get dColumn => switch (this) {
    SnakeDirection.up => 0,
    SnakeDirection.down => 0,
    SnakeDirection.left => -1,
    SnakeDirection.right => 1,
  };

  /// The direction that undoes this one — a straight reversal.
  SnakeDirection get opposite => switch (this) {
    SnakeDirection.up => SnakeDirection.down,
    SnakeDirection.down => SnakeDirection.up,
    SnakeDirection.left => SnakeDirection.right,
    SnakeDirection.right => SnakeDirection.left,
  };

  /// Whether [other] is a straight reversal of this direction.
  ///
  /// A snake at least two long that turned straight back on itself would drive
  /// its head into its own neck, so a step ignores an intended reversal and
  /// keeps going the way it was.
  bool isReverseOf(SnakeDirection other) => other == opposite;
}

/// The shape of a Snake board and how a game on it begins.
///
/// A rectangular grid — taller than it is wide, to sit in a phone's portrait
/// screen — with the snake's starting length and the way it first travels.
/// Everything in [SnakeGame] is written for the [cols], [rows] and the two
/// starting values here rather than for those numbers, so a second board is a
/// constant and not a rewrite.
///
/// Cells are numbered row-major from the top-left: index `row * cols + column`,
/// with row zero at the top. There is no wrap-around — a step off any edge is a
/// wall, and the [neighbour] method is the one place that rule lives.
@immutable
class SnakeSpec {
  const SnakeSpec({
    this.cols = 17,
    this.rows = 22,
    this.startLength = 3,
    this.startDirection = SnakeDirection.right,
  });

  /// The board Nook ships: a 17-wide, 22-tall portrait grid.
  static const SnakeSpec standard = SnakeSpec();

  /// The number of columns.
  final int cols;

  /// The number of rows.
  final int rows;

  /// How many cells long the snake is when a game begins.
  final int startLength;

  /// The way the snake is travelling when a game begins.
  final SnakeDirection startDirection;

  /// The total number of cells.
  int get cellCount => cols * rows;

  /// The row of the cell at [index].
  int rowOf(int index) => index ~/ cols;

  /// The column of the cell at [index].
  int columnOf(int index) => index % cols;

  /// The cell at [row], [column].
  int indexOf(int row, int column) => row * cols + column;

  /// The cell one step in [direction] from [index], or `null` if that step
  /// would leave the board.
  ///
  /// The whole of the no-wrap-around rule: a move that runs off the top, bottom
  /// or either side has no neighbour, so [SnakeGame.step] reads a `null` here as
  /// hitting a wall. Working in row/column rather than on the flat index is what
  /// makes a step off the left edge a wall instead of a silent wrap onto the end
  /// of the row above.
  int? neighbour(int index, SnakeDirection direction) {
    final int row = rowOf(index) + direction.dRow;
    final int column = columnOf(index) + direction.dColumn;
    if (row < 0 || row >= rows || column < 0 || column >= cols) {
      return null;
    }
    return indexOf(row, column);
  }

  /// Throws if this spec could not describe a playable Snake board.
  void validate() {
    if (cols < 2 || rows < 2) {
      throw ArgumentError('A board must be at least 2x2, got ${cols}x$rows.');
    }
    // The snake starts in one row travelling along it, so the row has to be long
    // enough to hold the whole starting length with the head off the wall.
    if (startLength < 1) {
      throw ArgumentError('The snake must start at least 1 long.');
    }
    if (startLength > cols) {
      throw ArgumentError(
        'A snake of $startLength does not fit across $cols columns.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is SnakeSpec &&
      other.cols == cols &&
      other.rows == rows &&
      other.startLength == startLength &&
      other.startDirection == startDirection;

  @override
  int get hashCode => Object.hash(cols, rows, startLength, startDirection);

  @override
  String toString() =>
      'SnakeSpec(${cols}x$rows, start $startLength ${startDirection.name})';
}
