import 'package:flutter/foundation.dart';

/// The pencil marks in one cell.
///
/// A set of digits, held as a bitmask: bit 0 is a 1, bit 8 is a 9. That keeps
/// a cell's notes a single integer, which is what lets a move carry them in
/// the history and a saved game write them straight to disk (VIB-75) without
/// a per-game encoder.
@immutable
class NoteMarks {
  /// The marks described by [mask].
  const NoteMarks(this.mask);

  /// A cell with nothing pencilled in.
  const NoteMarks.empty() : mask = 0;

  /// The marks for [digits]. Anything outside 1..[maxDigit] is ignored.
  factory NoteMarks.of(Iterable<int> digits) {
    int mask = 0;
    for (final int digit in digits) {
      if (digit >= 1 && digit <= maxDigit) {
        mask |= 1 << (digit - 1);
      }
    }
    return NoteMarks(mask);
  }

  /// The largest digit that can be pencilled in — a 9x9 Sudoku's 9, which is
  /// also the biggest board Nook plans to draw.
  static const int maxDigit = 9;

  /// The marks as a bitmask.
  final int mask;

  /// Whether nothing is pencilled in here.
  bool get isEmpty => mask == 0;

  /// Whether anything is pencilled in here.
  bool get isNotEmpty => mask != 0;

  /// Whether [digit] is pencilled in.
  bool contains(int digit) {
    if (digit < 1 || digit > maxDigit) {
      return false;
    }
    return mask & (1 << (digit - 1)) != 0;
  }

  /// These marks with [digit] added if it was missing and removed if it was
  /// there — one tap of the same key does both, which is how a player rubs a
  /// mark out.
  NoteMarks toggled(int digit) {
    if (digit < 1 || digit > maxDigit) {
      return this;
    }
    return NoteMarks(mask ^ (1 << (digit - 1)));
  }

  /// The digits pencilled in, smallest first.
  List<int> get digits {
    return <int>[
      for (int digit = 1; digit <= maxDigit; digit++)
        if (contains(digit)) digit,
    ];
  }

  @override
  bool operator ==(Object other) => other is NoteMarks && other.mask == mask;

  @override
  int get hashCode => mask.hashCode;

  @override
  String toString() => 'NoteMarks(${digits.join(', ')})';
}
