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
@immutable
class BoardMove {
  const BoardMove({
    required this.index,
    required this.before,
    required this.after,
    this.notesBefore = 0,
    this.notesAfter = 0,
  });

  /// Reads a move back from stored data.
  ///
  /// The note masks are optional, so a history written before a game had
  /// pencil marks still reads back as a history of plain entries.
  factory BoardMove.fromJson(Map<String, Object?> json) {
    return BoardMove(
      index: json['index']! as int,
      before: json['before']! as int,
      after: json['after']! as int,
      notesBefore: json['notesBefore'] as int? ?? 0,
      notesAfter: json['notesAfter'] as int? ?? 0,
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

  /// This move as plain data.
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'index': index,
      'before': before,
      'after': after,
      'notesBefore': notesBefore,
      'notesAfter': notesAfter,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is BoardMove &&
        other.index == index &&
        other.before == before &&
        other.after == after &&
        other.notesBefore == notesBefore &&
        other.notesAfter == notesAfter;
  }

  @override
  int get hashCode =>
      Object.hash(index, before, after, notesBefore, notesAfter);

  @override
  String toString() =>
      'BoardMove(index: $index, before: $before, after: $after, '
      'notesBefore: $notesBefore, notesAfter: $notesAfter)';
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
