import 'package:meta/meta.dart';

/// One of the two symbols a Duo cell can hold.
///
/// Nameless on purpose, like every other engine enum: a name a player reads
/// has to be translated, and this package is pure Dart. The app names the two
/// in `duo_naming.dart`. The declaration order is stable because [index] is
/// what a saved move records.
///
/// The two are drawn as a **circle** and a **square** rather than coloured,
/// because the shape is the colour-blind-safe distinction — Business Logic
/// rules a sun and a moon out for exactly that reason.
enum DuoSymbol {
  /// The round symbol.
  circle,

  /// The square symbol.
  square;

  /// The symbol that is not this one.
  DuoSymbol get other => this == circle ? square : circle;
}

/// What a constraint badge says about the two cells it sits between.
///
/// A badge is drawn on the edge between two orthogonally adjacent cells: an
/// `=` means they hold the **same** symbol, an `x` means they hold **different**
/// symbols. Nameless like [DuoSymbol]; the app draws the glyphs.
enum DuoRelation {
  /// The two cells hold the same symbol — an `=` badge.
  equal,

  /// The two cells hold different symbols — an `x` badge.
  unequal;

  /// Whether [a] and [b] satisfy this relation.
  bool holds(DuoSymbol a, DuoSymbol b) => this == equal ? a == b : a != b;

  /// The symbol the far cell must hold, given [from] on the near one.
  DuoSymbol from(DuoSymbol value) => this == equal ? value : value.other;
}

/// A constraint badge: an `=` or `x` on the edge between two adjacent cells.
///
/// [a] and [b] are the two cells, always with `a < b`, and [b] is either `a + 1`
/// (a horizontal edge, the two cells side by side) or `a + size` (a vertical
/// edge, one above the other). Storing the lower index first makes the badge
/// canonical, so a puzzle's badges compare and sort without caring which way an
/// edge was walked.
@immutable
class DuoBadge {
  const DuoBadge({required this.a, required this.b, required this.relation})
    : assert(a < b, 'A badge stores its lower cell first.');

  /// The lower-indexed of the two cells.
  final int a;

  /// The higher-indexed of the two cells: `a + 1` or `a + size`.
  final int b;

  /// Whether the two cells match or differ.
  final DuoRelation relation;

  /// Whether the badge sits on a horizontal edge (the cells are side by side).
  ///
  /// The two cells of a vertical edge are a whole row apart, so the only way
  /// [b] can be `a + 1` is a horizontal edge — a grid is at least two wide.
  bool get isHorizontal => b == a + 1;

  @override
  bool operator ==(Object other) =>
      other is DuoBadge &&
      other.a == a &&
      other.b == b &&
      other.relation == relation;

  @override
  int get hashCode => Object.hash(a, b, relation);

  @override
  String toString() => 'DuoBadge($a ${relation.name} $b)';
}

/// The shape of a Duo grid: a square board, how many of each symbol go in every
/// line, and how long a run of one symbol may get.
///
/// Nook's Duo is 6x6 with three of each symbol per line and no more than two
/// alike in a row, which is [standard]. Everything in the solver and generator
/// is written for the [size], [perSymbol] and [runLimit] here rather than for
/// those numbers, so an 8x8 variant later is a constructor argument and not a
/// rewrite.
@immutable
class DuoSpec {
  const DuoSpec({this.size = 6, int? perSymbol, this.runLimit = 2})
    : perSymbol = perSymbol ?? size ~/ 2;

  /// The 6x6, three-per-line board Nook ships.
  static const DuoSpec standard = DuoSpec();

  /// The side length of the grid.
  final int size;

  /// How many of each symbol a finished row or column holds.
  ///
  /// Half the [size]: a balanced line is [perSymbol] circles and [perSymbol]
  /// squares. A field of its own so the relationship is stated rather than
  /// assumed.
  final int perSymbol;

  /// The longest run of one symbol a line may hold — two, so three alike in a
  /// row is a breach.
  final int runLimit;

  /// The total number of cells.
  int get cellCount => size * size;

  /// The row of the cell at [index].
  int rowOf(int index) => index ~/ size;

  /// The column of the cell at [index].
  int columnOf(int index) => index % size;

  /// The cell at [row], [column].
  int indexOf(int row, int column) => row * size + column;

  /// Whether the cell at [index] has a cell to its right in the same row.
  bool hasRight(int index) => columnOf(index) < size - 1;

  /// Whether the cell at [index] has a cell below it.
  bool hasBelow(int index) => rowOf(index) < size - 1;

  /// Every edge a badge could sit on, as `(a, b)` pairs with `a < b`.
  ///
  /// The horizontal edges within each row and the vertical edges within each
  /// column — the adjacency a badge constrains. The generator draws its badges
  /// from this, and the same enumeration keeps the badge model canonical.
  List<(int, int)> edges() {
    final List<(int, int)> found = <(int, int)>[];
    for (int index = 0; index < cellCount; index++) {
      if (hasRight(index)) {
        found.add((index, index + 1));
      }
      if (hasBelow(index)) {
        found.add((index, index + size));
      }
    }
    return found;
  }

  /// Throws if this spec could not describe a Duo grid.
  void validate() {
    if (size < 2) {
      throw ArgumentError('A grid must be at least 2 wide, got $size.');
    }
    if (size.isOdd) {
      throw ArgumentError('A grid must have an even size, got $size.');
    }
    if (perSymbol * 2 != size) {
      throw ArgumentError(
        'A line of $size needs ${size ~/ 2} of each symbol, got $perSymbol.',
      );
    }
    if (runLimit < 1) {
      throw ArgumentError('A run limit must be positive, got $runLimit.');
    }
  }

  @override
  bool operator ==(Object other) =>
      other is DuoSpec &&
      other.size == size &&
      other.perSymbol == perSymbol &&
      other.runLimit == runLimit;

  @override
  int get hashCode => Object.hash(size, perSymbol, runLimit);

  @override
  String toString() =>
      'DuoSpec(${size}x$size, $perSymbol per line, run $runLimit)';
}
