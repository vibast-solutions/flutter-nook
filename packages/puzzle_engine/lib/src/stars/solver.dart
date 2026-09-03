import 'spec.dart';

/// An exhaustive Stars solver.
///
/// Its one job is the question the generator asks constantly: *how many ways
/// can this region map be starred?* Nook guarantees exactly one, and the
/// guarantee is only worth anything if it is counted rather than hoped for.
///
/// It is not the clever solver — the technique solver that rates difficulty and
/// powers hints is [StarsLogicSolver], a separate thing. This one searches
/// row by row, placing [StarsSpec.starsPerUnit] stars in each, and leans on a
/// counting argument to keep the search small: because every row is filled and
/// no column or region is ever allowed past its quota, any placement that
/// reaches the last row is automatically legal in every column and region, so
/// the search never pays to check them at the end.
class StarsSolver {
  StarsSolver(this.spec) {
    spec.validate();
  }

  final StarsSpec spec;

  /// Counts the placements [regions] admits, stopping once [limit] are found.
  ///
  /// The generator only needs to tell "exactly one" from "more than one", so it
  /// passes `limit: 2` and never pays for the rest of the search.
  int countPlacements(List<int> regions, {int limit = 2}) {
    final _Search search = _Search(spec, regions, limit: limit);
    search.run();
    return search.found;
  }

  /// A placement of [regions] as its sorted star cells, or `null` if it has
  /// none. When more than one exists, which comes back is unspecified.
  List<int>? solve(List<int> regions) {
    final _Search search = _Search(spec, regions, limit: 1, keep: true);
    search.run();
    return search.solution;
  }
}

/// One depth-first search over a region map. Not reusable: one per question.
class _Search {
  _Search(
    this.spec,
    List<int> regions, {
    required this.limit,
    this.keep = false,
  }) : _size = spec.size,
       _starsPerUnit = spec.starsPerUnit,
       _regions = regions,
       _columnCount = List<int>.filled(spec.size, 0),
       _regionCount = List<int>.filled(spec.regionCount, 0) {
    if (regions.length != spec.cellCount) {
      throw ArgumentError(
        'Expected ${spec.cellCount} region entries, got ${regions.length}.',
      );
    }
    _rowChoices = _buildRowChoices();
  }

  final StarsSpec spec;
  final int _size;
  final int _starsPerUnit;
  final List<int> _regions;
  final int limit;
  final bool keep;

  final List<int> _columnCount;
  final List<int> _regionCount;
  final List<int> _current = <int>[];

  /// Every legal set of columns one row could take: [_starsPerUnit] of them,
  /// no two touching. The same for every row, so it is built once.
  late final List<List<int>> _rowChoices;

  int found = 0;
  List<int>? solution;

  void run() => _place(0, const <int>[]);

  void _place(int row, List<int> prevColumns) {
    if (found >= limit) {
      return;
    }
    if (row == _size) {
      found++;
      if (keep && solution == null) {
        solution = List<int>.of(_current)..sort();
      }
      return;
    }

    for (final List<int> choice in _rowChoices) {
      if (!_clearsPreviousRow(choice, prevColumns)) {
        continue;
      }
      if (!_take(row, choice)) {
        continue;
      }
      _place(row + 1, choice);
      _giveBack(row, choice);
      if (found >= limit) {
        return;
      }
    }
  }

  /// Whether no column in [choice] touches a star in the row above.
  ///
  /// Consecutive rows are a single step apart, so two stars in them touch
  /// exactly when their columns are equal or one apart.
  bool _clearsPreviousRow(List<int> choice, List<int> prevColumns) {
    for (final int column in choice) {
      for (final int previous in prevColumns) {
        if ((column - previous).abs() <= 1) {
          return false;
        }
      }
    }
    return true;
  }

  /// Places [choice]'s stars in [row], or leaves the board untouched and
  /// returns false if that would put a column or region past its quota.
  bool _take(int row, List<int> choice) {
    int taken = 0;
    for (final int column in choice) {
      final int index = spec.indexOf(row, column);
      final int region = _regions[index];
      if (_columnCount[column] >= _starsPerUnit ||
          _regionCount[region] >= _starsPerUnit) {
        _rollBack(row, choice, taken);
        return false;
      }
      _columnCount[column]++;
      _regionCount[region]++;
      _current.add(index);
      taken++;
    }
    return true;
  }

  void _giveBack(int row, List<int> choice) =>
      _rollBack(row, choice, choice.length);

  void _rollBack(int row, List<int> choice, int count) {
    for (int i = 0; i < count; i++) {
      final int column = choice[i];
      final int index = spec.indexOf(row, column);
      _columnCount[column]--;
      _regionCount[_regions[index]]--;
      _current.removeLast();
    }
  }

  /// Every way to pick [_starsPerUnit] non-touching columns out of a row.
  List<List<int>> _buildRowChoices() {
    final List<List<int>> out = <List<int>>[];
    final List<int> current = List<int>.filled(_starsPerUnit, 0);

    void walk(int start, int depth) {
      if (depth == _starsPerUnit) {
        out.add(List<int>.of(current));
        return;
      }
      // Each next column is at least two past the last, which keeps the stars
      // in one row from touching without a separate check.
      final int from = depth == 0 ? start : current[depth - 1] + 2;
      for (int column = from; column < _size; column++) {
        current[depth] = column;
        walk(column + 1, depth + 1);
      }
    }

    walk(0, 0);
    return out;
  }
}
