import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

void main() {
  const StarsSpec spec = StarsSpec.standard;
  final StarsLogicSolver logic = StarsLogicSolver(spec);
  final StarsSolver solver = StarsSolver(spec);
  final StarsGenerator generator = StarsGenerator(spec);

  group('StarsLogicSolver', () {
    test('finishes a gentle puzzle using the simple rungs only', () {
      final StarsPuzzle puzzle = generator.generateAt(
        PuzzleDifficulty.gentle,
        3,
      );
      final StarsSolveReport report = logic.solve(puzzle.regions);

      expect(report.isSolved, isTrue);
      expect(report.stars, solver.solve(puzzle.regions));
      // A gentle puzzle needs only the simple band.
      expect(report.hardestTier, TechniqueTier.simple);
      expect(report.hardest, StarsTechnique.regionSingle);
      expect(report.countOf(TechniqueTier.simple), greaterThan(0));
      expect(report.countOf(TechniqueTier.intermediate), 0);
    });

    test('places the star of a shrunken region straight away', () {
      final StarsPuzzle puzzle = generator.generateAt(
        PuzzleDifficulty.gentle,
        3,
      );
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
