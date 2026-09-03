import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PackCodec', () {
    test('round-trips a pack through encode and decode', () {
      final List<PackRecord> records = <PackRecord>[
        const PackRecord(
          seed: 7,
          cells: '1234',
          techniques: <String, int>{'nakedSingle': 3},
        ),
        const PackRecord(seed: 3, cells: '4321', techniques: <String, int>{}),
      ];
      final String text = PackCodec.encode(
        game: 'sudoku-mini',
        tier: 'gentle',
        size: 2,
        records: records,
      );
      final PuzzlePack pack = PackCodec.decode(text);

      expect(pack.header.game, 'sudoku-mini');
      expect(pack.header.tier, 'gentle');
      expect(pack.header.size, 2);
      expect(pack.header.count, 2);
      // Sorted by seed, whatever order they went in.
      expect(pack.records.map((PackRecord r) => r.seed), <int>[3, 7]);
      expect(pack.records.first.cells, '4321');
      expect(pack.records.first.techniques, isEmpty);
      expect(pack.records.last.techniques, <String, int>{'nakedSingle': 3});
    });

    test('is deterministic: the same records encode to the same text', () {
      List<PackRecord> records() => <PackRecord>[
        const PackRecord(
          seed: 11,
          cells: '....',
          techniques: <String, int>{'hiddenSingle': 2, 'nakedPair': 1},
        ),
        const PackRecord(
          seed: 2,
          cells: '1..4',
          techniques: <String, int>{'nakedSingle': 9},
        ),
      ];
      final String a = PackCodec.encode(
        game: 'g',
        tier: 't',
        size: 2,
        records: records(),
      );
      final String b = PackCodec.encode(
        game: 'g',
        tier: 't',
        size: 2,
        records: records(),
      );
      expect(a, b);
    });

    test('rejects a header that is not a pack', () {
      expect(
        () => PackCodec.decode('not a pack header\n'),
        throwsA(isA<PackFormatException>()),
      );
    });

    test('rejects a record count that disagrees with the header', () {
      const String text = 'nook-pack 1 g t 2 2\n1 1234 -\n';
      expect(() => PackCodec.decode(text), throwsA(isA<PackFormatException>()));
    });

    test('rejects a cell token of the wrong width', () {
      const String text = 'nook-pack 1 g t 2 1\n1 123 -\n';
      expect(() => PackCodec.decode(text), throwsA(isA<PackFormatException>()));
    });

    test('rejects a malformed technique token', () {
      const String text = 'nook-pack 1 g t 2 1\n1 1234 nakedSingle\n';
      expect(() => PackCodec.decode(text), throwsA(isA<PackFormatException>()));
    });
  });

  group('SudokuPack', () {
    test('a record becomes the puzzle it came from', () {
      const SudokuSpec spec = SudokuSpec.classic;
      final SudokuPuzzle puzzle = SudokuGenerator(spec)
          .generateAt(PuzzleDifficulty.hard, 12345);
      final PackRecord record = SudokuPack.record(puzzle);
      final SudokuPuzzle rebuilt = SudokuPack.puzzle(
        record,
        spec,
        PuzzleDifficulty.hard,
      );

      expect(rebuilt.givens, puzzle.givens);
      expect(rebuilt.solution, puzzle.solution);
      expect(rebuilt.seed, puzzle.seed);
      expect(rebuilt.difficulty, PuzzleDifficulty.hard);
    });

    test('a shipped-tier record has exactly one solution and rates true', () {
      const SudokuSpec spec = SudokuSpec.classic;
      for (final PuzzleDifficulty tier in <PuzzleDifficulty>[
        PuzzleDifficulty.medium,
        PuzzleDifficulty.hard,
        PuzzleDifficulty.fiendish,
      ]) {
        final SudokuPuzzle puzzle = SudokuGenerator(spec)
            .generateAt(tier, 500 + tier.index);
        final PackRecord record = SudokuPack.record(puzzle);
        final SudokuPuzzle rebuilt = SudokuPack.puzzle(record, spec, tier);

        expect(
          SudokuSolver(spec).countSolutions(rebuilt.givens, limit: 2),
          1,
          reason: '${tier.name} pack puzzle must be unique',
        );
        final PuzzleDifficulty? rated = SudokuRater(spec)
            .rate(SudokuLogicSolver(spec).solve(rebuilt.givens));
        expect(rated, tier, reason: 'the stored tier must be the measured one');
      }
    });

    test('encoding the techniques is deterministic and hardest-last', () {
      const SudokuSpec spec = SudokuSpec.classic;
      final SudokuPuzzle puzzle = SudokuGenerator(spec)
          .generateAt(PuzzleDifficulty.hard, 999);
      final PackRecord a = SudokuPack.record(puzzle);
      final PackRecord b = SudokuPack.record(puzzle);
      expect(a.techniques, b.techniques);

      // The keys come out in ladder order, so the last is the hardest.
      final List<int> indices = a.techniques.keys
          .map((String name) => SudokuTechnique.values.byName(name).index)
          .toList();
      final List<int> sorted = List<int>.of(indices)..sort();
      expect(indices, sorted);
    });

    test('a corrupt record is refused rather than returned broken', () {
      const SudokuSpec spec = SudokuSpec.classic;
      // A grid of all ones cannot be a Sudoku: no solution.
      final PackRecord record = PackRecord(
        seed: 1,
        cells: '1' * spec.cellCount,
        techniques: const <String, int>{},
      );
      expect(
        () => SudokuPack.puzzle(record, spec, PuzzleDifficulty.hard),
        throwsA(isA<PackFormatException>()),
      );
    });
  });

  group('StarsPack', () {
    test('a record becomes the puzzle it came from', () {
      const StarsSpec spec = StarsSpec.standard;
      final StarsPuzzle puzzle = StarsGenerator(spec)
          .generateAt(PuzzleDifficulty.fiendish, 4242);
      final PackRecord record = StarsPack.record(puzzle);
      final StarsPuzzle rebuilt = StarsPack.puzzle(
        record,
        spec,
        PuzzleDifficulty.fiendish,
      );

      expect(rebuilt.regions, puzzle.regions);
      expect(rebuilt.solution, puzzle.solution);
      expect(rebuilt.seed, puzzle.seed);
      expect(rebuilt.difficulty, PuzzleDifficulty.fiendish);
    });

    test('a shipped-tier record admits one placement and rates true', () {
      const StarsSpec spec = StarsSpec.standard;
      for (final PuzzleDifficulty tier in <PuzzleDifficulty>[
        PuzzleDifficulty.easy,
        PuzzleDifficulty.medium,
        PuzzleDifficulty.hard,
        PuzzleDifficulty.fiendish,
      ]) {
        final StarsPuzzle puzzle = StarsGenerator(spec)
            .generateAt(tier, 700 + tier.index);
        final PackRecord record = StarsPack.record(puzzle);
        final StarsPuzzle rebuilt = StarsPack.puzzle(record, spec, tier);

        expect(
          StarsSolver(spec).countPlacements(rebuilt.regions, limit: 2),
          1,
          reason: '${tier.name} pack puzzle must be unique',
        );
        final PuzzleDifficulty? rated = StarsRater(spec)
            .rate(StarsLogicSolver(spec).solve(rebuilt.regions));
        expect(rated, tier, reason: 'the stored tier must be the measured one');
      }
    });
  });
}
