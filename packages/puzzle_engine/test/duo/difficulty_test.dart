import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

import 'difficulty_corpus.dart';

void main() {
  const DuoSpec spec = DuoSpec.standard;
  final DuoGenerator generator = DuoGenerator(spec);
  final DuoSolver solver = DuoSolver(spec);
  final DuoLogicSolver logic = DuoLogicSolver(spec);
  final DuoRater rater = DuoRater(spec);

  group('a puzzle generated for a tier really is that tier', () {
    for (final PuzzleDifficulty tier in DuoRater.tiersFor(spec)) {
      test(tier.name, () {
        for (int seed = 1; seed <= 8; seed++) {
          final DuoPuzzle puzzle = generator.generateAt(tier, seed);
          final String where = '${tier.name} seed $seed';

          expect(puzzle.difficulty, tier, reason: '$where: wrong label');
          expect(
            solver.countSolutions(puzzle.givens, puzzle.badges, limit: 2),
            1,
            reason: '$where: not exactly one solution',
          );

          final DuoSolveReport report = logic.solve(
            puzzle.givens,
            puzzle.badges,
          );
          expect(report.isSolved, isTrue, reason: '$where: would need a guess');
          expect(
            report.cells,
            puzzle.solution,
            reason: '$where: deduced a different grid',
          );
          expect(
            rater.rate(report),
            tier,
            reason: '$where: measures as something else',
          );
        }
      });
    }

    test('the 6x6 offers all five tiers', () {
      expect(DuoRater.tiersFor(spec), PuzzleDifficulty.values);
    });
  });

  group('difficulty is measured, not assumed', () {
    test('a puzzle that would need a guess is rejected, never promoted', () {
      // An empty board with no badges: it cannot be reasoned to a grid, so it
      // rates null rather than being dressed up as Fiendish.
      final DuoSolveReport stalled = logic.solve(
        List<DuoSymbol?>.filled(spec.cellCount, null),
        const <DuoBadge>[],
      );
      expect(stalled.isSolved, isFalse);
      expect(rater.rate(stalled), isNull);
    });

    test('a puzzle past the advanced set is discarded, not rated Fiendish', () {
      // Fiendish is the ceiling: the rater only ever returns a tier for a
      // report the ladder finished, and there is no rung above the advanced
      // one to promote a harder puzzle into. Every Fiendish puzzle needs the
      // advanced rung and nothing beyond it, because a puzzle that needed more
      // would not have solved at all.
      for (int seed = 1; seed <= 8; seed++) {
        final DuoPuzzle puzzle = generator.generateAt(
          PuzzleDifficulty.fiendish,
          seed,
        );
        final DuoSolveReport report = logic.solve(puzzle.givens, puzzle.badges);
        expect(report.hardestTier, TechniqueTier.advanced);
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
          final DuoPuzzle puzzle = generator.generateAt(tier, seed);
          final DuoSolveReport report = logic.solve(
            puzzle.givens,
            puzzle.badges,
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

    test('the Gentle/Easy line is where the boundaries say it is', () {
      final int line = rater.boundaries.easyFromSimpleSteps;
      for (int seed = 1; seed <= 6; seed++) {
        for (final PuzzleDifficulty tier in <PuzzleDifficulty>[
          PuzzleDifficulty.gentle,
          PuzzleDifficulty.easy,
        ]) {
          final DuoPuzzle puzzle = generator.generateAt(tier, seed);
          final DuoSolveReport report = logic.solve(
            puzzle.givens,
            puzzle.badges,
          );
          expect(report.hardestTier, TechniqueTier.simple);
          final int steps = report.countOf(TechniqueTier.simple);
          expect(
            tier == PuzzleDifficulty.easy ? steps >= line : steps < line,
            isTrue,
            reason: '${tier.name} seed $seed used $steps simple steps',
          );
        }
      }
    });
  });

  group('generation is reproducible and bounded', () {
    test('the same tier and seed give back the same puzzle', () {
      for (final PuzzleDifficulty tier in PuzzleDifficulty.values) {
        final DuoPuzzle first = generator.generateAt(tier, 77);
        final DuoPuzzle second = DuoGenerator(spec).generateAt(tier, 77);
        expect(second.givens, first.givens, reason: '${tier.name} drifted');
        expect(second.badges, first.badges);
        expect(second.solution, first.solution);
        expect(second.difficulty, tier);
      }
    });

    test('an exhausted budget fails loudly instead of spinning', () {
      // The budget is a hard cap: with none to spend it must fail cleanly
      // rather than loop, and the failure names the tier it could not reach.
      expect(
        () =>
            generator.generateAt(PuzzleDifficulty.fiendish, 1, maxAttempts: 0),
        throwsA(
          isA<DuoGenerationException>().having(
            (DuoGenerationException e) => e.target,
            'target',
            PuzzleDifficulty.fiendish,
          ),
        ),
      );
    });

    test('a Fiendish 6x6 arrives in a sensible time', () {
      // A smoke bound, not a benchmark: it catches the retry loop going
      // quadratic, not milliseconds. Generation runs on a background isolate in
      // the app, so the UI never waits on it.
      final Stopwatch watch = Stopwatch()..start();
      for (int seed = 1; seed <= 8; seed++) {
        generator.generateAt(PuzzleDifficulty.fiendish, seed);
      }
      watch.stop();
      expect(watch.elapsed, lessThan(const Duration(seconds: 10)));
    });
  });

  group('the committed corpus still measures the same', () {
    for (final DuoCorpusEntry entry in duoDifficultyCorpus) {
      final String name = '${entry.difficulty.name} seed ${entry.seed}';
      test(name, () {
        final DuoPuzzle puzzle = DuoGenerator(entry.spec)
            .generateAt(entry.difficulty, entry.seed);
        expect(
          puzzle.givens,
          entry.givenList,
          reason: '$name: the generator now produces different givens',
        );
        expect(
          puzzle.badges,
          entry.badgeList,
          reason: '$name: the generator now produces different badges',
        );

        final DuoSolveReport report = DuoLogicSolver(entry.spec)
            .solve(entry.givenList, entry.badgeList);
        expect(report.isSolved, isTrue, reason: '$name: no longer solvable');
        expect(
          DuoRater(entry.spec).rate(report),
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
