import '../difficulty.dart';
import '../stars/logic_solver.dart';
import '../stars/puzzle.dart';
import '../stars/solver.dart';
import '../stars/spec.dart';
import '../stars/technique.dart';
import 'pack.dart';

/// Turns a Stars puzzle into a pack record and back again.
///
/// The mirror of [SudokuPack] for the game whose board is a region map rather
/// than a grid of givens. A record stores the regions, never the star
/// placement — a pack puzzle admits exactly one placement by guarantee, so
/// [puzzle] recovers it with the same [StarsSolver] the generator used to prove
/// it unique.
class StarsPack {
  const StarsPack._();

  /// The record for [puzzle], measuring the techniques it needs on the way.
  static PackRecord record(StarsPuzzle puzzle) {
    final StarsSolveReport report = StarsLogicSolver(puzzle.spec)
        .solve(puzzle.regions);
    return PackRecord(
      seed: puzzle.seed,
      cells: encodeRegions(puzzle.spec, puzzle.regions),
      techniques: encodeTechniques(report.steps),
    );
  }

  /// The playable puzzle [record] describes, at [tier].
  ///
  /// Throws [PackFormatException] if the region map does not admit exactly one
  /// placement — a corrupt record is treated as no record, so the app falls back
  /// to generating rather than handing back a board with no unique answer.
  static StarsPuzzle puzzle(
    PackRecord record,
    StarsSpec spec,
    PuzzleDifficulty tier,
  ) {
    final List<int> regions = decodeRegions(spec, record.cells);
    final List<int>? solution = StarsSolver(spec).solve(regions);
    if (solution == null) {
      throw PackFormatException(
        'pack Stars (seed ${record.seed}) has no placement',
      );
    }
    return StarsPuzzle(
      spec: spec,
      seed: record.seed,
      regions: regions,
      solution: solution,
      difficulty: tier,
    );
  }

  /// The region map as one character per cell.
  ///
  /// One character per cell, so a pack is only built for a grid whose regions
  /// number ten or fewer — every Stars board Nook ships has eight.
  static String encodeRegions(StarsSpec spec, List<int> regions) {
    if (spec.regionCount > 10) {
      throw ArgumentError(
        'pack cells need one char per region; ${spec.regionCount} is too many',
      );
    }
    final StringBuffer out = StringBuffer();
    for (final int region in regions) {
      out.write(region.toString());
    }
    return out.toString();
  }

  /// The region map back from [cells].
  static List<int> decodeRegions(StarsSpec spec, String cells) {
    if (cells.length != spec.cellCount) {
      throw PackFormatException(
        'expected ${spec.cellCount} cells, got ${cells.length}',
      );
    }
    return <int>[
      for (int i = 0; i < cells.length; i++)
        _region(cells[i], spec.regionCount, i),
    ];
  }

  static int _region(String char, int regionCount, int index) {
    final int value = int.tryParse(char) ?? -1;
    if (value < 0 || value >= regionCount) {
      throw PackFormatException('bad region "$char" at index $index');
    }
    return value;
  }

  /// The solve report's steps as `name -> count`, ordered hardest-last.
  static Map<String, int> encodeTechniques(Map<StarsTechnique, int> steps) {
    final Map<String, int> out = <String, int>{};
    for (final StarsTechnique technique in StarsTechnique.values) {
      final int? count = steps[technique];
      if (count != null && count > 0) {
        out[technique.name] = count;
      }
    }
    return out;
  }
}
