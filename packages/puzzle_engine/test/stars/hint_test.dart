import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

/// A region map that puts every cell of a row in one region — one region per
/// row.
///
/// It is a legal partition, so the board has stars to find, but nothing about
/// it forces a single placement: the technique solver stalls on it at once.
/// That is exactly the shape a hinter's fallback exists for, so it stands in for
/// "a puzzle logic cannot finish" without needing one the generator would never
/// make.
List<int> bandedRegions(StarsSpec spec) => <int>[
  for (int cell = 0; cell < spec.cellCount; cell++) cell ~/ spec.size,
];

void main() {
  const StarsSpec spec = StarsSpec.standard;
  final StarsGenerator generator = StarsGenerator(spec);

  group('StarsHinter', () {
    test('a hint is a star the player could have worked out', () {
      final StarsPuzzle puzzle = generator.generate(2026);
      final StarsHint? hint = StarsHinter(puzzle).hintFor(const <int>{});

      expect(hint, isNotNull);
      expect(hint!.isDeduced, isTrue);
      expect(hint.technique, isNotNull);
      expect(
        puzzle.solution,
        contains(hint.index),
        reason: 'a hint has to agree with the puzzle it came from',
      );
    });

    test('it gives the next justified star for a partly-solved board', () {
      final StarsPuzzle puzzle = generator.generate(2026);
      final StarsHinter hinter = StarsHinter(puzzle);

      // The star the solver reaches first, then the same board with it down.
      final StarsHint first = hinter.hintFor(const <int>{})!;
      final StarsHint next = hinter.hintFor(<int>{first.index})!;

      expect(next.index, isNot(first.index));
      expect(next.isDeduced, isTrue);
      expect(puzzle.solution, contains(next.index));
    });

    test('hint after hint finishes the puzzle', () {
      // The property that matters most: a hint is always available while the
      // board has a star missing, always correct, and always moves it on. A
      // player leaning on hints alone must reach a solved board.
      final StarsPuzzle puzzle = generator.generate(5);
      final StarsHinter hinter = StarsHinter(puzzle);
      final Set<int> stars = <int>{};

      for (int step = 0; step < spec.cellCount; step++) {
        final StarsHint? hint = hinter.hintFor(stars);
        if (hint == null) {
          break;
        }
        expect(stars, isNot(contains(hint.index)));
        stars.add(hint.index);
      }

      expect(stars.toList()..sort(), puzzle.solution);
      expect(hinter.hintFor(stars), isNull);
    });

    test('it never targets a cell that already holds a star', () {
      final StarsPuzzle puzzle = generator.generate(9);
      final StarsHinter hinter = StarsHinter(puzzle);

      // Half the solution already placed, plus a wrong star the player put in a
      // cell the solution leaves empty. A hint has to skip every one of them.
      final int wrong = _nonSolutionCell(puzzle);
      final Set<int> stars = <int>{...puzzle.solution.take(4), wrong};

      final StarsHint hint = hinter.hintFor(stars)!;

      expect(stars, isNot(contains(hint.index)));
      expect(
        hint.index,
        isNot(wrong),
        reason: 'it offered to write over the player\'s own star',
      );
    });

    test('a solved board has no hint left in it', () {
      final StarsPuzzle puzzle = generator.generate(4);

      expect(StarsHinter(puzzle).hintFor(puzzle.solution.toSet()), isNull);
    });

    test('a puzzle logic cannot finish still gives a star away', () {
      // A banded region map has many solutions, so the technique solver refuses
      // to guess and places nothing. The hint comes off the solution instead of
      // a deduction. The generator never produces one of these; a save from an
      // older build one day might.
      final List<int> regions = bandedRegions(spec);
      final List<int> solution = StarsSolver(spec).solve(regions)!;
      final StarsPuzzle stuck = StarsPuzzle(
        spec: spec,
        seed: 0,
        regions: regions,
        solution: solution,
      );

      final StarsHint? hint = StarsHinter(stuck).hintFor(const <int>{});

      expect(hint, isNotNull);
      expect(hint!.isDeduced, isFalse);
      expect(hint.technique, isNull);
      expect(solution, contains(hint.index));
    });
  });
}

/// The first cell that holds no star in [puzzle]'s solution — somewhere a wrong
/// star can go without standing on the answer.
int _nonSolutionCell(StarsPuzzle puzzle) {
  for (int index = 0; index < puzzle.spec.cellCount; index++) {
    if (!puzzle.solution.contains(index)) {
      return index;
    }
  }
  throw StateError('every cell is a star, which no Stars board is');
}
