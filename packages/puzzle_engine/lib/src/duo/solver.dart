import 'spec.dart';

/// An exhaustive Duo solver.
///
/// Its one job is the question the generator asks constantly: *how many ways
/// can these givens and badges be completed?* Nook guarantees exactly one, and
/// the guarantee is only worth anything if it is counted rather than hoped for.
///
/// It is not the clever solver — the technique solver that rates difficulty and
/// powers hints is [DuoLogicSolver], a separate thing. This one searches the
/// grid cell by cell in reading order, and because every earlier cell is filled
/// by the time it reaches one, it can check the three rules against what is
/// already down and prune the instant a placement breaks one:
///
/// * **balance** — never more than [DuoSpec.perSymbol] of a symbol in any row or
///   column;
/// * **no long run** — never more than [DuoSpec.runLimit] of one symbol in a row
///   or column consecutively;
/// * **badges** — every `=`/`x` between a cell and its already-placed left or
///   upper neighbour is honoured.
///
/// A completed grid that passes those on the way down is legal in full, so the
/// search never pays for a separate final check.
class DuoSolver {
  DuoSolver(this.spec) {
    spec.validate();
  }

  final DuoSpec spec;

  /// Counts the completions [givens] and [badges] admit, stopping once [limit]
  /// are found.
  ///
  /// The generator only needs to tell "exactly one" from "more than one", so it
  /// passes `limit: 2` and never pays for the rest of the search.
  int countSolutions(
    List<DuoSymbol?> givens,
    List<DuoBadge> badges, {
    int limit = 2,
  }) {
    final _Search search = _Search(spec, givens, badges, limit: limit);
    search.run();
    return search.found;
  }

  /// The completion of [givens] and [badges], or `null` if there is none. When
  /// more than one exists, which comes back is unspecified.
  List<DuoSymbol>? solve(List<DuoSymbol?> givens, List<DuoBadge> badges) {
    final _Search search = _Search(spec, givens, badges, limit: 1, keep: true);
    search.run();
    return search.solution;
  }
}

/// One depth-first search over a set of givens. Not reusable: one per question.
class _Search {
  _Search(
    this.spec,
    List<DuoSymbol?> givens,
    List<DuoBadge> badges, {
    required this.limit,
    this.keep = false,
  }) : _size = spec.size,
       _perSymbol = spec.perSymbol,
       _runLimit = spec.runLimit,
       _given = <int>[
         for (final DuoSymbol? symbol in givens)
           symbol == null ? _empty : symbol.index,
       ],
       _grid = List<int>.filled(spec.cellCount, _empty),
       _rowCount = List<int>.filled(spec.size * 2, 0),
       _columnCount = List<int>.filled(spec.size * 2, 0),
       _badgeLeft = List<int>.filled(spec.cellCount, _noBadge),
       _badgeUp = List<int>.filled(spec.cellCount, _noBadge) {
    if (givens.length != spec.cellCount) {
      throw ArgumentError(
        'Expected ${spec.cellCount} given entries, got ${givens.length}.',
      );
    }
    for (final DuoBadge badge in badges) {
      if (badge.isHorizontal) {
        _badgeLeft[badge.b] = badge.relation.index;
      } else {
        _badgeUp[badge.b] = badge.relation.index;
      }
    }
  }

  static const int _empty = -1;
  static const int _noBadge = -1;

  final DuoSpec spec;
  final int _size;
  final int _perSymbol;
  final int _runLimit;
  final List<int> _given;
  final List<int> _grid;

  /// Circles and squares in each row, indexed `row * 2 + symbol`.
  final List<int> _rowCount;

  /// Circles and squares in each column, indexed `column * 2 + symbol`.
  final List<int> _columnCount;

  /// The relation on the edge to a cell's left neighbour, or [_noBadge].
  final List<int> _badgeLeft;

  /// The relation on the edge to a cell's upper neighbour, or [_noBadge].
  final List<int> _badgeUp;

  final int limit;
  final bool keep;

  int found = 0;
  List<DuoSymbol>? solution;

  void run() => _place(0);

  void _place(int index) {
    if (found >= limit) {
      return;
    }
    if (index == spec.cellCount) {
      found++;
      if (keep && solution == null) {
        solution = <DuoSymbol>[
          for (final int value in _grid) DuoSymbol.values[value],
        ];
      }
      return;
    }

    final int fixed = _given[index];
    for (int symbol = 0; symbol < 2; symbol++) {
      if (fixed != _empty && fixed != symbol) {
        continue;
      }
      if (!_legal(index, symbol)) {
        continue;
      }
      _set(index, symbol);
      _place(index + 1);
      _unset(index, symbol);
      if (found >= limit) {
        return;
      }
    }
  }

  /// Whether [symbol] may go in the cell at [index] given everything already
  /// placed to its left and above.
  bool _legal(int index, int symbol) {
    final int row = spec.rowOf(index);
    final int column = spec.columnOf(index);

    if (_rowCount[row * 2 + symbol] >= _perSymbol ||
        _columnCount[column * 2 + symbol] >= _perSymbol) {
      return false;
    }

    // A run of [_runLimit] identical cells already ending at the neighbour
    // would become one too long; the earlier cells are all placed because the
    // search fills in reading order.
    if (_runOf(index, -1, symbol) >= _runLimit ||
        _runOf(index, -_size, symbol) >= _runLimit) {
      return false;
    }

    final int left = _badgeLeft[index];
    if (left != _noBadge && column > 0) {
      if (!DuoRelation.values[left].holds(
        DuoSymbol.values[_grid[index - 1]],
        DuoSymbol.values[symbol],
      )) {
        return false;
      }
    }
    final int up = _badgeUp[index];
    if (up != _noBadge && row > 0) {
      if (!DuoRelation.values[up].holds(
        DuoSymbol.values[_grid[index - _size]],
        DuoSymbol.values[symbol],
      )) {
        return false;
      }
    }
    return true;
  }

  /// How many cells equal to [symbol] sit in an unbroken run stepping [step]
  /// away from [index] (−1 for left, −size for up). Stops at a boundary, an
  /// empty cell, or a different symbol.
  int _runOf(int index, int step, int symbol) {
    int run = 0;
    int at = index;
    while (true) {
      // A horizontal step must not cross a row boundary.
      if (step == -1 && spec.columnOf(at) == 0) {
        break;
      }
      at += step;
      if (at < 0 || _grid[at] != symbol) {
        break;
      }
      run++;
    }
    return run;
  }

  void _set(int index, int symbol) {
    _grid[index] = symbol;
    _rowCount[spec.rowOf(index) * 2 + symbol]++;
    _columnCount[spec.columnOf(index) * 2 + symbol]++;
  }

  void _unset(int index, int symbol) {
    _grid[index] = _empty;
    _rowCount[spec.rowOf(index) * 2 + symbol]--;
    _columnCount[spec.columnOf(index) * 2 + symbol]--;
  }
}
