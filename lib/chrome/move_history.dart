import 'package:flutter/foundation.dart';

/// One change to one cell of a board.
///
/// Deliberately plain: a handful of integers and nothing else. Every Nook game
/// is a grid whose cells hold a small number — a Sudoku digit, a Stars mark, a
/// Duo symbol — plus whatever the player has pencilled in, so this describes a
/// move in all of them, and it can be written straight to disk when a game has
/// to survive being closed (VIB-75) without a per-game encoder.
///
/// A cell's pencil marks travel as a `NoteMarks` bitmask, so taking a move
/// back restores what was written and what was noted together rather than
/// leaving one of them behind.
///
/// One move is one thing the player did, and a single action can tidy marks
/// out of cells it did not write to — a Sudoku digit rubs itself out of the
/// notes of its own row, column and box. Those go in [clearedNotes] rather
/// than becoming moves of their own, so undo stays the exact inverse of one
/// tap and the history stays a list of things a person actually did.
@immutable
class BoardMove {
  const BoardMove({
    required this.index,
    required this.before,
    required this.after,
    this.notesBefore = 0,
    this.notesAfter = 0,
    this.clearedNotes = const <int, int>{},
  });

  /// Reads a move back from stored data.
  ///
  /// Every field past the three that describe the cell is optional, so a
  /// history written before a game had pencil marks — or before a move could
  /// tidy them elsewhere — still reads back as the move it was rather than
  /// failing and taking the saved game with it.
  factory BoardMove.fromJson(Map<String, Object?> json) {
    final Map<Object?, Object?>? cleared =
        json['clearedNotes'] as Map<Object?, Object?>?;
    return BoardMove(
      index: json['index']! as int,
      before: json['before']! as int,
      after: json['after']! as int,
      notesBefore: json['notesBefore'] as int? ?? 0,
      notesAfter: json['notesAfter'] as int? ?? 0,
      clearedNotes: cleared == null
          ? const <int, int>{}
          : Map<int, int>.unmodifiable(<int, int>{
              for (final MapEntry<Object?, Object?> entry in cleared.entries)
                int.parse(entry.key! as String): entry.value! as int,
            }),
    );
  }

  /// Which cell changed.
  final int index;

  /// What the cell held before the move.
  final int before;

  /// What it holds after it.
  final int after;

  /// The cell's pencil marks before the move.
  final int notesBefore;

  /// Its pencil marks after it.
  final int notesAfter;

  /// The marks this move rubbed out of *other* cells, as cell index to the
  /// bits it removed from them.
  ///
  /// Empty for a move that only touched its own cell, which is most of them.
  /// Undo puts these bits back exactly where they came from; nothing else
  /// reads them, because no other control is allowed to reverse a move it did
  /// not make.
  final Map<int, int> clearedNotes;

  /// This move as plain data.
  ///
  /// [clearedNotes] is left out when it is empty, which keeps the common move
  /// the same handful of numbers it has always been on disk.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'index': index,
      'before': before,
      'after': after,
      'notesBefore': notesBefore,
      'notesAfter': notesAfter,
      if (clearedNotes.isNotEmpty)
        'clearedNotes': <String, int>{
          for (final MapEntry<int, int> entry in clearedNotes.entries)
            '${entry.key}': entry.value,
        },
    };
  }

  @override
  bool operator ==(Object other) {
    return other is BoardMove &&
        other.index == index &&
        other.before == before &&
        other.after == after &&
        other.notesBefore == notesBefore &&
        other.notesAfter == notesAfter &&
        _sameCleared(other.clearedNotes);
  }

  /// Whether [other] is the same set of tidied marks as [clearedNotes].
  ///
  /// Written out rather than reached for from a package: a map of two ints is
  /// not worth a dependency, and equality here has to be by value because a
  /// move is compared by what it did.
  bool _sameCleared(Map<int, int> other) {
    if (other.length != clearedNotes.length) {
      return false;
    }
    for (final MapEntry<int, int> entry in clearedNotes.entries) {
      if (other[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    index,
    before,
    after,
    notesBefore,
    notesAfter,
    // Sorted, so two moves that tidied the same marks hash alike whatever
    // order the cells happened to be visited in.
    Object.hashAll(<int>[
      for (final int cell in clearedNotes.keys.toList()..sort()) ...<int>[
        cell,
        clearedNotes[cell]!,
      ],
    ]),
  );

  @override
  String toString() =>
      'BoardMove(index: $index, before: $before, after: $after, '
      'notesBefore: $notesBefore, notesAfter: $notesAfter, '
      'clearedNotes: $clearedNotes)';
}

/// The moves a player can still take back, oldest first.
///
/// Immutable, and game-agnostic on purpose: Sudoku, Stars and Duo all record
/// their moves here rather than each growing an undo stack of its own. Nothing
/// in it is a closure or a widget, so the whole history is `toJson`-able.
///
/// There is no redo. Undo alone is how these games are played, and a redo
/// stack would double the state to keep correct for a move nobody asks for.
@immutable
class MoveHistory {
  /// A history holding [moves], trimmed to the newest [depth] of them.
  MoveHistory({required List<BoardMove> moves, this.depth = defaultDepth})
    : assert(depth > 0, 'A history has to be able to hold a move.'),
      moves = List<BoardMove>.unmodifiable(
        moves.length <= depth ? moves : moves.sublist(moves.length - depth),
      );

  /// A history with nothing in it yet.
  const MoveHistory.empty({this.depth = defaultDepth})
    : moves = const <BoardMove>[];

  /// Reads a history back from stored data.
  factory MoveHistory.fromJson(List<Object?> json, {int depth = defaultDepth}) {
    return MoveHistory(
      moves: <BoardMove>[
        for (final Object? move in json)
          BoardMove.fromJson((move! as Map<Object?, Object?>).cast()),
      ],
      depth: depth,
    );
  }

  /// How many moves are kept.
  ///
  /// Filling a 9x9 takes 81 moves, so this holds a whole grid and the
  /// corrections along the way. Beyond that the oldest move falls off the end:
  /// a long session must not grow a list without limit, and no player is
  /// undoing their way back an hour.
  static const int defaultDepth = 100;

  /// The moves themselves, oldest first.
  final List<BoardMove> moves;

  /// The most this history will hold.
  final int depth;

  /// Whether there is anything to take back.
  bool get canUndo => moves.isNotEmpty;

  /// The move that would be taken back next, or `null` if there is none.
  BoardMove? get last => moves.isEmpty ? null : moves.last;

  /// This history with [move] recorded on the end.
  MoveHistory push(BoardMove move) {
    return MoveHistory(moves: <BoardMove>[...moves, move], depth: depth);
  }

  /// This history without its most recent move.
  ///
  /// Empty histories pop to themselves rather than throwing: undoing past the
  /// first move is something a player does by accident, not a bug.
  MoveHistory pop() {
    if (moves.isEmpty) {
      return this;
    }
    return MoveHistory(moves: moves.sublist(0, moves.length - 1), depth: depth);
  }

  /// This history as plain data.
  List<Map<String, Object?>> toJson() {
    return <Map<String, Object?>>[
      for (final BoardMove move in moves) move.toJson(),
    ];
  }
}
