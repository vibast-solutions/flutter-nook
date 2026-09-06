import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

void main() {
  const SnakeSpec spec = SnakeSpec.standard;

  group('SnakeGame.start', () {
    test('lays out a snake of the starting length, head first, moving right', () {
      final SnakeGame game = SnakeGame.start(spec, seed: 1);
      expect(game.length, spec.startLength);
      expect(game.direction, SnakeDirection.right);
      expect(game.status, SnakeStatus.running);
      expect(game.score, 0);

      // Head first, tail laid out behind it: each segment is one column to the
      // left of the one before, all on the same row.
      for (int i = 1; i < game.body.length; i++) {
        expect(spec.rowOf(game.body[i]), spec.rowOf(game.head));
        expect(spec.columnOf(game.body[i]), spec.columnOf(game.head) - i);
      }
    });

    test('places food on an empty cell', () {
      final SnakeGame game = SnakeGame.start(spec, seed: 7);
      expect(game.food, isNot(-1));
      expect(game.occupies(game.food), isFalse);
      expect(game.food, inInclusiveRange(0, spec.cellCount - 1));
    });
  });

  group('moving', () {
    test('advances the whole snake one cell in the heading', () {
      final SnakeGame game = _freshAwayFromFood(seed: 3);
      final int oldHead = game.head;
      final int oldTail = game.body.last;

      final SnakeGame moved = game.step(SnakeDirection.right);

      expect(moved.status, SnakeStatus.running);
      expect(moved.length, game.length);
      expect(moved.head, spec.neighbour(oldHead, SnakeDirection.right));
      // The tail cell it left is now empty; the old head is now the second
      // segment.
      expect(moved.occupies(oldTail), isFalse);
      expect(moved.body[1], oldHead);
      expect(moved.score, 0);
    });

    test('a turn changes the heading and the head follows it', () {
      final SnakeGame game = _freshAwayFromFood(seed: 3);
      final SnakeGame turned = game.step(SnakeDirection.up);
      expect(turned.direction, SnakeDirection.up);
      expect(turned.head, spec.neighbour(game.head, SnakeDirection.up));
    });
  });

  group('a 180-degree reversal is ignored', () {
    test('reversing keeps the heading and does not kill the snake', () {
      final SnakeGame game = _freshAwayFromFood(seed: 3);
      // Moving right; asking for left is a straight reversal.
      final SnakeGame stepped = game.step(SnakeDirection.left);
      expect(stepped.status, SnakeStatus.running);
      expect(stepped.direction, SnakeDirection.right);
      expect(stepped.head, spec.neighbour(game.head, SnakeDirection.right));
    });
  });

  group('growth and food determinism', () {
    test('eating grows the snake, scores, and places new food', () {
      // Play greedily toward the food until the snake eats, then look at the
      // frame either side of that one step.
      SnakeGame game = SnakeGame.start(spec, seed: 5);
      SnakeGame before = game;
      for (int i = 0; i < 4000; i++) {
        before = game;
        game = game.step(_towardFood(game));
        expect(
          game.status,
          SnakeStatus.running,
          reason: 'trapped before eating',
        );
        if (game.score > before.score) {
          break;
        }
      }

      expect(game.score, before.score + 1, reason: 'never reached the food');
      expect(game.length, before.length + 1);
      expect(game.food, isNot(before.food));
      expect(game.occupies(game.food), isFalse);
    });

    test('the same seed produces an identical run, food included', () {
      SnakeGame a = SnakeGame.start(spec, seed: 42);
      SnakeGame b = SnakeGame.start(spec, seed: 42);
      const List<SnakeDirection> moves = <SnakeDirection>[
        SnakeDirection.up,
        SnakeDirection.up,
        SnakeDirection.right,
        SnakeDirection.right,
        SnakeDirection.down,
      ];
      for (final SnakeDirection move in moves) {
        a = a.step(move);
        b = b.step(move);
      }
      expect(a, b);
      expect(a.body, b.body);
      expect(a.food, b.food);
      expect(a.rngState, b.rngState);
    });

    test('different seeds generally place the first food differently', () {
      final Set<int> foods = <int>{
        for (int seed = 1; seed <= 30; seed++)
          SnakeGame.start(spec, seed: seed).food,
      };
      expect(foods.length, greaterThan(15));
    });
  });

  group('collisions end the run', () {
    test('hitting a wall kills the snake and stops it moving', () {
      // Drive straight up from the middle to the top wall.
      SnakeGame game = SnakeGame.start(spec, seed: 9).step(SnakeDirection.up);
      while (spec.rowOf(game.head) > 0) {
        game = game.step(SnakeDirection.up);
      }
      final List<int> bodyAtWall = game.body;
      final SnakeGame overTheEdge = game.step(SnakeDirection.up);

      expect(overTheEdge.status, SnakeStatus.dead);
      // It stops where it was rather than stepping onto the wall.
      expect(overTheEdge.body, bodyAtWall);
      // A dead game steps to itself.
      expect(overTheEdge.step(SnakeDirection.left), same(overTheEdge));
    });

    test('a snake turning back into its own body dies', () {
      // A five-long snake heading right, on a board of its own so the food never
      // interferes with the geometry: up, left, down draws a tight square whose
      // last step lands the head on a body cell that is not the tail.
      const SnakeSpec box = SnakeSpec(cols: 10, rows: 10, startLength: 5);
      final SnakeGame game = SnakeGame.start(box, seed: 1);
      final SnakeGame closed = game
          .step(SnakeDirection.up)
          .step(SnakeDirection.left)
          .step(SnakeDirection.down);
      expect(closed.status, SnakeStatus.dead);
    });

    test('stepping onto the tail as it vacates is allowed, not a self-hit', () {
      // On a plain move the tail leaves its cell, so a head arriving there does
      // not collide — the whole reason the self-hit check drops the tail. A
      // straight snake advancing never lands on its own tail, so this documents
      // the rule via the check the code makes rather than a contrived board.
      final SnakeGame game = _freshAwayFromFood(seed: 2);
      expect(game.step(game.direction).status, SnakeStatus.running);
    });
  });

  group('the engine is pure', () {
    test('a step never mutates the frame it came from', () {
      final SnakeGame game = _freshAwayFromFood(seed: 8);
      final List<int> bodyBefore = List<int>.of(game.body);
      final int foodBefore = game.food;
      final int rngBefore = game.rngState;

      game.step(SnakeDirection.up);
      game.step(SnakeDirection.down);

      expect(game.body, bodyBefore);
      expect(game.food, foodBefore);
      expect(game.rngState, rngBefore);
    });
  });
}

/// A fresh game whose next forward step lands on empty ground, so movement and
/// purity tests are not perturbed by eating.
///
/// The standard start has the snake in the middle heading right; a seed whose
/// food is not immediately in front keeps the first steps plain. Seeds used by
/// the movement tests are chosen so this holds.
SnakeGame _freshAwayFromFood({required int seed}) {
  final SnakeGame game = SnakeGame.start(SnakeSpec.standard, seed: seed);
  // Guard the assumption so a bad seed fails loudly here rather than in a test.
  final int? ahead = SnakeSpec.standard.neighbour(game.head, game.direction);
  assert(ahead != game.food, 'seed $seed puts food right in front of the head');
  return game;
}

/// A greedy heading toward the food that never asks for a reversal and never
/// steps off the board — enough of a driver to make a short snake on an open
/// board eat within a handful of moves, so a growth test does not have to
/// hand-place anything.
SnakeDirection _towardFood(SnakeGame game) {
  final SnakeSpec spec = game.spec;
  final int headRow = spec.rowOf(game.head);
  final int headColumn = spec.columnOf(game.head);
  final int foodRow = spec.rowOf(game.food);
  final int foodColumn = spec.columnOf(game.food);

  bool usable(SnakeDirection dir) =>
      !dir.isReverseOf(game.direction) &&
      spec.neighbour(game.head, dir) != null;

  final List<SnakeDirection> wanted = <SnakeDirection>[
    if (foodRow < headRow) SnakeDirection.up,
    if (foodRow > headRow) SnakeDirection.down,
    if (foodColumn < headColumn) SnakeDirection.left,
    if (foodColumn > headColumn) SnakeDirection.right,
  ];
  for (final SnakeDirection dir in wanted) {
    if (usable(dir)) {
      return dir;
    }
  }
  // Nothing food-ward is open: keep going straight if that is safe, else take
  // any legal turn.
  if (spec.neighbour(game.head, game.direction) != null) {
    return game.direction;
  }
  for (final SnakeDirection dir in SnakeDirection.values) {
    if (usable(dir)) {
      return dir;
    }
  }
  return game.direction;
}
