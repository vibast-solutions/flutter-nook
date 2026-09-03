import 'package:puzzle_engine/puzzle_engine.dart';

import '../games/stars/stars_controller.dart';
import '../games/stars/stars_variant.dart';
import '../games/sudoku/sudoku_controller.dart';
import '../games/sudoku/sudoku_variant.dart';
import 'pack_library.dart';

/// A [SudokuPuzzleSource] that serves the pack first and generates as a fallback.
///
/// The whole of the instant-launch behaviour, in one seam the controller already
/// reached through: it tries the bundled pack for this grid and tier, and — when
/// the pack has nothing to give, which is the normal state after the first few
/// games — generates on the device exactly as before. The player can never tell
/// which one they got: both return a puzzle of the tier they asked for.
///
/// Falling back is not an error path. A grid with no pack (the instant ones, and
/// every variant Nook chose not to ship a pack for) reaches the generator on
/// every start, and that is by design.
SudokuPuzzleSource packedSudokuSource(PackLibrary library) {
  return (SudokuSpec spec, PuzzleDifficulty difficulty, int seed) async {
    final SudokuVariant? variant = _variantForSpec(spec);
    if (variant != null) {
      final SudokuPuzzle? packed = await library.takeSudoku(
        variant.id,
        spec,
        difficulty,
      );
      if (packed != null) {
        return packed;
      }
    }
    return generateSudokuOffThread(spec, difficulty, seed);
  };
}

/// A [StarsPuzzleSource] that serves the pack first and generates as a fallback.
StarsPuzzleSource packedStarsSource(PackLibrary library) {
  return (StarsSpec spec, PuzzleDifficulty difficulty, int seed) async {
    final StarsVariant? variant = _starsVariantForSpec(spec);
    if (variant != null) {
      final StarsPuzzle? packed = await library.takeStars(
        variant.id,
        spec,
        difficulty,
      );
      if (packed != null) {
        return packed;
      }
    }
    return generateStarsOffThread(spec, difficulty, seed);
  };
}

/// The Sudoku a grid shape belongs to, so a pack can be keyed by the game's id
/// rather than by the shape. `null` for a shape no variant has, which cannot
/// happen for a running game but keeps the mapping total.
SudokuVariant? _variantForSpec(SudokuSpec spec) {
  for (final SudokuVariant variant in SudokuVariant.values) {
    if (variant.spec == spec) {
      return variant;
    }
  }
  return null;
}

/// The Stars variant a grid shape belongs to.
StarsVariant? _starsVariantForSpec(StarsSpec spec) {
  for (final StarsVariant variant in StarsVariant.values) {
    if (variant.spec == spec) {
      return variant;
    }
  }
  return null;
}
