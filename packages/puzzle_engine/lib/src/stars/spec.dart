import 'package:meta/meta.dart';

/// The shape of a Stars grid: a square board, a number of regions, and how
/// many stars go in each row, column and region.
///
/// Nook's Stars is 8x8 with eight regions and one star per unit, which is
/// [standard]. Everything in the solver and the generator is written for the
/// [size], [regionCount] and [starsPerUnit] here rather than for those
/// numbers, so a 10x10 two-star variant later is a constructor argument and
/// not a rewrite.
@immutable
class StarsSpec {
  const StarsSpec({this.size = 8, int? regionCount, this.starsPerUnit = 1})
    : regionCount = regionCount ?? size;

  /// The 8x8, eight-region, one-star-per-unit board Nook ships.
  static const StarsSpec standard = StarsSpec();

  /// The side length of the grid.
  final int size;

  /// How many regions the grid is partitioned into.
  ///
  /// A Star Battle has one region per row's worth of stars, so this is [size]:
  /// eight regions on an 8x8, each holding [starsPerUnit] stars. It is a field
  /// of its own so the relationship is stated rather than assumed.
  final int regionCount;

  /// How many stars go in each row, each column and each region.
  final int starsPerUnit;

  /// The total number of cells.
  int get cellCount => size * size;

  /// How many stars a finished board holds — [starsPerUnit] per row.
  int get starCount => starsPerUnit * size;

  /// The row of the cell at [index].
  int rowOf(int index) => index ~/ size;

  /// The column of the cell at [index].
  int columnOf(int index) => index % size;

  /// The cell at [row], [column].
  int indexOf(int row, int column) => row * size + column;

  /// The cells that touch the cell at [index] — up to eight of them, the four
  /// orthogonal and the four diagonal.
  ///
  /// This is the adjacency the "no two stars touch" rule is about, so it
  /// includes the diagonals: two stars a diagonal step apart are touching.
  List<int> neighbours(int index) {
    final int row = rowOf(index);
    final int column = columnOf(index);
    final List<int> found = <int>[];
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) {
          continue;
        }
        final int r = row + dr;
        final int c = column + dc;
        if (r >= 0 && r < size && c >= 0 && c < size) {
          found.add(indexOf(r, c));
        }
      }
    }
    return found;
  }

  /// The cells edge-to-edge with the cell at [index] — up to four of them.
  ///
  /// This is the adjacency a *region* is contiguous under: a region is a
  /// single blob whose cells connect through their edges, not their corners.
  List<int> orthogonalNeighbours(int index) {
    final int row = rowOf(index);
    final int column = columnOf(index);
    final List<int> found = <int>[];
    if (row > 0) {
      found.add(indexOf(row - 1, column));
    }
    if (row < size - 1) {
      found.add(indexOf(row + 1, column));
    }
    if (column > 0) {
      found.add(indexOf(row, column - 1));
    }
    if (column < size - 1) {
      found.add(indexOf(row, column + 1));
    }
    return found;
  }

  /// Throws if this spec could not describe a Stars grid.
  void validate() {
    if (size < 1) {
      throw ArgumentError('A grid must have a positive size, got $size.');
    }
    if (regionCount < 1) {
      throw ArgumentError(
        'A grid must have at least one region, got $regionCount.',
      );
    }
    if (starsPerUnit < 1) {
      throw ArgumentError(
        'A unit must hold at least one star, got $starsPerUnit.',
      );
    }
    // A Star Battle has one region per row, each holding [starsPerUnit] stars,
    // so the region count is the side length. The solver leans on this: it
    // caps each region at [starsPerUnit] and lets the counting take care of the
    // rest, which only comes out exact when there are exactly [size] regions.
    if (regionCount != size) {
      throw ArgumentError(
        'A $size x $size grid needs $size regions, got $regionCount.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is StarsSpec &&
      other.size == size &&
      other.regionCount == regionCount &&
      other.starsPerUnit == starsPerUnit;

  @override
  int get hashCode => Object.hash(size, regionCount, starsPerUnit);

  @override
  String toString() =>
      'StarsSpec(${size}x$size, $regionCount regions, '
      '$starsPerUnit per unit)';
}
