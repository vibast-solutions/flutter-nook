/// The rules behind every game in Nook.
///
/// This package is pure Dart on purpose. It must not import `package:flutter`,
/// touch the filesystem or read the clock: it is the one place puzzle
/// correctness lives, so it has to be testable exhaustively without a device
/// and reproducible from a seed alone.
library;

export 'src/random.dart';
export 'src/sudoku/generator.dart';
export 'src/sudoku/puzzle.dart';
export 'src/sudoku/solver.dart';
export 'src/sudoku/spec.dart';
