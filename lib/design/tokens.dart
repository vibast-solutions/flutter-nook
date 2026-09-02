import 'package:flutter/material.dart';

/// Nook's colour palette, reached through the theme rather than imported
/// directly by screens.
///
/// A theme is a token set: adding one (VIB-68) means adding another
/// [NookColors] instance, never editing a screen. That only holds if no widget
/// ever writes a literal colour, so none do — they all read from here via
/// `Theme.of(context).nook`.
@immutable
class NookColors extends ThemeExtension<NookColors> {
  const NookColors({
    required this.sand,
    required this.surface,
    required this.sunk,
    required this.line,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.inkGhost,
    required this.clay,
    required this.claySoft,
    required this.clayLine,
    required this.sage,
    required this.sageSoft,
    required this.sageLine,
    required this.sageInk,
    required this.boardRule,
    required this.boardHairline,
    required this.cellSelected,
    required this.cellPeer,
    required this.cellMatching,
    required this.noteInk,
    required this.disabledSurface,
    required this.disabledLine,
    required this.disabledInk,
    required this.disabledInkFaint,
  });

  /// The page background.
  final Color sand;

  /// Cards, cells and controls that sit on [sand].
  final Color surface;

  /// A recess in a surface, such as an unfilled progress track.
  final Color sunk;

  /// The hairline around cards and controls.
  final Color line;

  /// Primary text, and the digits the puzzle gave you.
  final Color ink;

  /// Secondary text.
  final Color inkMuted;

  /// Labels and captions.
  final Color inkFaint;

  /// The quietest text on the screen, and chevrons.
  final Color inkGhost;

  /// The accent: the player's own digits, primary actions.
  final Color clay;

  /// A wash of the accent, for icon tiles.
  final Color claySoft;

  /// A readable line-weight version of the accent.
  final Color clayLine;

  /// The secondary accent, used for anything daily or already-correct.
  final Color sage;

  /// A wash of [sage].
  final Color sageSoft;

  /// The hairline for [sageSoft] surfaces.
  final Color sageLine;

  /// Text on [sageSoft].
  final Color sageInk;

  /// The heavy rule around the board and between its boxes.
  final Color boardRule;

  /// The light rule between neighbouring cells inside a box.
  final Color boardHairline;

  /// The background of the selected cell.
  final Color cellSelected;

  /// The background of cells sharing a row, column or box with the selection.
  final Color cellPeer;

  /// The background of cells holding the same digit as the selection.
  final Color cellMatching;

  /// The pencil marks a player has written into a cell.
  ///
  /// Quieter than [clay] so a note never reads as an answer, and darker than
  /// [inkFaint] so nine of them at a third of the size stay legible.
  final Color noteInk;

  /// A control that has nothing left to do.
  final Color disabledSurface;

  /// The hairline of a spent control.
  final Color disabledLine;

  /// Text on a spent control.
  final Color disabledInk;

  /// Secondary text on a spent control.
  final Color disabledInkFaint;

  /// The Soft Clay palette — Nook's default and, until VIB-68, only theme.
  static const NookColors softClay = NookColors(
    sand: Color(0xFFF3EBE1),
    surface: Color(0xFFFCF8F2),
    sunk: Color(0xFFEADFCF),
    line: Color(0xFFE3D7C5),
    ink: Color(0xFF3A322B),
    inkMuted: Color(0xFF7B6E62),
    inkFaint: Color(0xFFAB9D8D),
    inkGhost: Color(0xFFB7A896),
    clay: Color(0xFFBF6A3E),
    claySoft: Color(0xFFF2DECC),
    clayLine: Color(0xFFE3BE9E),
    sage: Color(0xFF6E8A66),
    sageSoft: Color(0xFFDFE7D9),
    sageLine: Color(0xFFC7D4BE),
    sageInk: Color(0xFF3A5236),
    boardRule: Color(0xFFB9A78E),
    boardHairline: Color(0xFFE9DFD0),
    cellSelected: Color(0xFFF0D9C2),
    cellPeer: Color(0xFFF6EFE4),
    cellMatching: Color(0xFFDFE7D9),
    noteInk: Color(0xFFA08D77),
    disabledSurface: Color(0xFFF3EBE1),
    disabledLine: Color(0xFFE8DCCA),
    disabledInk: Color(0xFFC9BAA7),
    disabledInkFaint: Color(0xFFCFC1AE),
  );

  @override
  NookColors copyWith({
    Color? sand,
    Color? surface,
    Color? sunk,
    Color? line,
    Color? ink,
    Color? inkMuted,
    Color? inkFaint,
    Color? inkGhost,
    Color? clay,
    Color? claySoft,
    Color? clayLine,
    Color? sage,
    Color? sageSoft,
    Color? sageLine,
    Color? sageInk,
    Color? boardRule,
    Color? boardHairline,
    Color? cellSelected,
    Color? cellPeer,
    Color? cellMatching,
    Color? noteInk,
    Color? disabledSurface,
    Color? disabledLine,
    Color? disabledInk,
    Color? disabledInkFaint,
  }) {
    return NookColors(
      sand: sand ?? this.sand,
      surface: surface ?? this.surface,
      sunk: sunk ?? this.sunk,
      line: line ?? this.line,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      inkFaint: inkFaint ?? this.inkFaint,
      inkGhost: inkGhost ?? this.inkGhost,
      clay: clay ?? this.clay,
      claySoft: claySoft ?? this.claySoft,
      clayLine: clayLine ?? this.clayLine,
      sage: sage ?? this.sage,
      sageSoft: sageSoft ?? this.sageSoft,
      sageLine: sageLine ?? this.sageLine,
      sageInk: sageInk ?? this.sageInk,
      boardRule: boardRule ?? this.boardRule,
      boardHairline: boardHairline ?? this.boardHairline,
      cellSelected: cellSelected ?? this.cellSelected,
      cellPeer: cellPeer ?? this.cellPeer,
      cellMatching: cellMatching ?? this.cellMatching,
      noteInk: noteInk ?? this.noteInk,
      disabledSurface: disabledSurface ?? this.disabledSurface,
      disabledLine: disabledLine ?? this.disabledLine,
      disabledInk: disabledInk ?? this.disabledInk,
      disabledInkFaint: disabledInkFaint ?? this.disabledInkFaint,
    );
  }

  @override
  NookColors lerp(covariant NookColors? other, double t) {
    if (other == null) {
      return this;
    }
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return NookColors(
      sand: mix(sand, other.sand),
      surface: mix(surface, other.surface),
      sunk: mix(sunk, other.sunk),
      line: mix(line, other.line),
      ink: mix(ink, other.ink),
      inkMuted: mix(inkMuted, other.inkMuted),
      inkFaint: mix(inkFaint, other.inkFaint),
      inkGhost: mix(inkGhost, other.inkGhost),
      clay: mix(clay, other.clay),
      claySoft: mix(claySoft, other.claySoft),
      clayLine: mix(clayLine, other.clayLine),
      sage: mix(sage, other.sage),
      sageSoft: mix(sageSoft, other.sageSoft),
      sageLine: mix(sageLine, other.sageLine),
      sageInk: mix(sageInk, other.sageInk),
      boardRule: mix(boardRule, other.boardRule),
      boardHairline: mix(boardHairline, other.boardHairline),
      cellSelected: mix(cellSelected, other.cellSelected),
      cellPeer: mix(cellPeer, other.cellPeer),
      cellMatching: mix(cellMatching, other.cellMatching),
      noteInk: mix(noteInk, other.noteInk),
      disabledSurface: mix(disabledSurface, other.disabledSurface),
      disabledLine: mix(disabledLine, other.disabledLine),
      disabledInk: mix(disabledInk, other.disabledInk),
      disabledInkFaint: mix(disabledInkFaint, other.disabledInkFaint),
    );
  }
}

/// Reaches Nook's tokens from a [BuildContext].
extension NookTheme on ThemeData {
  /// The palette of the active theme.
  NookColors get nook => extension<NookColors>() ?? NookColors.softClay;
}

/// Corner radii, named for what they wrap rather than by size.
abstract final class NookRadius {
  /// Cards and the board.
  static const Radius card = Radius.circular(20);

  /// List rows.
  static const Radius row = Radius.circular(18);

  /// Buttons and number-pad keys.
  static const Radius key = Radius.circular(17);

  /// Small icon tiles.
  static const Radius tile = Radius.circular(13);

  /// The board's outer frame.
  static const Radius board = Radius.circular(12);
}

/// The smallest a tappable thing may be, in logical pixels.
///
/// Both stores recommend it and Nook treats it as a floor, not a target.
const double kMinTapTarget = 44;
