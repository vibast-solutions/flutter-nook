import 'spec.dart';

/// An exhaustive Sudoku solver.
///
/// Its job is not to be clever — the technique-based solver that rates
/// difficulty and powers hints is a separate thing. This one exists to answer
/// one question the generator asks constantly: *how many solutions does this
/// grid have?* Nook guarantees every puzzle has exactly one, and that
/// guarantee is only worth anything if it is checked rather than assumed.
///
/// Candidates are tracked as bitmasks and the search always expands the cell
/// with the fewest of them, which is what keeps a 9x9 uniqueness check cheap
/// enough to run inside a generation loop.
class SudokuSolver {
  SudokuSolver(this.spec) {
    spec.validate();
  }

  final SudokuSpec spec;

  /// Counts the solutions of [cells], stopping once [limit] have been found.
  ///
  /// The generator only ever needs to tell "exactly one" from "more than one",
  /// so it passes `limit: 2` and never pays for the rest of the search tree.
  /// A grid that already breaks the rules counts as zero solutions.
  int countSolutions(List<int> cells, {int limit = 2}) {
    final _Search? search = _Search.create(spec, cells, limit: limit);
    if (search == null) {
      return 0;
    }
    search.run();
    return search.found;
  }

  /// Returns a solution of [cells], or `null` if it has none.
  ///
  /// When more than one exists, which one comes back is unspecified.
  List<int>? solve(List<int> cells) {
    final _Search? search = _Search.create(spec, cells, limit: 1, keep: true);
    if (search == null) {
      return null;
    }
    search.run();
    return search.found == 0 ? null : search.solution;
  }

  /// Whether [cells] is a complete grid that breaks none of the rules.
  bool isSolved(List<int> cells) {
    if (cells.length != spec.cellCount) {
      return false;
    }
    final _Search? search = _Search.create(spec, cells, limit: 1);
    return search != null && !search.hasEmptyCell;
  }

  /// Whether [cells] breaks no rule *so far* — empty cells are allowed.
  bool isConsistent(List<int> cells) =>
      _Search.create(spec, cells, limit: 1) != null;

  /// Fills an empty grid at random, producing a complete valid solution.
  ///
  /// Randomness comes only from [nextInt], which must return a value in
  /// `[0, max)`; the caller owns the seed, so the same seed always yields the
  /// same grid.
  List<int> fillRandom(int Function(int max) nextInt) {
    final List<int> empty = List<int>.filled(spec.cellCount, 0);
    final _Search search = _Search.create(spec, empty, limit: 1, keep: true)!;
    search.shuffleWith = nextInt;
    search.run();
    return search.solution!;
  }
}

/// One depth-first search over a grid. Not reusable: create one per question.
class _Search {
  _Search._(this.spec, this.cells, this.limit, this.keep)
    : _size = spec.size,
      _rowMask = List<int>.filled(spec.size, 0),
      _columnMask = List<int>.filled(spec.size, 0),
      _boxMask = List<int>.filled(spec.size, 0),
      _allDigits = (1 << spec.size) - 1;

  /// Returns a search over a copy of [cells], or `null` when [cells] already
  /// breaks a rule and so cannot lead to any solution.
  static _Search? create(
    SudokuSpec spec,
    List<int> cells, {
    required int limit,
    bool keep = false,
  }) {
    if (cells.length != spec.cellCount) {
      throw ArgumentError(
        'Expected ${spec.cellCount} cells, got '
        '${cells.length}.',
      );
    }
    final _Search search = _Search._(spec, List<int>.of(cells), limit, keep);
    return search._seed() ? search : null;
  }

  final SudokuSpec spec;
  final List<int> cells;
  final int limit;
  final bool keep;
  final int _size;
  final List<int> _rowMask;
  final List<int> _columnMask;
  final List<int> _boxMask;
  final int _allDigits;

  /// Set to shuffle candidate order, which turns solving into generating.
  int Function(int max)? shuffleWith;

  int found = 0;
  List<int>? solution;
  bool hasEmptyCell = false;

  /// Records the givens in the row/column/box masks.
  /// Returns false if two of them collide.
  bool _seed() {
    for (int i = 0; i < cells.length; i++) {
      final int value = cells[i];
      if (value == 0) {
        hasEmptyCell = true;
        continue;
      }
      if (value < 1 || value > _size) {
        return false;
      }
      final int bit = 1 << (value - 1);
      final int row = spec.rowOf(i);
      final int column = spec.columnOf(i);
      final int box = spec.boxOf(i);
      if ((_rowMask[row] & bit) != 0 ||
          (_columnMask[column] & bit) != 0 ||
          (_boxMask[box] & bit) != 0) {
        return false;
      }
      _rowMask[row] |= bit;
      _columnMask[column] |= bit;
      _boxMask[box] |= bit;
    }
    return true;
  }

  void run() => _step();

  void _step() {
    int bestIndex = -1;
    int bestCandidates = 0;
    int bestCount = _size + 1;

    for (int i = 0; i < cells.length; i++) {
      if (cells[i] != 0) {
        continue;
      }
      final int candidates =
          _allDigits &
          ~(_rowMask[spec.rowOf(i)] |
              _columnMask[spec.columnOf(i)] |
              _boxMask[spec.boxOf(i)]);
      if (candidates == 0) {
        // A dead end: this cell can hold nothing.
        return;
      }
      final int count = _bitCount(candidates);
      if (count < bestCount) {
        bestCount = count;
        bestIndex = i;
        bestCandidates = candidates;
        if (count == 1) {
          break;
        }
      }
    }

    if (bestIndex == -1) {
      // No empty cell left, so the grid is complete.
      found++;
      if (keep && solution == null) {
        solution = List<int>.of(cells);
      }
      return;
    }

    final List<int> digits = <int>[];
    for (int digit = 1; digit <= _size; digit++) {
      if ((bestCandidates & (1 << (digit - 1))) != 0) {
        digits.add(digit);
      }
    }
    final int Function(int max)? shuffle = shuffleWith;
    if (shuffle != null) {
      for (int i = digits.length - 1; i > 0; i--) {
        final int j = shuffle(i + 1);
        final int tmp = digits[i];
        digits[i] = digits[j];
        digits[j] = tmp;
      }
    }

    final int row = spec.rowOf(bestIndex);
    final int column = spec.columnOf(bestIndex);
    final int box = spec.boxOf(bestIndex);

    for (final int digit in digits) {
      final int bit = 1 << (digit - 1);
      cells[bestIndex] = digit;
      _rowMask[row] |= bit;
      _columnMask[column] |= bit;
      _boxMask[box] |= bit;

      _step();

      cells[bestIndex] = 0;
      _rowMask[row] &= ~bit;
      _columnMask[column] &= ~bit;
      _boxMask[box] &= ~bit;

      if (found >= limit) {
        return;
      }
    }
  }

  static int _bitCount(int mask) {
    int count = 0;
    int value = mask;
    while (value != 0) {
      value &= value - 1;
      count++;
    }
    return count;
  }
}
