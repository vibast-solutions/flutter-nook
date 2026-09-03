import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/stars/stars_state.dart';
import '../l10n/app_localizations.dart';
import 'conflict_hatch.dart';

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
/// breach mark of VIB-88, the hint of VIB-90) costs nothing. Only the region
/// textures are painted, and those have nothing to hit and nothing to read out —
/// a cell's sentence is on the cell itself.
///
/// The **region boundary** is the primary colour-free cue: the heavy rule around
/// a region walls it off whatever its fill, so the shape a player solves against
/// reads with colour taken away entirely. The region's texture is a quiet second
/// voice under the fill — drawn at [boardTextureAlpha] so the soft colour leads
/// and the board stays calm rather than a quilt of eight competing patterns —
/// and the legend swatch, which shows the same texture at full strength, is where
/// it is read as a key.
///
/// Stateful for the one thing the board says by moving: a star being crossed out
/// as a hint takes it away. There is no completed-unit pulse here on purpose — a
/// row completes the moment its one star lands, and a wash over that star would
/// only get in its way — so the removal is the whole of the board's motion. It
/// is a transition rather than a state, so it is found by comparing the game
/// that arrives with the one before it; the state itself only ever describes the
/// board as it stands.
class StarsBoard extends StatefulWidget {
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

  /// How strongly a region's texture prints on the board, as an opacity.
  ///
  /// A whisper: the soft fill leads and the heavy region boundary does the
  /// colour-free work, so the texture is a quiet redundancy rather than the loud
  /// hatch it was — eight bold patterns at once buried the fills and hid the
  /// region shapes. The legend swatch still draws the texture at full strength,
  /// because that is where it has to read as a key.
  static const double boardTextureAlpha = 0.12;

  /// How long the cross a hint draws over a star it takes away stays up for.
  static const Duration removalDuration = Duration(milliseconds: 300);

  /// The key of the cell at [index], so a test can reach a known cell without
  /// depending on how it happens to look.
  static Key cellKey(int index) => ValueKey<String>('stars-cell-$index');

  /// The key of the star or dot drawn in the cell at [index], if it holds one.
  static Key markKey(int index) => ValueKey<String>('stars-mark-$index');

  /// The key of the hatch across the cell at [index], drawn when the star it
  /// holds breaks a rule.
  static Key breachKey(int index) => ValueKey<String>('stars-breach-$index');

  /// The key of the cross drawn over the cell at [index] as a hint takes a
  /// wrong star out of it.
  static Key removalKey(int index) => ValueKey<String>('stars-removal-$index');

  @override
  State<StarsBoard> createState() => _StarsBoardState();
}

class _StarsBoardState extends State<StarsBoard>
    with SingleTickerProviderStateMixin {
  /// Runs whether or not the board is allowed to move: it is what times the
  /// sentence a screen reader is given about the cell, and holding a label for a
  /// moment is not motion.
  late final AnimationController _removal = AnimationController(
    vsync: this,
    duration: StarsBoard.removalDuration,
  )..addStatusListener(_removalEnded);

  /// The star a hint is in the middle of taking off the board.
  StarRemoval? _removing;

  @override
  void didUpdateWidget(StarsBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startRemoval(oldWidget.game);
  }

  @override
  void dispose() {
    _removal.dispose();
    super.dispose();
  }

  /// Crosses out a star a hint has just taken away.
  void _startRemoval(StarsGameState before) {
    final StarRemoval? removal = widget.game.starRemoval;
    if (removal == null || removal == before.starRemoval) {
      return;
    }
    setState(() => _removing = removal);
    _removal.forward(from: 0);
  }

  void _removalEnded(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _removing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double? fixed = widget.edge;
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
    final StarsGameState game = widget.game;
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
          child: AnimatedBuilder(
            animation: _removal,
            builder: (BuildContext context, Widget? child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int row = 0; row < size; row++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int column = 0; column < size; column++)
                        _cellAt(row * size + column, cell),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cellAt(int index, double extent) {
    final StarRemoval? removing = _removing;
    return _StarsCell(
      game: widget.game,
      index: index,
      extent: extent,
      onTap: widget.onTap,
      removing: removing != null && removing.index == index ? removing : null,
      removalProgress: _removal.value,
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
    required this.removing,
    required this.removalProgress,
  });

  final StarsGameState game;
  final int index;
  final double extent;
  final ValueChanged<int> onTap;

  /// The star a hint is taking out of this cell, or `null` if it is not this
  /// cell's turn to be crossed out.
  final StarRemoval? removing;

  /// How far through the crossing-out the board is, 0 to 1.
  final double removalProgress;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final int size = game.spec.size;
    final int row = game.spec.rowOf(index);
    final int column = game.spec.columnOf(index);
    final int region = game.regionOf(index);
    final StarsMark mark = game.markAt(index);
    // Null unless this cell holds a star that breaks a rule. Only a star can
    // breach: a dot is an annotation and an empty cell has nothing to break.
    final StarBreach? breach = game.breachAt(index);

    // A boundary between two regions is the heavy rule; a join inside one
    // region is the hairline. The board's own frame covers the outer edges.
    final BorderSide right = column == size - 1
        ? BorderSide.none
        : _edgeBetween(colors, index, index + 1);
    final BorderSide bottom = row == size - 1
        ? BorderSide.none
        : _edgeBetween(colors, index, index + size);

    return Semantics(
      label: _describe(
        AppLocalizations.of(context),
        row,
        column,
        region,
        mark,
        breach,
      ),
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
              // The breach wash sits under the region's texture so the region
              // stays readable through it; the region's own colour never
              // carries meaning alone, so the texture still paints on top.
              if (breach != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: colors.cellConflict.withValues(alpha: 0.72),
                  ),
                ),
              // Colour never carries meaning alone on a Nook board, so every
              // region wears a texture a player can read without it — printed
              // quietly here (the heavy region boundary is the loud colour-free
              // cue) so the board reads calm, and shown at full strength in the
              // legend swatch, which is where the texture serves as a key.
              Positioned.fill(
                child: CustomPaint(
                  painter: _RegionTexture(
                    texture: regionTextureFor(region),
                    ink: colors.regionTextureInk.withValues(
                      alpha: StarsBoard.boardTextureAlpha,
                    ),
                  ),
                ),
              ),
              // A breach is a colour *and* a texture, the same hatch Sudoku
              // draws over a repeated digit, so it survives colour being taken
              // away and stays the app's one marking language.
              if (breach != null)
                Positioned.fill(
                  child: CustomPaint(
                    key: StarsBoard.breachKey(index),
                    painter: ConflictHatch(
                      colour: colors.conflictLine.withValues(alpha: 0.30),
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

  /// A star going away, the star or dot the cell holds, or nothing.
  Widget? _content(NookColors colors) {
    if (removing != null) {
      return _StarsRemoval(
        extent: extent,
        progress: removalProgress,
        cross: colors.conflictLine,
        // The star that is leaving was the player's own, so it fades in the
        // ink the player's stars are drawn in.
        ink: colors.ink,
        cellKey: StarsBoard.removalKey(index),
      );
    }
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
  ///
  /// A star in breach says *which* rule it breaks, not merely that something is
  /// wrong — the same fact a sighted player reads from the hatch, spelled out.
  String _describe(
    AppLocalizations l10n,
    int row,
    int column,
    int region,
    StarsMark mark,
    StarBreach? breach,
  ) {
    final int line = row + 1;
    final int column1 = column + 1;
    final int region1 = region + 1;
    // A star on its way off the board says so, so a player who cannot see it
    // fade is told why the cell they were on has emptied — the same fact either
    // way, whether or not the cross is drawn.
    if (removing != null) {
      return l10n.cellStarsCleared(line, column1, region1);
    }
    return switch (mark) {
      StarsMark.empty => l10n.cellStarsEmpty(line, column1, region1),
      StarsMark.ruledOut => l10n.cellStarsRuledOut(line, column1, region1),
      StarsMark.star => switch (breach) {
        null => l10n.cellStarsStar(line, column1, region1),
        StarBreach.row => l10n.cellStarsStarBreachRow(line, column1, region1),
        StarBreach.column => l10n.cellStarsStarBreachColumn(
          line,
          column1,
          region1,
        ),
        StarBreach.region => l10n.cellStarsStarBreachRegion(
          line,
          column1,
          region1,
        ),
        StarBreach.adjacent => l10n.cellStarsStarBreachAdjacent(
          line,
          column1,
          region1,
        ),
      },
    };
  }
}

/// A star being taken off the board by a hint, crossed out and fading.
///
/// The cross is what makes the disappearance mean something: a cell that simply
/// blanked would read as the app losing a star rather than as the player being
/// told, in the one way they asked for, that it was wrong. The same shape
/// Sudoku's `_Removal` draws, with a star where the digit would be.
class _StarsRemoval extends StatelessWidget {
  const _StarsRemoval({
    required this.extent,
    required this.progress,
    required this.cross,
    required this.ink,
    required this.cellKey,
  });

  final double extent;
  final double progress;
  final Color cross;
  final Color ink;
  final Key cellKey;

  @override
  Widget build(BuildContext context) {
    // Under a request for less motion there is nothing to watch: the star is
    // already gone from the grid, and this draws nothing over the gap. The cell
    // still says what happened to a screen reader.
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    final double fade = (1 - progress).clamp(0.0, 1.0);
    return Opacity(
      key: cellKey,
      opacity: fade,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Icon(Icons.star_rounded, size: extent * 0.62, color: ink),
          Icon(Icons.close_rounded, size: extent * 0.62, color: cross),
        ],
      ),
    );
  }
}

/// A repeating texture across a cell, so a region is legible without its
/// colour.
///
/// The patterns are geometry, not colour, which is the whole point: paired with
/// the fill and the heavy region boundary, they carry region identity that
/// survives the fills being flattened to one grey. The board prints this
/// quietly (see [StarsBoard.boardTextureAlpha]); the legend swatch prints it at
/// full strength, where it reads as a key.
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
