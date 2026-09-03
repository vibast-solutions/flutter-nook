import 'package:flutter_test/flutter_test.dart';
import 'package:nook/games/stars/stars_state.dart';
import 'package:nook/games/stars/stars_variant.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../support/stars_fixture.dart';

/// A game whose board is the solution of [puzzle], as stars.
StarsGameState solved(StarsPuzzle puzzle) {
  final List<StarsMark> cells = List<StarsMark>.filled(
    puzzle.spec.cellCount,
    StarsMark.empty,
  );
  for (final int star in puzzle.solution) {
    cells[star] = StarsMark.star;
  }
  return StarsGameState(
    variant: StarsVariant.standard,
    puzzle: puzzle,
    cells: cells,
  );
}

void main() {
  group('StarsGameState', () {
    test('a fresh game is empty and unsolved', () {
      final StarsGameState game = StarsGameState.fresh(
        variant: StarsVariant.standard,
        puzzle: fixedStarsPuzzle(),
      );
      expect(game.starCount, 0);
      expect(game.starTarget, 8);
      expect(game.isSolved, isFalse);
      expect(game.cells, everyElement(StarsMark.empty));
      expect(game.canUndo, isFalse);
    });

    test('the solution, placed as stars, is solved', () {
      final StarsGameState game = solved(fixedStarsPuzzle());
      expect(game.starCount, 8);
      expect(game.isSolved, isTrue);
    });

    test('is judged by the rules, never by the stored solution', () {
      // The solution-swap guard: replace the puzzle's own solution with a
      // different one and the verdict must not budge. Anything reading the
      // answer instead of the rules would change its mind here.
      final StarsPuzzle real = fixedStarsPuzzle();
      final StarsPuzzle lying = StarsPuzzle(
        spec: real.spec,
        seed: real.seed,
        regions: real.regions,
        // A wrong "solution": the first eight cells, which break every rule.
        solution: <int>[0, 1, 2, 3, 4, 5, 6, 7],
      );

      // The board carries the *real* answer in both games; only the puzzle's
      // claimed solution differs. Judged by the rules the verdict is the same,
      // which it could not be if anything read the stored answer.
      final List<StarsMark> answer = solved(real).cells;
      final StarsGameState honest = StarsGameState(
        variant: StarsVariant.standard,
        puzzle: real,
        cells: answer,
      );
      final StarsGameState fooled = StarsGameState(
        variant: StarsVariant.standard,
        puzzle: lying,
        cells: answer,
      );
      expect(honest.isSolved, isTrue);
      expect(fooled.isSolved, isTrue);
    });

    test('a full board that breaks a rule is not solved', () {
      final StarsPuzzle puzzle = fixedStarsPuzzle();
      final StarsGameState game = solved(puzzle);
      // Take one star off and drop it next to another: eight stars still, but
      // now two of them touch, so the board is not solved.
      final int removed = puzzle.solution.first;
      final int touching = puzzle.spec.neighbours(puzzle.solution[1]).first;
      final List<StarsMark> cells = List<StarsMark>.of(game.cells)
        ..[removed] = StarsMark.empty
        ..[touching] = StarsMark.star;
      final StarsGameState broken = game.copyWith(cells: cells);
      expect(broken.starCount, 8);
      expect(broken.isSolved, isFalse);
    });

    test(
      'a ruled-out dot is only an annotation — it never solves anything',
      () {
        final StarsPuzzle puzzle = fixedStarsPuzzle();
        final List<StarsMark> cells = List<StarsMark>.filled(
          puzzle.spec.cellCount,
          StarsMark.ruledOut,
        );
        final StarsGameState game = StarsGameState(
          variant: StarsVariant.standard,
          puzzle: puzzle,
          cells: cells,
        );
        expect(game.starCount, 0);
        expect(game.isSolved, isFalse);
      },
    );
  });
}
