/// The rules behind every game in Nook.
///
/// This package is pure Dart on purpose. It must not import `package:flutter`,
/// touch the filesystem or read the clock: it is the one place puzzle
/// correctness lives, so it has to be testable exhaustively without a device
/// and reproducible from a seed alone.
library;

export 'src/difficulty.dart';
export 'src/duo/difficulty.dart';
export 'src/duo/generator.dart';
export 'src/duo/hint.dart';
export 'src/duo/logic_solver.dart';
export 'src/duo/puzzle.dart';
export 'src/duo/solver.dart';
export 'src/duo/spec.dart';
export 'src/duo/technique.dart';
export 'src/pack/pack.dart';
export 'src/pack/stars_pack.dart';
export 'src/pack/sudoku_pack.dart';
export 'src/random.dart';
export 'src/stars/difficulty.dart';
export 'src/stars/generator.dart';
export 'src/stars/hint.dart';
export 'src/stars/logic_solver.dart';
export 'src/stars/puzzle.dart';
export 'src/stars/solver.dart';
export 'src/stars/spec.dart';
export 'src/stars/technique.dart';
export 'src/sudoku/difficulty.dart';
export 'src/sudoku/generator.dart';
export 'src/sudoku/hint.dart';
export 'src/sudoku/logic_solver.dart';
export 'src/sudoku/puzzle.dart';
export 'src/sudoku/solver.dart';
export 'src/sudoku/spec.dart';
export 'src/sudoku/technique.dart';
export 'src/technique.dart';
