import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nook/content/pack_library.dart';
import 'package:nook/store/nook_database.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

/// A loader over a fixed shelf of packs, addressed by asset key.
///
/// Anything not on the shelf returns `null`, exactly as a missing asset does, so
/// a test can hand the library some packs and no others and watch it fall back.
PackAssetLoader _shelf(Map<String, Uint8List> packs) {
  return (String assetKey) async => packs[assetKey];
}

/// The bytes of a pack the way the CLI writes them: encoded, then gzipped.
Uint8List _packBytes({
  required String game,
  required PuzzleDifficulty tier,
  required int size,
  required List<PackRecord> records,
}) {
  final String text = PackCodec.encode(
    game: game,
    tier: tier.name,
    size: size,
    records: records,
  );
  return Uint8List.fromList(gzip.encode(utf8.encode(text)));
}

/// A small real Mini pack — real puzzles, so the library's solve on the way out
/// has something valid to work with.
List<PackRecord> _miniRecords(int count) {
  final SudokuGenerator gen = SudokuGenerator(SudokuSpec.mini);
  final List<PackRecord> out = <PackRecord>[];
  for (int seed = 1; out.length < count; seed++) {
    final PackRecord record = SudokuPack.record(
      gen.generateAt(PuzzleDifficulty.gentle, seed),
    );
    if (out.every((PackRecord r) => r.cells != record.cells)) {
      out.add(record);
    }
  }
  return out;
}

void main() {
  const String key = 'assets/packs/sudoku-mini-gentle.pack.gz';
  late NookDatabase db;
  late PackProgressStore progress;

  setUp(() {
    db = NookDatabase.memory();
    progress = PackProgressStore(db);
  });
  tearDown(() => db.close());

  test('hands out pack puzzles in order and never repeats one', () async {
    final List<PackRecord> records = _miniRecords(3);
    final PackLibrary library = PackLibrary(
      loader: _shelf(<String, Uint8List>{
        key: _packBytes(
          game: 'sudoku-mini',
          tier: PuzzleDifficulty.gentle,
          size: SudokuSpec.mini.size,
          records: records,
        ),
      }),
      progress: progress,
    );

    final List<int> handedOutSeeds = <int>[];
    for (int i = 0; i < 3; i++) {
      final SudokuPuzzle? puzzle = await library.takeSudoku(
        'sudoku-mini',
        SudokuSpec.mini,
        PuzzleDifficulty.gentle,
      );
      expect(puzzle, isNotNull);
      handedOutSeeds.add(puzzle!.seed);
    }

    // In the pack's own order (sorted by seed) and each seed exactly once.
    final List<int> expected = records.map((PackRecord r) => r.seed).toList()
      ..sort();
    expect(handedOutSeeds, expected);
    expect(handedOutSeeds.toSet(), hasLength(3), reason: 'no puzzle repeated');
  });

  test(
    'returns null once the pack is spent, which is the cue to generate',
    () async {
      final PackLibrary library = PackLibrary(
        loader: _shelf(<String, Uint8List>{
          key: _packBytes(
            game: 'sudoku-mini',
            tier: PuzzleDifficulty.gentle,
            size: SudokuSpec.mini.size,
            records: _miniRecords(2),
          ),
        }),
        progress: progress,
      );

      Future<SudokuPuzzle?> take() => library.takeSudoku(
        'sudoku-mini',
        SudokuSpec.mini,
        PuzzleDifficulty.gentle,
      );

      expect(await take(), isNotNull);
      expect(await take(), isNotNull);
      expect(await take(), isNull, reason: 'the pack is spent');
    },
  );

  test(
    'an absent pack gives nothing — an empty shelf breaks nothing',
    () async {
      final PackLibrary library = PackLibrary(
        loader: _shelf(<String, Uint8List>{}),
        progress: progress,
      );
      expect(
        await library.takeSudoku(
          'sudoku-mini',
          SudokuSpec.mini,
          PuzzleDifficulty.gentle,
        ),
        isNull,
      );
    },
  );

  test('unreadable bytes are treated as no pack, not a crash', () async {
    final PackLibrary library = PackLibrary(
      loader: _shelf(<String, Uint8List>{
        key: Uint8List.fromList(<int>[0, 1, 2, 3, 4]),
      }),
      progress: progress,
    );
    expect(
      await library.takeSudoku(
        'sudoku-mini',
        SudokuSpec.mini,
        PuzzleDifficulty.gentle,
      ),
      isNull,
    );
  });

  test('progress persists, so a new run carries on where the last left off', () async {
    final Map<String, Uint8List> shelf = <String, Uint8List>{
      key: _packBytes(
        game: 'sudoku-mini',
        tier: PuzzleDifficulty.gentle,
        size: SudokuSpec.mini.size,
        records: _miniRecords(3),
      ),
    };
    // First run over one database.
    final PackLibrary first = PackLibrary(
      loader: _shelf(shelf),
      progress: progress,
    );
    final SudokuPuzzle? a = await first.takeSudoku(
      'sudoku-mini',
      SudokuSpec.mini,
      PuzzleDifficulty.gentle,
    );

    // A fresh library — a new launch — over the *same* store must not hand the
    // same puzzle out again.
    final PackLibrary second = PackLibrary(
      loader: _shelf(shelf),
      progress: progress,
    );
    final SudokuPuzzle? b = await second.takeSudoku(
      'sudoku-mini',
      SudokuSpec.mini,
      PuzzleDifficulty.gentle,
    );

    expect(a!.seed, isNot(b!.seed));
  });
}
