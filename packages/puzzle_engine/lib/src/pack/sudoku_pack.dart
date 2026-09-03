import '../difficulty.dart';
import '../sudoku/logic_solver.dart';
import '../sudoku/puzzle.dart';
import '../sudoku/solver.dart';
import '../sudoku/spec.dart';
import '../sudoku/technique.dart';
import 'pack.dart';

/// Turns a Sudoku into a pack record and back again.
///
/// The two directions are the whole reason the pack format is shared engine
/// code: the CLI writes a record with [record], the app reads one back with
/// [puzzle], and neither can drift from the other because they are the same
/// pair of functions.
///
/// A record stores the givens, never the solution — a pack puzzle is guess-free
/// by guarantee, so [puzzle] recovers the one solution with the same [SudokuSolver]
/// the generator used to prove it unique.
class SudokuPack {
  const SudokuPack._();

  /// The record for [puzzle], measuring the techniques it needs on the way.
  ///
  /// The techniques come from the human solver rather than being carried on the
  /// puzzle, because [SudokuPuzzle] does not keep them; running the solver here
  /// is what lets the record say honestly what makes the puzzle its tier.
  static PackRecord record(SudokuPuzzle puzzle) {
    final SudokuSolveReport report = SudokuLogicSolver(puzzle.spec)
        .solve(puzzle.givens);
    return PackRecord(
      seed: puzzle.seed,
      cells: encodeGivens(puzzle.spec, puzzle.givens),
      techniques: encodeTechniques(report.steps),
    );
  }

  /// The playable puzzle [record] describes, at [tier].
  ///
  /// Throws [PackFormatException] if the givens do not solve to exactly the
  /// solution a valid pack promises — a corrupt record is treated as no record,
  /// so the app falls back to generating rather than handing back a broken board.
  static SudokuPuzzle puzzle(
    PackRecord record,
    SudokuSpec spec,
    PuzzleDifficulty tier,
  ) {
    final List<int> givens = decodeGivens(spec, record.cells);
    final List<int>? solution = SudokuSolver(spec).solve(givens);
    if (solution == null) {
      throw PackFormatException(
        'pack Sudoku (seed ${record.seed}) has no solution',
      );
    }
    return SudokuPuzzle(
      spec: spec,
      seed: record.seed,
      givens: givens,
      solution: solution,
      difficulty: tier,
    );
  }

  /// The givens as one character per cell: the digit, or `.` for a blank.
  ///
  /// One character per cell keeps a record a single legible token, which is why
  /// packs are only built for grids whose digits are a single character —
  /// everything Nook ships is 9×9 or smaller.
  static String encodeGivens(SudokuSpec spec, List<int> givens) {
    if (spec.size > 9) {
      throw ArgumentError(
        'pack cells need one char per digit; ${spec.size} is too wide',
      );
    }
    final StringBuffer out = StringBuffer();
    for (final int value in givens) {
      out.write(value == 0 ? '.' : value.toString());
    }
    return out.toString();
  }

  /// The givens back from [cells], `.` becoming a blank.
  static List<int> decodeGivens(SudokuSpec spec, String cells) {
    if (cells.length != spec.cellCount) {
      throw PackFormatException(
        'expected ${spec.cellCount} cells, got ${cells.length}',
      );
    }
    return <int>[
      for (int i = 0; i < cells.length; i++) _digit(cells[i], spec.size, i),
    ];
  }

  static int _digit(String char, int size, int index) {
    if (char == '.') {
      return 0;
    }
    final int value = int.tryParse(char) ?? -1;
    if (value < 1 || value > size) {
      throw PackFormatException('bad cell "$char" at index $index');
    }
    return value;
  }

  /// The solve report's steps as `name -> count`, ordered hardest-last.
  ///
  /// Ordered by the technique ladder so the encoding is deterministic — two
  /// runs of the same solve produce the same record — and so a reviewer reads
  /// the techniques in the order a solver would reach for them.
  static Map<String, int> encodeTechniques(Map<SudokuTechnique, int> steps) {
    final Map<String, int> out = <String, int>{};
    for (final SudokuTechnique technique in SudokuTechnique.values) {
      final int? count = steps[technique];
      if (count != null && count > 0) {
        out[technique.name] = count;
      }
    }
    return out;
  }
}
