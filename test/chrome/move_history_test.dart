import 'package:flutter_test/flutter_test.dart';
import 'package:nook/chrome/move_history.dart';

void main() {
  group('a move', () {
    test('survives a trip through plain data', () {
      const BoardMove move = BoardMove(
        index: 7,
        before: 0,
        after: 4,
        notesBefore: 6,
      );

      expect(move.toJson(), <String, Object?>{
        'index': 7,
        'before': 0,
        'after': 4,
        'notesBefore': 6,
        'notesAfter': 0,
      });
      expect(BoardMove.fromJson(move.toJson()), move);
    });

    test('reads back a move stored before notes existed', () {
      final BoardMove move = BoardMove.fromJson(<String, Object?>{
        'index': 7,
        'before': 0,
        'after': 4,
      });

      expect(move, const BoardMove(index: 7, before: 0, after: 4));
      expect(move.notesBefore, 0);
      expect(move.notesAfter, 0);
    });

    test('a move that only changes the notes is still a move', () {
      const BoardMove pencilled = BoardMove(
        index: 3,
        before: 0,
        after: 0,
        notesAfter: 1,
      );

      expect(pencilled, isNot(const BoardMove(index: 3, before: 0, after: 0)));
      expect(BoardMove.fromJson(pencilled.toJson()), pencilled);
    });

    test('two moves of the same shape are the same move', () {
      expect(
        const BoardMove(index: 1, before: 2, after: 3),
        const BoardMove(index: 1, before: 2, after: 3),
      );
      expect(
        const BoardMove(index: 1, before: 2, after: 3),
        isNot(const BoardMove(index: 1, before: 2, after: 9)),
      );
    });
  });

  group('a history', () {
    const BoardMove first = BoardMove(index: 0, before: 0, after: 1);
    const BoardMove second = BoardMove(index: 5, before: 0, after: 2);

    test('starts with nothing to undo', () {
      const MoveHistory history = MoveHistory.empty();

      expect(history.canUndo, isFalse);
      expect(history.last, isNull);
      expect(history.moves, isEmpty);
    });

    test('remembers moves in the order they were made', () {
      final MoveHistory history = const MoveHistory.empty()
          .push(first)
          .push(second);

      expect(history.canUndo, isTrue);
      expect(history.moves, <BoardMove>[first, second]);
      expect(history.last, second);
    });

    test('popping takes the most recent move off', () {
      final MoveHistory history = const MoveHistory.empty()
          .push(first)
          .push(second)
          .pop();

      expect(history.moves, <BoardMove>[first]);
      expect(history.last, first);
    });

    test('popping an empty history gives an empty history', () {
      const MoveHistory empty = MoveHistory.empty();

      expect(empty.pop().canUndo, isFalse);
      expect(empty.pop().moves, isEmpty);
    });

    test('the oldest moves fall off the end at the cap', () {
      MoveHistory history = const MoveHistory.empty(depth: 3);
      for (int i = 0; i < 5; i++) {
        history = history.push(BoardMove(index: i, before: 0, after: 1));
      }

      expect(history.moves, hasLength(3));
      expect(history.moves.map((BoardMove move) => move.index), <int>[
        2,
        3,
        4,
      ], reason: 'the three most recent, not the three first');
    });

    test('a history read back longer than the cap is trimmed to it', () {
      final MoveHistory history = MoveHistory(
        moves: <BoardMove>[
          for (int i = 0; i < 10; i++) BoardMove(index: i, before: 0, after: 1),
        ],
        depth: 4,
      );

      expect(history.moves, hasLength(4));
      expect(history.last!.index, 9);
    });

    test('survives a trip through plain data', () {
      final MoveHistory history = const MoveHistory.empty()
          .push(first)
          .push(second);

      final List<Object?> stored = history.toJson();
      expect(MoveHistory.fromJson(stored).moves, <BoardMove>[first, second]);
    });

    test('holds a full 9x9 grid and then some', () {
      expect(MoveHistory.defaultDepth, greaterThan(81));
    });

    test('cannot be built with no room in it', () {
      expect(
        () => MoveHistory(moves: const <BoardMove>[], depth: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
