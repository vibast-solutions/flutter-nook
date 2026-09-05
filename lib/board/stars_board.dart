import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/stars/stars_state.dart';
import '../l10n/app_localizations.dart';
import 'board_frame.dart';

/// The texture paired with region [region].
///
/// The board no longer paints these — the heavy region boundary carries region
/// identity on its own — but the one-texture-per-region pairing is kept and
/// tested so the mapping is ready if a future theme wants to draw it again.
RegionTexture regionTextureFor(int region) =>
    RegionTexture.values[region % RegionTexture.values.length];

/// The Stars grid.
///
/// Built from widgets rather than a painted canvas, for the reasons the
/// technical design gives: one [Semantics] node per cell lets a screen reader
/// describe the board, hit testing is free, and animating a single cell (the
/// breach mark of VIB-88, the hint of VIB-90) costs nothing.
///
/// The **region boundary** carries region identity on its own: the heavy rule
/// around a region walls it off from its neighbours whatever their fills, so the
/// shape a player solves against reads with colour taken away entirely. The
/// board was once textured under the fill as a second colour-free cue, but eight
/// hatches at once buried the fills and read as noise; the boundary already does
/// the colour-free work, so the fills are now a calm decorative layer over it.
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

  /// The thickness of the board's outer frame — heavier than the region rule
  /// so the board reads as one bounded object with a firm edge.
  static const double frameWidth = 3;

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
    final double cell = (edge - StarsBoard.frameWidth * 2) / size;

    return Semantics(
      container: true,
      label: l10n.boardLabel(l10n.starsTitle, size),
      child: BoardFrameGlow(
        solved: game.isSolved,
        child: ClipRect(
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
        // Square corners, not the rounded board of the other games: the region
        // fills run right to the edge, so a rounded clip would shave their
        // corners. A firmer, slightly darker frame gives the board a clear edge.
        builder:
            (BuildContext context, List<BoxShadow> shadows, Widget child) =>
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(
                      color: colors.inkFaint,
                      width: StarsBoard.frameWidth,
                    ),
                    boxShadow: shadows,
                  ),
                  child: child,
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

/// One cell: its region's fill underneath, and a star, a cross, or nothing on
/// top.
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
              // A breach turns the cell pale red and rings it in the conflict
              // line. The ring is a shape a player reads without the hue, and a
              // screen reader still names the rule that broke, so the marking is
              // never carried by colour alone. The fill covers the region rather
              // than washing over it, and nothing is drawn past the cell, so a
              // breach never bleeds into the cell next door.
              if (breach != null)
                Positioned.fill(
                  child: DecoratedBox(
                    key: StarsBoard.breachKey(index),
                    decoration: BoxDecoration(
                      color: colors.cellConflict,
                      border: Border.all(
                        color: colors.conflictLine,
                        width: 1.5,
                      ),
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
      // A join inside a region is a soft translucent ink rather than the
      // near-white hairline: it stays readable over all eight fills so a player
      // can follow a row or a column across the board by eye, while never
      // reading as heavy as the region wall.
      color: boundary
          ? colors.boardRule
          : colors.inkFaint.withValues(alpha: 0.30),
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
        // A small cross: an annotation saying "no star here", quiet on purpose
        // and no bigger than the dot it replaces so it never competes with a
        // star. A cross rather than a dot reads as a deliberate ruling-out at a
        // glance, and its size keeps it from crowding the cell.
        return Icon(
          Icons.close_rounded,
          key: StarsBoard.markKey(index),
          size: extent * 0.24,
          color: colors.inkMuted,
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

/// The key to the eight regions, shown under the board.
///
/// A small palette: eight swatches, one per region colour, and a line naming
/// them. Colour is not what makes the board solvable — the heavy rule walling
/// each region off is, so a player who cannot tell the fills apart still reads
/// the regions by their boundaries — but naming the colours is a friendly key
/// for everyone else.
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
                _Swatch(fill: colors.regionFills[region], line: colors.line),
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

/// One region's fill, in a small rounded square.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.fill, required this.line});

  final Color fill;
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
    );
  }
}
