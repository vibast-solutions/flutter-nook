import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

/// How many seeds the sweeping tests cover.
///
/// Every generated puzzle is put through the exhaustive uniqueness check and
/// the technique solver, which is the most valuable pair of assertions in the
/// package: it is what stands behind the promise that a player never has to
/// guess. Kept high enough to be a real sweep, low enough to stay quick.
const int _seeds = 120;

void main() {
  const StarsSpec spec = StarsSpec.standard;
  final StarsGenerator generator = StarsGenerator(spec);
  final StarsSolver solver = StarsSolver(spec);
  final StarsLogicSolver logic = StarsLogicSolver(spec);

  group('StarsGenerator (8x8)', () {
    test('every generated puzzle has exactly one placement', () {
      for (int seed = 1; seed <= _seeds; seed++) {
        final StarsPuzzle puzzle = generator.generate(seed);
        expect(
          solver.countPlacements(puzzle.regions, limit: 2),
          1,
          reason: 'seed $seed produced a puzzle that is not unique',
        );
      }
    });

    test('the stated solution is that one placement', () {
      for (int seed = 1; seed <= _seeds; seed++) {
        final StarsPuzzle puzzle = generator.generate(seed);
        expect(
          solver.solve(puzzle.regions),
          puzzle.solution,
          reason: 'seed $seed disagrees with its own solution',
        );
        // One star per row, per column and per region, none touching.
        expect(puzzle.solution, hasLength(8));
        expect(puzzle.solution.map(spec.rowOf).toSet(), hasLength(8));
        expect(puzzle.solution.map(spec.columnOf).toSet(), hasLength(8));
        expect(
          puzzle.solution.map((int cell) => puzzle.regions[cell]).toSet(),
          hasLength(8),
        );
        for (int a = 0; a < puzzle.solution.length; a++) {
          for (int b = a + 1; b < puzzle.solution.length; b++) {
            expect(
              spec.neighbours(puzzle.solution[a]),
              isNot(contains(puzzle.solution[b])),
              reason: 'seed $seed has two stars touching',
            );
          }
        }
      }
    });

    test('every generated puzzle can be finished without a guess', () {
      for (int seed = 1; seed <= _seeds; seed++) {
        final StarsPuzzle puzzle = generator.generate(seed);
        final StarsSolveReport report = logic.solve(puzzle.regions);
        expect(
          report.isSolved,
          isTrue,
          reason: 'seed $seed needs a guess the technique solver cannot make',
        );
        expect(report.stars, puzzle.solution);
      }
    });

    test('the regions are eight contiguous blobs covering every cell', () {
      for (int seed = 1; seed <= _seeds; seed++) {
        final StarsPuzzle puzzle = generator.generate(seed);
        expect(puzzle.regions, hasLength(64));
        _expectSaneRegions(spec, puzzle.regions, seed);
      }
    });

    test('is gentle, and says so', () {
      final StarsPuzzle puzzle = generator.generate(7);
      expect(puzzle.difficulty, PuzzleDifficulty.gentle);
    });

    test('the same seed produces an identical puzzle', () {
      for (final int seed in <int>[1, 7, 99, 12345, -3]) {
        final StarsPuzzle first = StarsGenerator(spec).generate(seed);
        final StarsPuzzle second = StarsGenerator(spec).generate(seed);
        expect(second, first, reason: 'seed $seed is not reproducible');
        expect(second.regions, first.regions);
        expect(second.solution, first.solution);
      }
    });

    test('different seeds generally produce different puzzles', () {
      final Set<String> distinct = <String>{};
      for (int seed = 1; seed <= 40; seed++) {
        distinct.add(generator.generate(seed).regions.join(','));
      }
      expect(distinct.length, greaterThan(30));
    });
  });

  group('StarsGenerator (giving up)', () {
    test('throws rather than hanging when nothing can satisfy the request', () {
      // A 2x2 board cannot hold two non-touching stars — every pair of cells
      // touches — so no placement exists and generation must fail cleanly
      // rather than loop for ever.
      const StarsSpec tiny = StarsSpec(size: 2);
      expect(
        () => StarsGenerator(tiny).generate(1, maxAttempts: 20),
        throwsA(isA<StarsGenerationException>()),
      );
    });
  });
}

/// Checks [regions] is a partition of the grid into [StarsSpec.regionCount]
/// edge-connected regions that between them cover every cell exactly once.
void _expectSaneRegions(StarsSpec spec, List<int> regions, int seed) {
  final List<int> sizes = List<int>.filled(spec.regionCount, 0);
  for (final int region in regions) {
    expect(
      region,
      inInclusiveRange(0, spec.regionCount - 1),
      reason: 'seed $seed has a cell in no region',
    );
    sizes[region]++;
  }
  for (int region = 0; region < spec.regionCount; region++) {
    expect(sizes[region], greaterThan(0), reason: 'seed $seed empty region');
  }

  // Contiguity: a flood from the first cell of each region reaches all of it.
  for (int region = 0; region < spec.regionCount; region++) {
    final int start = regions.indexOf(region);
    final Set<int> seen = <int>{start};
    final List<int> queue = <int>[start];
    while (queue.isNotEmpty) {
      final int cell = queue.removeLast();
      for (final int neighbour in spec.orthogonalNeighbours(cell)) {
        if (regions[neighbour] == region && seen.add(neighbour)) {
          queue.add(neighbour);
        }
      }
    }
    expect(
      seen.length,
      sizes[region],
      reason: 'seed $seed region $region is not contiguous',
    );
  }
}
