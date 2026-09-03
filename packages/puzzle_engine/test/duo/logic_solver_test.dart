import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

void main() {
  // A 4x4 board — two of each symbol per line, no three in a row — is small
  // enough to build the scenarios for each technique by hand.
  const DuoSpec spec = DuoSpec(size: 4);
  final DuoLogicSolver logic = DuoLogicSolver(spec);

  List<DuoSymbol?> empty() => List<DuoSymbol?>.filled(spec.cellCount, null);

  group('DuoLogicSolver simple techniques', () {
    test('a badge forces its neighbour', () {
      final List<DuoSymbol?> givens = empty()..[0] = DuoSymbol.circle;
      const DuoBadge equal = DuoBadge(a: 0, b: 1, relation: DuoRelation.equal);
      const DuoBadge differ = DuoBadge(
        a: 0,
        b: 4,
        relation: DuoRelation.unequal,
      );
      final DuoSolveReport report = logic.solve(givens, <DuoBadge>[
        equal,
        differ,
      ]);

      expect(report.cells[1], DuoSymbol.circle, reason: '= copies the symbol');
      expect(report.cells[4], DuoSymbol.square, reason: 'x takes the other');
      expect(report.countTechnique(DuoTechnique.badge), greaterThan(0));
    });

    test('a cell that would make three in a row is forced the other way', () {
      // Two circles side by side, no badges: the third cell of the row cannot be
      // a circle, so the no-three-in-a-row rule forces a square.
      final List<DuoSymbol?> givens = empty()
        ..[0] = DuoSymbol.circle
        ..[1] = DuoSymbol.circle;
      final DuoSolveReport report = logic.solve(givens, const <DuoBadge>[]);

      expect(report.cells[2], DuoSymbol.square);
      expect(report.countTechnique(DuoTechnique.noTriple), greaterThan(0));
    });

    test('a line already holding its share fills the rest', () {
      // Circles at the ends of the top row, apart so neither empty cell would
      // make three in a row — the row already has both its circles, so the two
      // gaps are squares by counting alone.
      final List<DuoSymbol?> givens = empty()
        ..[0] = DuoSymbol.circle
        ..[3] = DuoSymbol.circle;
      final DuoSolveReport report = logic.solve(givens, const <DuoBadge>[]);

      expect(report.cells[1], DuoSymbol.square);
      expect(report.cells[2], DuoSymbol.square);
      expect(report.countTechnique(DuoTechnique.lineFull), greaterThan(0));
    });

    test('stalls rather than guessing on an empty board', () {
      final DuoSolveReport report = logic.solve(empty(), const <DuoBadge>[]);
      expect(report.isSolved, isFalse);
      expect(report.cells.every((DuoSymbol? cell) => cell == null), isTrue);
      expect(report.steps, isEmpty);
    });

    test('placements it yields all match its final cells', () {
      const DuoSpec big = DuoSpec.standard;
      final DuoLogicSolver solver = DuoLogicSolver(big);
      final DuoPuzzle puzzle = DuoGenerator(big).generate(3);
      final List<DuoPlacement> steps = solver
          .placements(puzzle.givens, puzzle.badges)
          .toList();
      // A guess-free puzzle with cells left to fill: every placement is the
      // puzzle's own answer for that cell.
      expect(steps, isNotEmpty);
      for (final DuoPlacement placement in steps) {
        expect(placement.symbol, puzzle.solution[placement.index]);
      }
    });
  });

  group('DuoLogicSolver harder techniques', () {
    // The 6x6 leaves room for a pair of alike cells that has not yet filled a
    // line's quota, which the 4x4 does not.
    const DuoSpec big = DuoSpec.standard;
    final DuoLogicSolver bigLogic = DuoLogicSolver(big);
    List<DuoSymbol?> bigEmpty() => List<DuoSymbol?>.filled(big.cellCount, null);

    test('a gap between two alike is the other symbol — a sandwich', () {
      // Circles at 0 and 2 with a gap at 1: filling the gap alike would make
      // three across it, so it is a square. The row is nowhere near its three
      // circles, so this is not [DuoTechnique.lineFull]; and there is no
      // adjacent pair, so it is not [DuoTechnique.noTriple] — it is the
      // intermediate gap deduction.
      final List<DuoSymbol?> givens = bigEmpty()
        ..[0] = DuoSymbol.circle
        ..[2] = DuoSymbol.circle;
      final DuoSolveReport report = bigLogic.solve(givens, const <DuoBadge>[]);

      expect(report.cells[1], DuoSymbol.square);
      expect(report.countTechnique(DuoTechnique.sandwich), greaterThan(0));
      expect(
        report.countTechnique(DuoTechnique.noTriple),
        0,
        reason: 'a gap is not an adjacent pair',
      );
    });

    test('a Fiendish puzzle actually needs the advanced line-reading rung', () {
      // The rater calls a puzzle Fiendish only when the solve reaches the
      // advanced rung; this checks that rung is real and gets used, rather than
      // the label resting on a technique that never fires.
      final DuoPuzzle puzzle = DuoGenerator(big)
          .generateAt(PuzzleDifficulty.fiendish, 1);
      final DuoSolveReport report = bigLogic.solve(
        puzzle.givens,
        puzzle.badges,
      );
      expect(report.isSolved, isTrue);
      expect(report.countTechnique(DuoTechnique.lineReading), greaterThan(0));
      expect(report.hardestTier, TechniqueTier.advanced);
    });
  });
}
