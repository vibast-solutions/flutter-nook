import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

import 'difficulty_corpus.dart';

const Map<String, SudokuSpec> variants = <String, SudokuSpec>{
  '4x4': SudokuSpec.mini,
  '6x6': SudokuSpec.light,
  '9x9': SudokuSpec.classic,
};

void main() {
  group('a puzzle generated for a tier really is that tier', () {
    variants.forEach((String name, SudokuSpec spec) {
      final SudokuGenerator generator = SudokuGenerator(spec);
      final SudokuSolver solver = SudokuSolver(spec);
      final SudokuLogicSolver logic = SudokuLogicSolver(spec);
      final SudokuRater rater = SudokuRater(spec);

      for (final SudokuDifficulty tier in SudokuRater.tiersFor(spec)) {
        test('$name ${tier.label}', () {
          for (int seed = 1; seed <= 8; seed++) {
            final SudokuPuzzle puzzle = generator.generateAt(tier, seed);
            final String where = '$name ${tier.label} seed $seed';

            expect(puzzle.difficulty, tier, reason: '$where: wrong label');
            expect(
              solver.countSolutions(puzzle.givens, limit: 2),
              1,
              reason: '$where: not exactly one solution',
            );

            final SudokuSolveReport report = logic.solve(puzzle.givens);
            expect(
              report.isSolved,
              isTrue,
              reason: '$where: would need a guess',
            );
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
    });
  });

  group('tiers are offered only where they exist', () {
    test('a 4x4 is Gentle however hard you carve it', () {
      // Sixteen cells always leave something readable on its own, so the
      // hardest a 4x4 can be — a minimal grid — is still the bottom rung.
      // This is why Mini offers one tier rather than five.
      final SudokuGenerator generator = SudokuGenerator(SudokuSpec.mini);
      final SudokuLogicSolver logic = SudokuLogicSolver(SudokuSpec.mini);
      final SudokuRater rater = SudokuRater(SudokuSpec.mini);

      for (int seed = 1; seed <= 400; seed++) {
        expect(
          rater.rate(logic.solve(generator.generate(seed).givens)),
          SudokuDifficulty.gentle,
          reason: 'seed $seed was not Gentle, so Mini may have grown a ladder',
        );
      }
      expect(SudokuRater.tiersFor(SudokuSpec.mini), <SudokuDifficulty>[
        SudokuDifficulty.gentle,
      ]);
    });

    test('a 6x6 skips the middle of the ladder', () {
      // With six digits a chain cracks the grid open before a pair ever bites,
      // so Medium and Hard turn up too rarely to promise on demand.
      final SudokuGenerator generator = SudokuGenerator(SudokuSpec.light);
      final SudokuLogicSolver logic = SudokuLogicSolver(SudokuSpec.light);
      final SudokuRater rater = SudokuRater(SudokuSpec.light);
      final Map<SudokuDifficulty, int> tally = <SudokuDifficulty, int>{};

      const int grids = 400;
      for (int seed = 1; seed <= grids; seed++) {
        final SudokuDifficulty? rating = rater.rate(
          logic.solve(generator.generate(seed).givens),
        );
        if (rating != null) {
          tally.update(rating, (int n) => n + 1, ifAbsent: () => 1);
        }
      }

      final int middle =
          (tally[SudokuDifficulty.medium] ?? 0) +
          (tally[SudokuDifficulty.hard] ?? 0);
      expect(
        middle / grids,
        lessThan(0.02),
        reason: 'the middle tiers became common; 6x6 could now offer them',
      );
      expect(SudokuRater.tiersFor(SudokuSpec.light), <SudokuDifficulty>[
        SudokuDifficulty.gentle,
        SudokuDifficulty.easy,
        SudokuDifficulty.fiendish,
      ]);
    });

    test('a 9x9 spans the whole ladder', () {
      expect(SudokuRater.tiersFor(SudokuSpec.classic), SudokuDifficulty.values);
    });
  });

  group('difficulty is measured, not counted', () {
    test('every tier of a 9x9 overlaps every other on clue count', () {
      // The rule the whole model rests on. If clue count told you the tier,
      // these ranges would sit side by side instead of on top of each other.
      final SudokuGenerator generator = SudokuGenerator(SudokuSpec.classic);
      final Map<SudokuDifficulty, List<int>> counts =
          <SudokuDifficulty, List<int>>{};
      for (final SudokuDifficulty tier in SudokuDifficulty.values) {
        counts[tier] = <int>[
          for (int seed = 1; seed <= 12; seed++)
            generator.generateAt(tier, seed).givenCount,
        ];
      }

      for (final SudokuDifficulty a in SudokuDifficulty.values) {
        for (final SudokuDifficulty b in SudokuDifficulty.values) {
          if (a == b) {
            continue;
          }
          final int lowA = counts[a]!.reduce((int x, int y) => x < y ? x : y);
          final int highA = counts[a]!.reduce((int x, int y) => x > y ? x : y);
          final int lowB = counts[b]!.reduce((int x, int y) => x < y ? x : y);
          final int highB = counts[b]!.reduce((int x, int y) => x > y ? x : y);
          expect(
            lowA <= highB && lowB <= highA,
            isTrue,
            reason:
                '${a.label} ($lowA..$highA) and ${b.label} ($lowB..$highB) '
                'no longer overlap, so clue count would separate them',
          );
        }
      }
    });

    test('a puzzle that would need a guess is rejected, never promoted', () {
      final SudokuRater rater = SudokuRater(SudokuSpec.classic);
      final SudokuSolveReport stalled = SudokuLogicSolver(SudokuSpec.classic)
          .solve(List<int>.filled(SudokuSpec.classic.cellCount, 0));

      expect(stalled.isSolved, isFalse);
      expect(rater.rate(stalled), isNull);
    });

    test('the Medium/Hard line is where the boundaries say it is', () {
      final SudokuRater rater = SudokuRater(SudokuSpec.classic);
      final int line = rater.boundaries.hardFromIntermediateSteps;
      final SudokuGenerator generator = SudokuGenerator(SudokuSpec.classic);
      final SudokuLogicSolver logic = SudokuLogicSolver(SudokuSpec.classic);

      for (int seed = 1; seed <= 6; seed++) {
        for (final SudokuDifficulty tier in <SudokuDifficulty>[
          SudokuDifficulty.medium,
          SudokuDifficulty.hard,
        ]) {
          final SudokuSolveReport report = logic.solve(
            generator.generateAt(tier, seed).givens,
          );
          final int steps = report.countOf(TechniqueTier.intermediate);
          expect(
            tier == SudokuDifficulty.hard ? steps >= line : steps < line,
            isTrue,
            reason: '${tier.label} seed $seed used $steps of them',
          );
        }
      }
    });
  });

  group('generation is reproducible and bounded', () {
    test('the same tier and seed give back the same puzzle', () {
      // A save stores a seed and a tier rather than a grid, so this is the
      // property that lets a puzzle be put down and picked up again.
      final SudokuGenerator generator = SudokuGenerator(SudokuSpec.classic);
      for (final SudokuDifficulty tier in SudokuDifficulty.values) {
        final SudokuPuzzle first = generator.generateAt(tier, 77);
        final SudokuPuzzle second = SudokuGenerator(SudokuSpec.classic)
            .generateAt(tier, 77);
        expect(second.givens, first.givens, reason: '${tier.label} drifted');
        expect(second.solution, first.solution);
        expect(second.difficulty, tier);
      }
    });

    test('an impossible request fails loudly instead of spinning', () {
      expect(
        () =>
            SudokuGenerator(SudokuSpec.mini)
                .generateAt(SudokuDifficulty.fiendish, 1, maxAttempts: 5),
        throwsA(isA<SudokuGenerationException>()),
      );
    });

    test('a Fiendish 9x9 arrives in a sensible time', () {
      // A smoke bound, not a benchmark: it is here to catch the retry loop
      // going quadratic, not to police milliseconds. Generation runs on a
      // background isolate in the app, so the UI never waits on it either.
      final SudokuGenerator generator = SudokuGenerator(SudokuSpec.classic);
      final Stopwatch watch = Stopwatch()..start();
      for (int seed = 1; seed <= 5; seed++) {
        generator.generateAt(SudokuDifficulty.fiendish, seed);
      }
      watch.stop();
      expect(watch.elapsed, lessThan(const Duration(seconds: 20)));
    });
  });

  group('the committed corpus still measures the same', () {
    for (final CorpusEntry entry in difficultyCorpus) {
      final String name =
          '${entry.spec.size}x${entry.spec.size} '
          '${entry.difficulty.label} seed ${entry.seed}';
      test(name, () {
        final SudokuPuzzle puzzle = SudokuGenerator(entry.spec)
            .generateAt(entry.difficulty, entry.seed);
        expect(
          puzzle.givens,
          entry.cells,
          reason: '$name: the generator now produces a different grid',
        );

        final SudokuSolveReport report = SudokuLogicSolver(entry.spec)
            .solve(entry.cells);
        expect(report.isSolved, isTrue, reason: '$name: no longer solvable');
        expect(
          SudokuRater(entry.spec).rate(report),
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
