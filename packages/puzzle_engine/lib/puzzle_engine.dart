/// The rules behind every game in Nook.
///
/// This package is pure Dart on purpose. It must not import `package:flutter`,
/// touch the filesystem or read the clock: it is the one place puzzle
/// correctness lives, so it has to be testable exhaustively without a device
/// and reproducible from a seed alone.
library;

export 'src/difficulty.dart';
export 'src/random.dart';
export 'src/stars/difficulty.dart';
export 'src/stars/generator.dart';
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
