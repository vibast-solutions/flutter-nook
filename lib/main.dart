import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'content/pack_library.dart';
import 'content/packed_source.dart';
import 'games/stars/stars_controller.dart';
import 'games/sudoku/sudoku_controller.dart';

void main() {
  runApp(
    ProviderScope(
      // Puzzles come from the bundled packs first and are generated on the
      // device only when a pack is spent or absent (VIB-78). The wiring lives
      // here, at the app root, so a game screen still just reads its puzzle
      // source — and tests, which build their own scope, keep the plain
      // generator unless they ask for the packs.
      overrides: [
        sudokuPuzzleSourceProvider.overrideWith(
          (Ref ref) => packedSudokuSource(ref.watch(packLibraryProvider)),
        ),
        starsPuzzleSourceProvider.overrideWith(
          (Ref ref) => packedStarsSource(ref.watch(packLibraryProvider)),
        ),
      ],
      child: const NookApp(),
    ),
  );
}
