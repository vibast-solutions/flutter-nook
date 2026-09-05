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
    required this.hintInk,
    required this.cellConflict,
    required this.conflictLine,
    required this.cellComplete,
    required this.disabledSurface,
    required this.disabledLine,
    required this.disabledInk,
    required this.disabledInkFaint,
    required this.regionFills,
    required this.regionTextureInk,
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

  /// A digit a hint filled in.
  ///
  /// A third voice on the board, and it has to be legible as one: the puzzle's
  /// own digits are [ink] and the player's are [clay], so a hint is neither.
  /// Green rather than a paler orange, because a shade of the accent would
  /// read as a player's digit drawn badly.
  final Color hintInk;

  /// The background of a cell whose digit is repeated in its row, column or
  /// box.
  ///
  /// Never the only thing saying so: the cell is also marked in [conflictLine]
  /// — hatched in Sudoku and Duo, ringed in Stars — because a board that
  /// carried this meaning in a colour alone would be silent for the players
  /// most likely to need it.
  final Color cellConflict;

  /// The hatch drawn across a conflicting cell, and the stroke of the cross a
  /// hint draws over a wrong digit as it takes it away.
  final Color conflictLine;

  /// The wash a row, column or box is pulsed with when it is filled without a
  /// repeat.
  ///
  /// [sage] rather than the accent: it is the colour Nook already uses for
  /// something that has come out right, and the accent is the player's own
  /// handwriting.
  final Color cellComplete;

  /// The fill of each of a Stars board's eight regions, one per region index.
  ///
  /// Paired by index with [RegionTexture.values]: region `i` is drawn in
  /// `regionFills[i]` **and** textured with `RegionTexture.values[i]`. The
  /// pairing is the theme's, not a screen's, because it is what keeps the board
  /// solvable for a player who cannot tell the colours apart — the texture
  /// carries the same information the colour does, so neither is load-bearing
  /// alone. A theme that changed the fills would leave the textures where they
  /// are; the geometry is fixed and only the colour is a matter of taste.
  final List<Color> regionFills;

  /// The stroke a region's texture is drawn in, over its [regionFills] entry.
  ///
  /// One ink for all eight: the fills are pale enough that a single translucent
  /// dark reads on every one of them, and a texture that changed colour by
  /// region would be a second colour code rather than the shape-based one it is
  /// meant to be.
  final Color regionTextureInk;

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
    hintInk: Color(0xFF5E8055),
    cellConflict: Color(0xFFF6DED4),
    conflictLine: Color(0xFFC2543A),
    cellComplete: Color(0xFFC9DCC0),
    disabledSurface: Color(0xFFF3EBE1),
    disabledLine: Color(0xFFE8DCCA),
    disabledInk: Color(0xFFC9BAA7),
    disabledInkFaint: Color(0xFFCFC1AE),
    // Eight soft fills, warm enough to sit inside the Soft Clay board. They are
    // only half the story: each is paired with a texture, so the board reads
    // the same with every one of them turned to grey.
    regionFills: <Color>[
      Color(0xFFF2D9C4), // peach
      Color(0xFFDBE7D0), // sage
      Color(0xFFCFE0EE), // sky
      Color(0xFFE5DBEE), // lilac
      Color(0xFFF2D6DC), // rose
      Color(0xFFF1E8C2), // butter
      Color(0xFFCDE7DE), // mint
      Color(0xFFE7D8BE), // wheat
    ],
    regionTextureInk: Color(0x59695B4B),
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
    Color? hintInk,
    Color? cellConflict,
    Color? conflictLine,
    Color? cellComplete,
    Color? disabledSurface,
    Color? disabledLine,
    Color? disabledInk,
    Color? disabledInkFaint,
    List<Color>? regionFills,
    Color? regionTextureInk,
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
      hintInk: hintInk ?? this.hintInk,
      cellConflict: cellConflict ?? this.cellConflict,
      conflictLine: conflictLine ?? this.conflictLine,
      cellComplete: cellComplete ?? this.cellComplete,
      disabledSurface: disabledSurface ?? this.disabledSurface,
      disabledLine: disabledLine ?? this.disabledLine,
      disabledInk: disabledInk ?? this.disabledInk,
      disabledInkFaint: disabledInkFaint ?? this.disabledInkFaint,
      regionFills: regionFills ?? this.regionFills,
      regionTextureInk: regionTextureInk ?? this.regionTextureInk,
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
      hintInk: mix(hintInk, other.hintInk),
      cellConflict: mix(cellConflict, other.cellConflict),
      conflictLine: mix(conflictLine, other.conflictLine),
      cellComplete: mix(cellComplete, other.cellComplete),
      disabledSurface: mix(disabledSurface, other.disabledSurface),
      disabledLine: mix(disabledLine, other.disabledLine),
      disabledInk: mix(disabledInk, other.disabledInk),
      disabledInkFaint: mix(disabledInkFaint, other.disabledInkFaint),
      regionFills: <Color>[
        for (int i = 0; i < regionFills.length; i++)
          mix(regionFills[i], other.regionFills[i]),
      ],
      regionTextureInk: mix(regionTextureInk, other.regionTextureInk),
    );
  }
}

/// How many regions a Stars board is partitioned into, and so how many fills
/// and textures a theme pairs up.
///
/// Nook's Stars is eight regions; a variant with a different count would want
/// its own token set, so this is stated once here rather than assumed at every
/// `regionFills[i]`.
const int kRegionCount = 8;

/// The texture drawn over each region, so the eight regions read apart with the
/// colour taken away entirely.
///
/// Paired by index with [NookColors.regionFills]: region `i` is
/// `RegionTexture.values[i]`. A colour-only board is unplayable for a
/// meaningful share of players, so a Stars board never leans on colour alone —
/// every region carries one of these, and no two regions carry the same one.
enum RegionTexture {
  /// A field of small filled dots.
  dots,

  /// A field of small hollow rings.
  rings,

  /// Parallel lines running bottom-left to top-right.
  diagonalUp,

  /// Parallel lines running top-left to bottom-right.
  diagonalDown,

  /// Both diagonals at once.
  crossHatch,

  /// Horizontal lines.
  horizontal,

  /// Vertical lines.
  vertical,

  /// Horizontal and vertical lines at once.
  grid,
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

/// The narrowest screen Nook lays out for, in logical pixels.
///
/// Every control has to stay at [kMinTapTarget] at this width — a 9x9 board
/// with its nine-key pad under it is the tightest thing Nook draws, so this is
/// the number that decides whether the pad takes one row or two.
///
/// Board cells are the deliberate exception: nine of them across a phone
/// cannot each be 44 wide, and no Sudoku on any phone manages it. They take
/// as much of the width as the page can spare instead.
const double kSmallestSupportedWidth = 320;
