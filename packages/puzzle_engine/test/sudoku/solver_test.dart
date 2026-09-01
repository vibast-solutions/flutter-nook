import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SudokuSpec', () {
    test('describes 4x4, 6x6 and 9x9 grids', () {
      expect(SudokuSpec.mini.size, 4);
      expect(SudokuSpec.mini.cellCount, 16);
      expect(SudokuSpec.light.size, 6);
      expect(SudokuSpec.classic.size, 9);
      expect(SudokuSpec.classic.cellCount, 81);
    });

    test('maps cells to boxes for square boxes', () {
      const SudokuSpec spec = SudokuSpec.mini;
      // Top-left box holds cells 0, 1, 4, 5.
      expect(<int>[0, 1, 4, 5].map(spec.boxOf), everyElement(0));
      // Bottom-right box holds cells 10, 11, 14, 15.
      expect(<int>[10, 11, 14, 15].map(spec.boxOf), everyElement(3));
    });

    test('maps cells to boxes for wide boxes', () {
      // 6x6 with 3-wide, 2-tall boxes: two boxes across, three down.
      const SudokuSpec spec = SudokuSpec.light;
      expect(spec.boxesAcross, 2);
      expect(spec.boxesDown, 3);
      expect(<int>[0, 1, 2, 6, 7, 8].map(spec.boxOf), everyElement(0));
      expect(<int>[3, 4, 5, 9, 10, 11].map(spec.boxOf), everyElement(1));
      expect(<int>[24, 25, 26, 30, 31, 32].map(spec.boxOf), everyElement(4));
    });

    test('rejects impossible shapes', () {
      expect(
        const SudokuSpec(boxWidth: 0, boxHeight: 3).validate,
        throwsArgumentError,
      );
      expect(
        const SudokuSpec(boxWidth: 9, boxHeight: 9).validate,
        throwsArgumentError,
      );
    });
  });

  group('SudokuSolver', () {
    test('solves a grid with a single solution', () {
      final SudokuSolver solver = SudokuSolver(SudokuSpec.mini);
      // One cell missing; only 3 fits.
      final List<int> cells = <int>[
        1, 2, 3, 4, //
        3, 4, 1, 2, //
        2, 1, 4, 0, //
        4, 3, 2, 1, //
      ];
      expect(solver.countSolutions(cells), 1);
      expect(solver.solve(cells)![11], 3);
    });

    test('counts an empty grid as more than one solution', () {
      final SudokuSolver solver = SudokuSolver(SudokuSpec.mini);
      final List<int> empty = List<int>.filled(16, 0);
      expect(solver.countSolutions(empty), 2, reason: 'stops at the limit');
    });

    test('reports a contradictory grid as unsolvable', () {
      final SudokuSolver solver = SudokuSolver(SudokuSpec.mini);
      final List<int> cells = List<int>.filled(16, 0);
      cells[0] = 1;
      cells[1] = 1; // Same digit twice in row 0.
      expect(solver.countSolutions(cells), 0);
      expect(solver.solve(cells), isNull);
      expect(solver.isConsistent(cells), isFalse);
    });

    test('reports a grid with no completion as unsolvable', () {
      final SudokuSolver solver = SudokuSolver(SudokuSpec.mini);
      // Legal so far, but cell 3 can then hold nothing.
      final List<int> cells = <int>[
        1, 2, 3, 0, //
        0, 0, 0, 4, //
        0, 0, 0, 0, //
        0, 0, 0, 0, //
      ];
      expect(solver.isConsistent(cells), isTrue);
      expect(solver.countSolutions(cells), 0);
    });

    test('recognises a completed grid', () {
      final SudokuSolver solver = SudokuSolver(SudokuSpec.mini);
      final List<int> solved = <int>[
        1, 2, 3, 4, //
        3, 4, 1, 2, //
        2, 1, 4, 3, //
        4, 3, 2, 1, //
      ];
      expect(solver.isSolved(solved), isTrue);

      final List<int> incomplete = List<int>.of(solved)..[0] = 0;
      expect(solver.isSolved(incomplete), isFalse);

      final List<int> broken = List<int>.of(solved)..[0] = 2;
      expect(solver.isSolved(broken), isFalse);
    });

    test('rejects a grid of the wrong length', () {
      final SudokuSolver solver = SudokuSolver(SudokuSpec.mini);
      expect(
        () => solver.countSolutions(List<int>.filled(15, 0)),
        throwsArgumentError,
      );
    });

    test('fillRandom produces a valid complete grid', () {
      for (final SudokuSpec spec in <SudokuSpec>[
        SudokuSpec.mini,
        SudokuSpec.light,
        SudokuSpec.classic,
      ]) {
        final SudokuSolver solver = SudokuSolver(spec);
        final PuzzleRandom random = PuzzleRandom(spec.size);
        final List<int> grid = solver.fillRandom(random.nextInt);
        expect(grid, hasLength(spec.cellCount));
        expect(solver.isSolved(grid), isTrue, reason: '$spec');
      }
    });
  });

  group('PuzzleRandom', () {
    test('is reproducible from a seed', () {
      final List<int> first = List<int>.generate(
        20,
        (_) => PuzzleRandom(7).nextInt(1000),
      );
      expect(
        first,
        everyElement(first.first),
        reason: 'a fresh generator repeats itself',
      );

      final PuzzleRandom a = PuzzleRandom(42);
      final PuzzleRandom b = PuzzleRandom(42);
      for (int i = 0; i < 200; i++) {
        expect(a.nextInt(100), b.nextInt(100));
      }
    });

    test('stays inside the requested range', () {
      final PuzzleRandom random = PuzzleRandom(1);
      for (int i = 0; i < 500; i++) {
        final int value = random.nextInt(6);
        expect(value, inInclusiveRange(0, 5));
      }
    });

    test('covers the whole range', () {
      final PuzzleRandom random = PuzzleRandom(3);
      final Set<int> seen = <int>{};
      for (int i = 0; i < 200; i++) {
        seen.add(random.nextInt(4));
      }
      expect(seen, <int>{0, 1, 2, 3});
    });

    test('survives a zero seed', () {
      expect(() => PuzzleRandom(0).nextInt(4), returnsNormally);
    });

    test('rejects a non-positive bound', () {
      expect(() => PuzzleRandom(1).nextInt(0), throwsArgumentError);
    });

    test('shuffle is a permutation and depends on the seed', () {
      List<int> shuffled(int seed) {
        final List<int> list = List<int>.generate(20, (int i) => i);
        PuzzleRandom(seed).shuffle(list);
        return list;
      }

      final List<int> a = shuffled(11);
      expect(a..sort(), List<int>.generate(20, (int i) => i));
      expect(shuffled(11), shuffled(11));
      expect(shuffled(11), isNot(shuffled(12)));
    });
  });
}
