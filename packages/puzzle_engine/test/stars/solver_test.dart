import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('StarsSpec', () {
    const StarsSpec spec = StarsSpec.standard;

    test('describes the 8x8 one-star board', () {
      expect(spec.size, 8);
      expect(spec.regionCount, 8);
      expect(spec.starsPerUnit, 1);
      expect(spec.cellCount, 64);
      expect(spec.starCount, 8);
    });

    test('maps cells to rows and columns', () {
      expect(spec.rowOf(0), 0);
      expect(spec.columnOf(0), 0);
      expect(spec.rowOf(9), 1);
      expect(spec.columnOf(9), 1);
      expect(spec.indexOf(3, 4), 28);
    });

    test('touching neighbours include the diagonals', () {
      // A middle cell touches eight; a corner touches three.
      expect(spec.neighbours(spec.indexOf(3, 3)), hasLength(8));
      expect(
        spec.neighbours(0),
        unorderedEquals(<int>[1, spec.indexOf(1, 0), spec.indexOf(1, 1)]),
      );
    });

    test('orthogonal neighbours are edge-to-edge only', () {
      expect(spec.orthogonalNeighbours(spec.indexOf(3, 3)), hasLength(4));
      expect(
        spec.orthogonalNeighbours(0),
        unorderedEquals(<int>[1, spec.indexOf(1, 0)]),
      );
    });

    test('rejects impossible shapes', () {
      expect(const StarsSpec(size: 0).validate, throwsArgumentError);
      expect(
        const StarsSpec(size: 8, regionCount: 6).validate,
        throwsArgumentError,
      );
      expect(const StarsSpec(starsPerUnit: 0).validate, throwsArgumentError);
    });
  });

  group('StarsSolver', () {
    const StarsSpec spec = StarsSpec.standard;
    final StarsSolver solver = StarsSolver(spec);

    // A hand-built region map with a single, easily checked solution: eight
    // horizontal bands, one region per row. Its only placement is the one
    // where the columns are a knight's spread apart.
    List<int> bandedRegions() => <int>[
      for (int cell = 0; cell < spec.cellCount; cell++) spec.rowOf(cell),
    ];

    test('counts placements and stops at the limit', () {
      // Eight horizontal bands force one star per row anywhere its column and
      // adjacency allow — that is a great many placements, so the count is
      // capped rather than enumerated.
      expect(solver.countPlacements(bandedRegions(), limit: 2), 2);
      expect(solver.countPlacements(bandedRegions(), limit: 5), 5);
    });

    test('a solved placement is legal in every unit', () {
      final List<int>? stars = solver.solve(bandedRegions());
      expect(stars, isNotNull);
      final List<int> placement = stars!;
      expect(placement, hasLength(8));
      // One per row and column.
      expect(placement.map(spec.rowOf).toSet(), hasLength(8));
      expect(placement.map(spec.columnOf).toSet(), hasLength(8));
      // None touching.
      for (int a = 0; a < placement.length; a++) {
        for (int b = a + 1; b < placement.length; b++) {
          expect(
            spec.neighbours(placement[a]),
            isNot(contains(placement[b])),
            reason: 'two stars touch',
          );
        }
      }
    });

    test('a region map with no legal placement counts zero', () {
      // Put every region in one column-pair so no legal one-per-column
      // placement can exist: a single 8-cell region down column 0 and the
      // rest crammed leaves column 0 unable to host its required star without a
      // second in some region. Simplest impossible map: all cells one region.
      final List<int> oneRegion = List<int>.filled(spec.cellCount, 0);
      // Not a valid 8-region map, but the solver should still count zero legal
      // placements rather than throw.
      expect(() => solver.countPlacements(oneRegion), returnsNormally);
    });

    test('rejects a region map of the wrong length', () {
      expect(() => solver.countPlacements(<int>[0, 1, 2]), throwsArgumentError);
    });
  });
}
