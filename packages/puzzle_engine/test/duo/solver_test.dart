import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

void main() {
  const DuoSpec spec = DuoSpec.standard;
  final DuoSolver solver = DuoSolver(spec);
  final DuoGenerator generator = DuoGenerator(spec);

  List<DuoSymbol?> empty() => List<DuoSymbol?>.filled(spec.cellCount, null);

  group('DuoSolver', () {
    test('an empty 6x6 has more than one completion', () {
      // No givens, no badges: the board is wide open, so the count runs up to
      // the limit rather than settling on one.
      expect(solver.countSolutions(empty(), const <DuoBadge>[], limit: 2), 2);
    });

    test('a finished grid is its own single completion', () {
      final DuoPuzzle puzzle = generator.generate(11);
      final List<DuoSymbol?> full = List<DuoSymbol?>.of(puzzle.solution);
      expect(solver.countSolutions(full, const <DuoBadge>[], limit: 2), 1);
      expect(solver.solve(full, const <DuoBadge>[]), puzzle.solution);
    });

    test('a given that disagrees with the answer admits no completion', () {
      // Flip one cell of the finished grid: its row and column no longer hold
      // their share of each symbol, so the board is unbalanced and no
      // completion of it exists. (Flipping one of the *carved* givens is not a
      // safe test — a necessary given removed and negated can leave a different
      // whole grid standing — so the assertion is pinned to the full solution,
      // which cannot.)
      final DuoPuzzle puzzle = generator.generate(11);
      final List<DuoSymbol?> broken = List<DuoSymbol?>.of(puzzle.solution);
      broken[0] = puzzle.solution[0].other;
      expect(solver.countSolutions(broken, const <DuoBadge>[], limit: 2), 0);
    });

    test('a badge the givens break admits no completion', () {
      // Two adjacent givens that differ, with an `=` badge insisting they match.
      final List<DuoSymbol?> givens = empty()
        ..[0] = DuoSymbol.circle
        ..[1] = DuoSymbol.square;
      const DuoBadge equal = DuoBadge(a: 0, b: 1, relation: DuoRelation.equal);
      expect(solver.countSolutions(givens, <DuoBadge>[equal], limit: 2), 0);
    });

    test('honours a badge while completing the rest', () {
      final DuoPuzzle puzzle = generator.generate(11);
      final List<DuoSymbol> found = solver.solve(puzzle.givens, puzzle.badges)!;
      for (final DuoBadge badge in puzzle.badges) {
        expect(badge.relation.holds(found[badge.a], found[badge.b]), isTrue);
      }
    });
  });
}
