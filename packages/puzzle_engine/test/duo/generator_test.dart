import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

/// How many seeds the sweeping tests cover.
///
/// Every generated puzzle is put through the exhaustive uniqueness check and the
/// technique solver, which is the most valuable pair of assertions in the
/// package: it is what stands behind the promise that a player never has to
/// guess. Kept high enough to be a real sweep, low enough to stay quick.
const int _seeds = 120;

void main() {
  const DuoSpec spec = DuoSpec.standard;
  final DuoGenerator generator = DuoGenerator(spec);
  final DuoSolver solver = DuoSolver(spec);
  final DuoLogicSolver logic = DuoLogicSolver(spec);

  group('DuoGenerator (6x6)', () {
    test('every generated puzzle has exactly one solution', () {
      for (int seed = 1; seed <= _seeds; seed++) {
        final DuoPuzzle puzzle = generator.generate(seed);
        expect(
          solver.countSolutions(puzzle.givens, puzzle.badges, limit: 2),
          1,
          reason: 'seed $seed produced a puzzle that is not unique',
        );
      }
    });

    test('the stated solution is that one solution', () {
      for (int seed = 1; seed <= _seeds; seed++) {
        final DuoPuzzle puzzle = generator.generate(seed);
        expect(
          solver.solve(puzzle.givens, puzzle.badges),
          puzzle.solution,
          reason: 'seed $seed disagrees with its own solution',
        );
      }
    });

    test('every solution obeys the three rules', () {
      for (int seed = 1; seed <= _seeds; seed++) {
        final DuoPuzzle puzzle = generator.generate(seed);
        _expectValidGrid(spec, puzzle, seed);
      }
    });

    test('every given agrees with the solution', () {
      for (int seed = 1; seed <= _seeds; seed++) {
        final DuoPuzzle puzzle = generator.generate(seed);
        for (int index = 0; index < spec.cellCount; index++) {
          final DuoSymbol? given = puzzle.givens[index];
          if (given != null) {
            expect(
              given,
              puzzle.solution[index],
              reason: 'seed $seed has a given that is not its own answer',
            );
          }
        }
      }
    });

    test('every generated puzzle can be finished without a guess', () {
      for (int seed = 1; seed <= _seeds; seed++) {
        final DuoPuzzle puzzle = generator.generate(seed);
        final DuoSolveReport report = logic.solve(puzzle.givens, puzzle.badges);
        expect(
          report.isSolved,
          isTrue,
          reason: 'seed $seed needs a guess the technique solver cannot make',
        );
        expect(report.cells, puzzle.solution);
      }
    });

    test('the same seed produces an identical puzzle, badges included', () {
      for (final int seed in <int>[1, 7, 99, 12345, -3]) {
        final DuoPuzzle first = DuoGenerator(spec).generate(seed);
        final DuoPuzzle second = DuoGenerator(spec).generate(seed);
        expect(second, first, reason: 'seed $seed is not reproducible');
        expect(second.givens, first.givens);
        expect(second.badges, first.badges);
        expect(second.solution, first.solution);
      }
    });

    test('different seeds generally produce different puzzles', () {
      final Set<String> distinct = <String>{};
      for (int seed = 1; seed <= 40; seed++) {
        final DuoPuzzle puzzle = generator.generate(seed);
        distinct.add(
          '${puzzle.givens.map((DuoSymbol? s) => s?.index ?? -1).join(',')}'
          '|${puzzle.badges.join(',')}',
        );
      }
      expect(distinct.length, greaterThan(30));
    });

    test('labels every puzzle with the tier the solver measures', () {
      // `generate` no longer hardcodes Gentle (VIB-93): now that there is a
      // rater, an untargeted puzzle wears the tier its own solve measures.
      final DuoRater rater = DuoRater(spec);
      for (int seed = 1; seed <= 40; seed++) {
        final DuoPuzzle puzzle = generator.generate(seed);
        expect(
          puzzle.difficulty,
          rater.rate(logic.solve(puzzle.givens, puzzle.badges)),
          reason: 'seed $seed wears a label its solve does not measure',
        );
        expect(puzzle.difficulty, isNotNull);
      }
    });

    test('leaves some cells for the player and draws some badges', () {
      // Not a rule, but a smell test: a generator that gave back the finished
      // grid every time, or one that never drew a badge, would pass every rule
      // above and be no puzzle at all.
      for (int seed = 1; seed <= 40; seed++) {
        final DuoPuzzle puzzle = generator.generate(seed);
        expect(
          puzzle.givenCount,
          lessThan(spec.cellCount),
          reason: 'seed $seed handed back a finished grid',
        );
        expect(
          puzzle.badges,
          isNotEmpty,
          reason: 'seed $seed drew no badges at all',
        );
      }
    });
  });

  group('DuoGenerator (giving up)', () {
    test('throws rather than hanging when it is given no attempts', () {
      // The budget is a hard cap: with none to spend it must fail cleanly
      // rather than loop, which is what stops a pathological request from
      // hanging the isolate it runs on.
      expect(
        () => generator.generate(1, maxAttempts: 0),
        throwsA(isA<DuoGenerationException>()),
      );
    });
  });
}

/// Checks [puzzle]'s solution obeys balance, the no-three-in-a-row rule, and
/// every one of its badges.
void _expectValidGrid(DuoSpec spec, DuoPuzzle puzzle, int seed) {
  final List<DuoSymbol> grid = puzzle.solution;
  expect(grid, hasLength(spec.cellCount));

  // Balance: [perSymbol] of each symbol in every row and column.
  for (int line = 0; line < spec.size; line++) {
    int rowCircles = 0;
    int columnCircles = 0;
    for (int i = 0; i < spec.size; i++) {
      if (grid[spec.indexOf(line, i)] == DuoSymbol.circle) {
        rowCircles++;
      }
      if (grid[spec.indexOf(i, line)] == DuoSymbol.circle) {
        columnCircles++;
      }
    }
    expect(
      rowCircles,
      spec.perSymbol,
      reason: 'seed $seed row $line unbalanced',
    );
    expect(
      columnCircles,
      spec.perSymbol,
      reason: 'seed $seed column $line unbalanced',
    );
  }

  // No run longer than the limit, in any row or column.
  for (int row = 0; row < spec.size; row++) {
    for (int column = 0; column < spec.size; column++) {
      if (column + spec.runLimit < spec.size) {
        final DuoSymbol first = grid[spec.indexOf(row, column)];
        bool allSame = true;
        for (int k = 1; k <= spec.runLimit; k++) {
          if (grid[spec.indexOf(row, column + k)] != first) {
            allSame = false;
            break;
          }
        }
        expect(allSame, isFalse, reason: 'seed $seed row run at $row,$column');
      }
      if (row + spec.runLimit < spec.size) {
        final DuoSymbol first = grid[spec.indexOf(row, column)];
        bool allSame = true;
        for (int k = 1; k <= spec.runLimit; k++) {
          if (grid[spec.indexOf(row + k, column)] != first) {
            allSame = false;
            break;
          }
        }
        expect(allSame, isFalse, reason: 'seed $seed col run at $row,$column');
      }
    }
  }

  // Every badge is satisfied by the solution.
  for (final DuoBadge badge in puzzle.badges) {
    expect(
      badge.relation.holds(grid[badge.a], grid[badge.b]),
      isTrue,
      reason: 'seed $seed breaks badge $badge',
    );
  }
}
