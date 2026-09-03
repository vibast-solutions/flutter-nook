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

    test('a move carries the marks it tidied elsewhere, there and back', () {
      // One action can rub a digit out of the notes of twenty other cells; all
      // of it travels on the one move, so undo is the inverse of one tap and
      // the history stays a list of things a person did.
      const BoardMove tidied = BoardMove(
        index: 4,
        before: 0,
        after: 3,
        clearedNotes: <int, int>{0: 4, 8: 4, 12: 4},
      );

      final MoveHistory read = MoveHistory.fromJson(
        const MoveHistory.empty().push(tidied).toJson(),
      );

      expect(read.last, tidied);
      expect(read.last!.clearedNotes, <int, int>{0: 4, 8: 4, 12: 4});
    });

    test('and two moves that tidied differently are not the same move', () {
      const BoardMove one = BoardMove(
        index: 4,
        before: 0,
        after: 3,
        clearedNotes: <int, int>{0: 4},
      );
      const BoardMove other = BoardMove(
        index: 4,
        before: 0,
        after: 3,
        clearedNotes: <int, int>{8: 4},
      );

      expect(one, isNot(other));
      expect(one, BoardMove.fromJson(one.toJson()));
      expect(one.hashCode, BoardMove.fromJson(one.toJson()).hashCode);
    });

    test('a move stored before any move could tidy reads back as one that '
        'tidied nothing', () {
      // The shape a save written by an older build has. It has to come back as
      // the move it was rather than failing and taking the saved game with it.
      final BoardMove old = BoardMove.fromJson(<String, Object?>{
        'index': 4,
        'before': 0,
        'after': 3,
        'notesBefore': 0,
        'notesAfter': 0,
      });

      expect(old.clearedNotes, isEmpty);
      expect(old, const BoardMove(index: 4, before: 0, after: 3));
    });

    test('and a move that tidied nothing is not written out any longer', () {
      // Most moves touch one cell. Their rows on disk stay the handful of
      // numbers they have always been.
      expect(
        const BoardMove(index: 4, before: 0, after: 3).toJson(),
        isNot(contains('clearedNotes')),
      );
    });

    test('a clear-marks move carries every dot it wiped, there and back', () {
      // Stars "clear marks" empties every dotted cell at once and must come
      // back in one undo: the first dot rides in the move's own cell, the rest
      // in clearedMarks, and all of it survives the trip to disk.
      const BoardMove cleared = BoardMove(
        index: 2,
        before: 1,
        after: 0,
        clearedMarks: <int, int>{10: 1, 25: 1, 47: 1},
      );

      final MoveHistory read = MoveHistory.fromJson(
        const MoveHistory.empty().push(cleared).toJson(),
      );

      expect(read.last, cleared);
      expect(read.last!.clearedMarks, <int, int>{10: 1, 25: 1, 47: 1});
      expect(read.last!.hashCode, cleared.hashCode);
    });

    test(
      'two clear-marks moves that wiped different cells are not the same',
      () {
        const BoardMove one = BoardMove(
          index: 2,
          before: 1,
          after: 0,
          clearedMarks: <int, int>{10: 1},
        );
        const BoardMove other = BoardMove(
          index: 2,
          before: 1,
          after: 0,
          clearedMarks: <int, int>{25: 1},
        );

        expect(one, isNot(other));
        // The two swept-cell maps are kept apart from the tidied-notes ones: a
        // move that cleared a mark is not a move that tidied a note.
        expect(
          one,
          isNot(
            const BoardMove(
              index: 2,
              before: 1,
              after: 0,
              clearedNotes: <int, int>{10: 1},
            ),
          ),
        );
      },
    );

    test('a move stored without the swept-cells field reads back with none', () {
      // The compatibility guarantee: a save written before "clear marks"
      // existed has no clearedMarks key, and must come back as the move it was
      // rather than failing and taking the saved game down with it.
      final BoardMove old = BoardMove.fromJson(<String, Object?>{
        'index': 2,
        'before': 1,
        'after': 0,
        'notesBefore': 0,
        'notesAfter': 0,
      });

      expect(old.clearedMarks, isEmpty);
      expect(old, const BoardMove(index: 2, before: 1, after: 0));
    });

    test('and a move that swept nothing leaves the field off disk', () {
      expect(
        const BoardMove(index: 2, before: 1, after: 0).toJson(),
        isNot(contains('clearedMarks')),
      );
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
