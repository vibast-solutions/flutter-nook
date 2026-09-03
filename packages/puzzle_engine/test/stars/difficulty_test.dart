import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

import 'difficulty_corpus.dart';

void main() {
  const StarsSpec spec = StarsSpec.standard;
  final StarsGenerator generator = StarsGenerator(spec);
  final StarsSolver solver = StarsSolver(spec);
  final StarsLogicSolver logic = StarsLogicSolver(spec);
  final StarsRater rater = StarsRater(spec);

  group('a puzzle generated for a tier really is that tier', () {
    for (final PuzzleDifficulty tier in StarsRater.tiersFor(spec)) {
      test(tier.name, () {
        for (int seed = 1; seed <= 8; seed++) {
          final StarsPuzzle puzzle = generator.generateAt(tier, seed);
          final String where = '${tier.name} seed $seed';

          expect(puzzle.difficulty, tier, reason: '$where: wrong label');
          expect(
            solver.countPlacements(puzzle.regions, limit: 2),
            1,
            reason: '$where: not exactly one placement',
          );

          final StarsSolveReport report = logic.solve(puzzle.regions);
          expect(report.isSolved, isTrue, reason: '$where: would need a guess');
          expect(
            report.stars,
            puzzle.solution,
            reason: '$where: deduced a different placement',
          );
          expect(
            rater.rate(report),
            tier,
            reason: '$where: measures as something else',
          );
        }
      });
    }

    test('the 8x8 offers all five tiers', () {
      expect(StarsRater.tiersFor(spec), PuzzleDifficulty.values);
    });
  });

  group('difficulty is measured, not assumed', () {
    test('a region map that would need a guess is rejected, never promoted', () {
      // A blank single-region map: it cannot be reasoned to a placement, so it
      // rates null rather than being dressed up as Fiendish.
      final StarsSolveReport stalled = logic.solve(
        List<int>.filled(spec.cellCount, 0),
      );
      expect(stalled.isSolved, isFalse);
      expect(rater.rate(stalled), isNull);
    });

    test('a puzzle past the advanced set is discarded, not rated Fiendish', () {
      // Fiendish is the ceiling: the rater only ever returns a tier for a
      // report the ladder finished, and there is no rung above the advanced
      // one to promote a harder puzzle into.
      for (int seed = 1; seed <= 8; seed++) {
        final StarsPuzzle puzzle = generator.generateAt(
          PuzzleDifficulty.fiendish,
          seed,
        );
        final StarsSolveReport report = logic.solve(puzzle.regions);
        expect(report.hardestTier, TechniqueTier.advanced);
        // Everything the solver used was on the ladder; nothing "beyond
        // advanced" was needed, because such a puzzle would not have solved.
        expect(report.isSolved, isTrue);
      }
    });

    test('the Medium/Hard line is where the boundaries say it is', () {
      final int line = rater.boundaries.hardFromIntermediateSteps;
      for (int seed = 1; seed <= 6; seed++) {
        for (final PuzzleDifficulty tier in <PuzzleDifficulty>[
          PuzzleDifficulty.medium,
          PuzzleDifficulty.hard,
        ]) {
          final StarsSolveReport report = logic.solve(
            generator.generateAt(tier, seed).regions,
          );
          final int steps = report.countOf(TechniqueTier.intermediate);
          expect(
            tier == PuzzleDifficulty.hard ? steps >= line : steps < line,
            isTrue,
            reason: '${tier.name} seed $seed used $steps intermediate steps',
          );
        }
      }
    });
  });

  group('generation is reproducible and bounded', () {
    test('the same tier and seed give back the same puzzle', () {
      for (final PuzzleDifficulty tier in PuzzleDifficulty.values) {
        final StarsPuzzle first = generator.generateAt(tier, 77);
        final StarsPuzzle second = StarsGenerator(spec).generateAt(tier, 77);
        expect(second.regions, first.regions, reason: '${tier.name} drifted');
        expect(second.solution, first.solution);
        expect(second.difficulty, tier);
      }
    });

    test('an impossible request fails loudly instead of spinning', () {
      // A 2x2 has no legal placement at all, so no tier can be produced.
      expect(
        () =>
            StarsGenerator(const StarsSpec(size: 2))
                .generateAt(PuzzleDifficulty.gentle, 1, maxAttempts: 10),
        throwsA(isA<StarsGenerationException>()),
      );
    });

    test('a Fiendish 8x8 arrives in a sensible time', () {
      // A smoke bound, not a benchmark: it catches the retry loop going
      // quadratic, not milliseconds. Generation runs on a background isolate in
      // the app, so the UI never waits on it.
      final Stopwatch watch = Stopwatch()..start();
      for (int seed = 1; seed <= 5; seed++) {
        generator.generateAt(PuzzleDifficulty.fiendish, seed);
      }
      watch.stop();
      expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
    });
  });

  group('the committed corpus still measures the same', () {
    for (final StarsCorpusEntry entry in starsDifficultyCorpus) {
      final String name = '${entry.difficulty.name} seed ${entry.seed}';
      test(name, () {
        final StarsPuzzle puzzle = StarsGenerator(entry.spec)
            .generateAt(entry.difficulty, entry.seed);
        expect(
          puzzle.regions,
          entry.regionList,
          reason: '$name: the generator now produces a different region map',
        );

        final StarsSolveReport report = StarsLogicSolver(entry.spec)
            .solve(entry.regionList);
        expect(report.isSolved, isTrue, reason: '$name: no longer solvable');
        expect(
          StarsRater(entry.spec).rate(report),
          entry.difficulty,
          reason: '$name: measures as a different tier now',
        );
        expect(
          report.hardest,
          entry.hardest,
          reason: '$name: needs a different technique now',
        );
        expect(
          report.steps.values.reduce((int a, int b) => a + b),
          entry.deductions,
          reason: '$name: takes a different number of deductions now',
        );
      });
    }
  });
}
