import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/stars/stars_state.dart';
import '../l10n/app_localizations.dart';

/// The texture region [region] is drawn with.
///
/// The pairing lives in the theme — colour and texture together are region
/// `region` — and this is the single place the board reads it, so a colour and
/// its pattern can never drift apart.
RegionTexture regionTextureFor(int region) =>
    RegionTexture.values[region % RegionTexture.values.length];

/// The Stars grid.
///
/// Built from widgets rather than a painted canvas, for the reasons the
/// technical design gives: one [Semantics] node per cell lets a screen reader
/// describe the board, hit testing is free, and animating a single cell (the
/// breach mark of VIB-88, the hint of VIB-90) will cost nothing. Only the
/// region textures are painted, and those have nothing to hit and nothing to
/// read out — a cell's sentence is on the cell itself.
///
/// Every cell carries its region's colour **and** its region's texture, so the
/// eight regions stay distinguishable with the colour taken away entirely.
class StarsBoard extends StatelessWidget {
  const StarsBoard({
    required this.game,
    required this.onTap,
    this.edge,
    super.key,
  });

  /// The game being drawn.
  final StarsGameState game;

  /// Called with the index of a tapped cell.
  final ValueChanged<int> onTap;

  /// The width and height of the board in logical pixels. Defaults to as much
  /// of the available width as it can take.
  final double? edge;

  /// The thickness of the board's frame and the rule between two regions.
  static const double ruleWidth = 2;

  /// The thickness of the line between two cells in the same region.
  static const double hairlineWidth = 1;

  /// The key of the cell at [index], so a test can reach a known cell without
  /// depending on how it happens to look.
  static Key cellKey(int index) => ValueKey<String>('stars-cell-$index');

  /// The key of the star or dot drawn in the cell at [index], if it holds one.
  static Key markKey(int index) => ValueKey<String>('stars-mark-$index');

  @override
  Widget build(BuildContext context) {
    final double? fixed = edge;
    if (fixed != null) {
      return _build(context, fixed);
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double available = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        return _build(context, available);
      },
    );
  }

  Widget _build(BuildContext context, double edge) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int size = game.spec.size;
    final double cell = (edge - StarsBoard.ruleWidth * 2) / size;

    return Semantics(
      container: true,
      label: l10n.boardLabel(l10n.starsTitle, size),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(
            color: colors.boardRule,
            width: StarsBoard.ruleWidth,
          ),
          borderRadius: const BorderRadius.all(NookRadius.board),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.ink.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(NookRadius.board),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int row = 0; row < size; row++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int column = 0; column < size; column++)
                      _StarsCell(
                        game: game,
                        index: row * size + column,
                        extent: cell,
                        onTap: onTap,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One cell: its region's fill and texture underneath, and a star, a dot, or
/// nothing on top.
class _StarsCell extends StatelessWidget {
  const _StarsCell({
    required this.game,
    required this.index,
    required this.extent,
    required this.onTap,
  });

  final StarsGameState game;
  final int index;
  final double extent;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final int size = game.spec.size;
    final int row = game.spec.rowOf(index);
    final int column = game.spec.columnOf(index);
    final int region = game.regionOf(index);
    final StarsMark mark = game.markAt(index);

    // A boundary between two regions is the heavy rule; a join inside one
    // region is the hairline. The board's own frame covers the outer edges.
    final BorderSide right = column == size - 1
        ? BorderSide.none
        : _edgeBetween(colors, index, index + 1);
    final BorderSide bottom = row == size - 1
        ? BorderSide.none
        : _edgeBetween(colors, index, index + size);

    return Semantics(
      label: _describe(AppLocalizations.of(context), row, column, region, mark),
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        key: StarsBoard.cellKey(index),
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Container(
          width: extent,
          height: extent,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.regionFills[region % colors.regionFills.length],
            border: Border(right: right, bottom: bottom),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Colour never carries meaning alone on a Nook board, so every
              // region wears a texture a player can read without it.
              Positioned.fill(
                child: CustomPaint(
                  painter: _RegionTexture(
                    texture: regionTextureFor(region),
                    ink: colors.regionTextureInk,
                  ),
                ),
              ),
              ?_content(colors),
            ],
          ),
        ),
      ),
    );
  }

  /// The rule between the cell at [a] and the cell at [b]: heavy if they are in
  /// different regions, a hairline if they share one.
  BorderSide _edgeBetween(NookColors colors, int a, int b) {
    final bool boundary = game.regionOf(a) != game.regionOf(b);
    return BorderSide(
      color: boundary ? colors.boardRule : colors.boardHairline,
      width: boundary ? StarsBoard.ruleWidth : StarsBoard.hairlineWidth,
    );
  }

  /// The star or the ruled-out dot, or nothing for an empty cell.
  Widget? _content(NookColors colors) {
    switch (game.markAt(index)) {
      case StarsMark.empty:
        return null;
      case StarsMark.ruledOut:
        // A small dot: an annotation, quiet on purpose so it never competes
        // with a star.
        return SizedBox(
          key: StarsBoard.markKey(index),
          width: extent * 0.2,
          height: extent * 0.2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.inkMuted,
              shape: BoxShape.circle,
            ),
          ),
        );
      case StarsMark.star:
        return Icon(
          Icons.star_rounded,
          key: StarsBoard.markKey(index),
          size: extent * 0.62,
          // A hinted star reads as a third voice, the way a hinted digit does
          // in Sudoku; nothing sets a hint until VIB-90, so this is [ink]
          // today.
          color: game.isHinted(index) ? colors.hintInk : colors.ink,
        );
    }
  }

  /// What a screen reader reads out for this cell. Rows, columns and regions
  /// are counted from one, the way a person describes a grid.
  String _describe(
    AppLocalizations l10n,
    int row,
    int column,
    int region,
    StarsMark mark,
  ) {
    final int line = row + 1;
    final int column1 = column + 1;
    final int region1 = region + 1;
    return switch (mark) {
      StarsMark.empty => l10n.cellStarsEmpty(line, column1, region1),
      StarsMark.ruledOut => l10n.cellStarsRuledOut(line, column1, region1),
      StarsMark.star => l10n.cellStarsStar(line, column1, region1),
    };
  }
}

/// A repeating texture across a cell, so a region is legible without its
/// colour.
///
/// The patterns are geometry, not colour, which is the whole point: they carry
/// the region identity that the fill also carries, so the board stays solvable
/// with the fills flattened to one grey.
class _RegionTexture extends CustomPainter {
  const _RegionTexture({required this.texture, required this.ink});

  final RegionTexture texture;
  final Color ink;

  /// The gap between one mark and the next, in logical pixels.
  ///
  /// Fixed rather than a fraction of the cell so the pattern stays a pattern on
  /// a small cell rather than turning into two fat marks.
  static const double _step = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = ink
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final Paint fill = Paint()
      ..color = ink
      ..style = PaintingStyle.fill;

    switch (texture) {
      case RegionTexture.dots:
        _dots(canvas, size, fill, filled: true);
      case RegionTexture.rings:
        _dots(canvas, size, stroke, filled: false);
      case RegionTexture.diagonalUp:
        _diagonal(canvas, size, stroke, up: true);
      case RegionTexture.diagonalDown:
        _diagonal(canvas, size, stroke, up: false);
      case RegionTexture.crossHatch:
        _diagonal(canvas, size, stroke, up: true);
        _diagonal(canvas, size, stroke, up: false);
      case RegionTexture.horizontal:
        _horizontal(canvas, size, stroke);
      case RegionTexture.vertical:
        _vertical(canvas, size, stroke);
      case RegionTexture.grid:
        _horizontal(canvas, size, stroke);
        _vertical(canvas, size, stroke);
    }
  }

  void _dots(Canvas canvas, Size size, Paint paint, {required bool filled}) {
    const double radius = 1.4;
    for (double y = _step / 2; y < size.height; y += _step) {
      for (double x = _step / 2; x < size.width; x += _step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  void _diagonal(Canvas canvas, Size size, Paint paint, {required bool up}) {
    for (double d = -size.height; d < size.width; d += _step) {
      if (up) {
        canvas.drawLine(
          Offset(d, size.height),
          Offset(d + size.height, 0),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(d, 0),
          Offset(d + size.height, size.height),
          paint,
        );
      }
    }
  }

  void _horizontal(Canvas canvas, Size size, Paint paint) {
    for (double y = _step / 2; y < size.height; y += _step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _vertical(Canvas canvas, Size size, Paint paint) {
    for (double x = _step / 2; x < size.width; x += _step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_RegionTexture oldDelegate) =>
      oldDelegate.texture != texture || oldDelegate.ink != ink;
}

/// The key to the eight regions, shown under the board.
///
/// It exists because colour alone is not the code: a player who cannot tell the
/// fills apart reads the board by its textures, and the legend is where those
/// textures are named as a set. Eight small swatches, each the fill and pattern
/// of one region, and a line saying what they are.
class StarsLegend extends StatelessWidget {
  const StarsLegend({required this.regionCount, super.key});

  /// How many regions the board has.
  final int regionCount;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final int count = math.min(regionCount, colors.regionFills.length);

    return Semantics(
      label: l10n.starsLegendLabel,
      excludeSemantics: true,
      child: Column(
        children: <Widget>[
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: <Widget>[
              for (int region = 0; region < count; region++)
                _Swatch(
                  fill: colors.regionFills[region],
                  texture: regionTextureFor(region),
                  ink: colors.regionTextureInk,
                  line: colors.line,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.starsLegend,
            textAlign: TextAlign.center,
            style: NookType.footnote(colors.inkGhost),
          ),
        ],
      ),
    );
  }
}

/// One region's fill and pattern, in a small rounded square.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.fill,
    required this.texture,
    required this.ink,
    required this.line,
  });

  final Color fill;
  final RegionTexture texture;
  final Color ink;
  final Color line;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: line),
        borderRadius: const BorderRadius.all(NookRadius.tile),
      ),
      child: CustomPaint(
        painter: _RegionTexture(texture: texture, ink: ink),
      ),
    );
  }
}
