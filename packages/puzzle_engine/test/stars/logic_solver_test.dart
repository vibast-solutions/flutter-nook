import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

void main() {
  const StarsSpec spec = StarsSpec.standard;
  final StarsLogicSolver logic = StarsLogicSolver(spec);
  final StarsSolver solver = StarsSolver(spec);
  final StarsGenerator generator = StarsGenerator(spec);

  group('StarsLogicSolver', () {
    test('finishes a generated gentle puzzle using the simple rung only', () {
      final StarsPuzzle puzzle = generator.generate(3);
      final StarsSolveReport report = logic.solve(puzzle.regions);

      expect(report.isSolved, isTrue);
      expect(report.stars, solver.solve(puzzle.regions));
      // VIB-85 carries one technique; everything it did was that rung.
      expect(report.hardestTier, TechniqueTier.simple);
      expect(report.hardest, StarsTechnique.soleCandidate);
      expect(report.countOf(TechniqueTier.simple), greaterThan(0));
      expect(report.countOf(TechniqueTier.intermediate), 0);
    });

    test('places the star of a single-cell region straight away', () {
      // Region 0 is one cell; the rest of the board is split into seven other
      // regions. A unit already down to its star count is where the simple rung
      // starts, so that single cell is a star.
      final StarsPuzzle puzzle = generator.generate(3);
      final StarsSolveReport report = logic.solve(puzzle.regions);
      for (final int star in report.stars) {
        expect(puzzle.regions[star], inInclusiveRange(0, 7));
      }
      // Every region holds exactly one of the solved stars.
      final Set<int> regionsWithStars = report.stars
          .map((int cell) => puzzle.regions[cell])
          .toSet();
      expect(regionsWithStars, hasLength(8));
    });

    test('a region map with no placement comes back unsolved', () {
      // Every cell in region 0: only one star can go in it, so eight are
      // impossible.
      final List<int> impossible = List<int>.filled(spec.cellCount, 0);
      final StarsSolveReport report = logic.solve(impossible);
      expect(report.isSolved, isFalse);
    });

    test('rejects a region map of the wrong length', () {
      expect(() => logic.solve(<int>[0, 1]), throwsArgumentError);
    });
  });
}
