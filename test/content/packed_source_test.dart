import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/content/pack_library.dart';
import 'package:nook/content/packed_source.dart';
import 'package:nook/games/sudoku/sudoku_controller.dart';
import 'package:nook/store/nook_database.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

Uint8List _miniPack(int count) {
  final SudokuGenerator gen = SudokuGenerator(SudokuSpec.mini);
  final List<PackRecord> records = <PackRecord>[];
  for (int seed = 1; records.length < count; seed++) {
    final PackRecord record = SudokuPack.record(
      gen.generateAt(PuzzleDifficulty.gentle, seed),
    );
    if (records.every((PackRecord r) => r.cells != record.cells)) {
      records.add(record);
    }
  }
  final String text = PackCodec.encode(
    game: 'sudoku-mini',
    tier: PuzzleDifficulty.gentle.name,
    size: SudokuSpec.mini.size,
    records: records,
  );
  return Uint8List.fromList(gzip.encode(utf8.encode(text)));
}

void main() {
  late NookDatabase db;
  setUp(() => db = NookDatabase.memory());
  tearDown(() => db.close());

  const String key = 'assets/packs/sudoku-mini-gentle.pack.gz';
  const int generatedSeed = 999999;

  test('serves the pack when it has a puzzle to give', () async {
    final PackLibrary library = PackLibrary(
      loader: (String assetKey) async => assetKey == key ? _miniPack(3) : null,
      progress: PackProgressStore(db),
    );
    final SudokuPuzzleSource source = packedSudokuSource(library);

    final SudokuPuzzle puzzle = await source(
      SudokuSpec.mini,
      PuzzleDifficulty.gentle,
      generatedSeed,
    );
    // A pack puzzle carries its own seed, never the one the caller passed for a
    // generated puzzle.
    expect(puzzle.seed, isNot(generatedSeed));
    expect(puzzle.difficulty, PuzzleDifficulty.gentle);
    expect(
      SudokuSolver(SudokuSpec.mini).countSolutions(puzzle.givens, limit: 2),
      1,
    );
  });

  test('generates on the device when the shelf is empty', () async {
    final PackLibrary library = PackLibrary(
      loader: (String assetKey) async => null,
      progress: PackProgressStore(db),
    );
    final SudokuPuzzleSource source = packedSudokuSource(library);

    final SudokuPuzzle puzzle = await source(
      SudokuSpec.mini,
      PuzzleDifficulty.gentle,
      generatedSeed,
    );
    // Nothing on the shelf, so this is the generated one, at the caller's seed —
    // and the fallback is a real puzzle, not a failure.
    expect(puzzle.seed, generatedSeed);
    expect(
      SudokuSolver(SudokuSpec.mini).countSolutions(puzzle.givens, limit: 2),
      1,
    );
  });

  test('generates once the pack behind it is spent', () async {
    final PackLibrary library = PackLibrary(
      loader: (String assetKey) async => assetKey == key ? _miniPack(1) : null,
      progress: PackProgressStore(db),
    );
    final SudokuPuzzleSource source = packedSudokuSource(library);

    final SudokuPuzzle first = await source(
      SudokuSpec.mini,
      PuzzleDifficulty.gentle,
      generatedSeed,
    );
    final SudokuPuzzle second = await source(
      SudokuSpec.mini,
      PuzzleDifficulty.gentle,
      generatedSeed,
    );

    expect(
      first.seed,
      isNot(generatedSeed),
      reason: 'first came from the pack',
    );
    expect(
      second.seed,
      generatedSeed,
      reason: 'the pack was spent, so generated',
    );
  });
}
