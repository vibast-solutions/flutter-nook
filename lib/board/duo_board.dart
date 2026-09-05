import 'package:flutter/material.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/duo/duo_state.dart';
import '../l10n/app_localizations.dart';
import 'board_frame.dart';
import 'conflict_hatch.dart';

/// The Duo grid.
///
/// Built from widgets rather than a painted canvas, for the reasons the
/// technical design gives: one [Semantics] node per cell lets a screen reader
/// describe the board, hit testing is free, and animating a single cell (the
/// breach mark of VIB-95, the hint of VIB-97) will cost nothing.
///
/// The two symbols are drawn as a **circle** and a **square** — the shape is the
/// distinction, so the board reads with colour taken away entirely, which is why
/// Business Logic rules a sun and a moon out. Given cells are drawn fixed and
/// visually distinct from the player's own entries.
///
/// The genuinely new rendering job, which neither Sudoku nor Stars has, is the
/// **constraint badges**: a small `=` or `x` centred on the edge between the two
/// cells it constrains, on both horizontal and vertical edges.
///
/// Stateful for the one thing the board says by moving: a symbol being crossed
/// out as a hint takes it away. A completed-line pulse is explicitly not wanted
/// here — a line completes the moment its last symbol lands — so the removal is
/// the whole of the board's motion. It is a transition rather than a state, so
/// it is found by comparing the game that arrives with the one before it; the
/// state itself only ever describes the board as it stands.
class DuoBoard extends StatefulWidget {
  const DuoBoard({
    required this.game,
    required this.onTap,
    this.edge,
    super.key,
  });

  /// The game being drawn.
  final DuoGameState game;

  /// Called with the index of a tapped cell.
  final ValueChanged<int> onTap;

  /// The width and height of the board in logical pixels. Defaults to as much of
  /// the available width as it can take.
  final double? edge;

  /// The thickness of the board's frame.
  static const double ruleWidth = 2;

  /// The thickness of the line between two cells.
  static const double hairlineWidth = 1;

  /// The glyph a circle is drawn with: filled, so it reads as the solid one of
  /// the pair.
  static const IconData circleIcon = Icons.circle;

  /// The glyph a square is drawn with — outline rather than filled, so the two
  /// symbols are told apart by fill as well as by shape and the board never
  /// reads as a field of same-weight blobs. A different shape, never merely a
  /// different colour.
  static const IconData squareIcon = Icons.square_outlined;

  /// How long the cross a hint draws over a symbol it takes away stays up for.
  static const Duration removalDuration = Duration(milliseconds: 300);

  /// The key of the cell at [index], so a test can reach a known cell without
  /// depending on how it happens to look.
  static Key cellKey(int index) => ValueKey<String>('duo-cell-$index');

  /// The key of the symbol drawn in the cell at [index], if it holds one.
  static Key markKey(int index) => ValueKey<String>('duo-mark-$index');

  /// The key of the hatch across the cell at [index], drawn when the symbol it
  /// holds breaks a rule.
  static Key breachKey(int index) => ValueKey<String>('duo-breach-$index');

  /// The key of the cross drawn over the cell at [index] as a hint takes a
  /// wrong symbol out of it.
  static Key removalKey(int index) => ValueKey<String>('duo-removal-$index');

  /// The key of the badge on the edge between cells [a] and [b].
  ///
  /// The two cells are folded into one number so the key is a single
  /// interpolation with no literal in the middle — a separator between two
  /// `$a`/`$b` interpolations would read as player-facing copy to the string
  /// guard, and a widget key is neither a word nor translated.
  static Key badgeKey(int a, int b) =>
      ValueKey<String>('duo-badge-${a * 10000 + b}');

  @override
  State<DuoBoard> createState() => _DuoBoardState();
}

class _DuoBoardState extends State<DuoBoard>
    with SingleTickerProviderStateMixin {
  /// Runs whether or not the board is allowed to move: it is what times the
  /// sentence a screen reader is given about the cell, and holding a label for
  /// a moment is not motion.
  late final AnimationController _removal = AnimationController(
    vsync: this,
    duration: DuoBoard.removalDuration,
  )..addStatusListener(_removalEnded);

  /// The symbol a hint is in the middle of taking off the board.
  DuoRemoval? _removing;

  @override
  void didUpdateWidget(DuoBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startRemoval(oldWidget.game);
  }

  @override
  void dispose() {
    _removal.dispose();
    super.dispose();
  }

  /// Crosses out a symbol a hint has just taken away.
  void _startRemoval(DuoGameState before) {
    final DuoRemoval? removal = widget.game.removal;
    if (removal == null || removal == before.removal) {
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
    final DuoGameState game = widget.game;
    final int size = game.spec.size;
    final double cell = (edge - DuoBoard.ruleWidth * 2) / size;
    final double inner = cell * size;
    // A small annotation on the line, not a chip competing with the cells: kept
    // deliberately tiny so the `=`/`x` reads as a note on the boundary and a
    // player follows the grid past it rather than around it.
    final double badgeExtent = (cell * 0.22).clamp(10.0, 13.0);

    return Semantics(
      container: true,
      label: l10n.boardLabel(l10n.duoTitle, size),
      child: BoardFrameGlow(
        solved: game.isSolved,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(NookRadius.board),
          child: SizedBox(
            width: inner,
            height: inner,
            child: AnimatedBuilder(
              animation: _removal,
              builder: (BuildContext context, Widget? child) => Stack(
                children: <Widget>[
                  Column(
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
                  for (final DuoBadge badge in game.puzzle.badges)
                    _positionBadge(badge, cell, badgeExtent),
                ],
              ),
            ),
          ),
        ),
        builder:
            (BuildContext context, List<BoxShadow> shadows, Widget child) =>
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(
                      color: colors.boardRule,
                      width: DuoBoard.ruleWidth,
                    ),
                    borderRadius: const BorderRadius.all(NookRadius.board),
                    boxShadow: shadows,
                  ),
                  child: child,
                ),
      ),
    );
  }

  Widget _cellAt(int index, double extent) {
    final DuoRemoval? removing = _removing;
    return _DuoCellTile(
      game: widget.game,
      index: index,
      extent: extent,
      onTap: widget.onTap,
      removing: removing != null && removing.index == index ? removing : null,
      removalProgress: _removal.value,
    );
  }

  /// Places a badge over the edge it sits on, centred on the line between its
  /// two cells.
  Widget _positionBadge(DuoBadge badge, double cell, double extent) {
    final int size = widget.game.spec.size;
    final int row = badge.a ~/ size;
    final int column = badge.a % size;
    final double centreX = badge.isHorizontal
        ? (column + 1) * cell
        : column * cell + cell / 2;
    final double centreY = badge.isHorizontal
        ? row * cell + cell / 2
        : (row + 1) * cell;
    return Positioned(
      left: centreX - extent / 2,
      top: centreY - extent / 2,
      width: extent,
      height: extent,
      child: _BadgeMark(
        key: DuoBoard.badgeKey(badge.a, badge.b),
        relation: badge.relation,
        extent: extent,
      ),
    );
  }
}

/// One cell: a fixed given or one of the player's own, with a circle, a square,
/// or nothing on it.
class _DuoCellTile extends StatelessWidget {
  const _DuoCellTile({
    required this.game,
    required this.index,
    required this.extent,
    required this.onTap,
    required this.removing,
    required this.removalProgress,
  });

  final DuoGameState game;
  final int index;
  final double extent;
  final ValueChanged<int> onTap;

  /// The symbol a hint is taking out of this cell, or `null` if it is not this
  /// cell's turn to be crossed out.
  final DuoRemoval? removing;

  /// How far through the crossing-out the board is, 0 to 1.
  final double removalProgress;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final int size = game.spec.size;
    final int row = game.spec.rowOf(index);
    final int column = game.spec.columnOf(index);
    final DuoCell cell = game.cellAt(index);
    final bool given = game.isGiven(index);
    final bool selected = game.selectedIndex == index && !given;
    // Null unless this cell holds a symbol that breaks a rule. An empty cell has
    // nothing to break.
    final DuoBreach? breach = game.breachAt(index);

    final BorderSide hairline = BorderSide(
      color: colors.boardHairline,
      width: DuoBoard.hairlineWidth,
    );
    // A given sits in a recess so it reads as part of the puzzle rather than the
    // player's own; a breach washes the cell; the selected cell lifts; the rest
    // is plain surface. Selection wins over the breach wash — a player who has
    // lost the cursor has a worse problem than a breach they can still see
    // hatched — but the hatch still draws, so the marking never vanishes.
    final Color background = selected
        ? colors.cellSelected
        : breach != null
        ? colors.cellConflict
        : given
        ? colors.sunk
        : colors.surface;

    return Semantics(
      label: _describe(
        AppLocalizations.of(context),
        row + 1,
        column + 1,
        cell,
        given,
        breach,
      ),
      button: !given,
      excludeSemantics: true,
      child: GestureDetector(
        key: DuoBoard.cellKey(index),
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Container(
          width: extent,
          height: extent,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            border: Border(
              right: column == size - 1 ? BorderSide.none : hairline,
              bottom: row == size - 1 ? BorderSide.none : hairline,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Colour never carries a meaning by itself on a Nook board, so the
              // wash comes with a hatch a player can read without it — the same
              // hatch Sudoku and Stars draw, so the marking is one language
              // across the app. It sits under the symbol, which stays legible on
              // top.
              if (breach != null)
                Positioned.fill(
                  child: CustomPaint(
                    key: DuoBoard.breachKey(index),
                    painter: ConflictHatch(
                      colour: colors.conflictLine.withValues(alpha: 0.30),
                    ),
                  ),
                ),
              ?_symbol(colors, cell, given),
            ],
          ),
        ),
      ),
    );
  }

  /// The circle or square the cell holds, or nothing.
  ///
  /// A given is drawn in [NookColors.inkMuted], the player's own in the accent,
  /// and a hinted one in the hint ink — three voices, the way the other games
  /// tell a given from an answer from a hint. A given is the quieter [inkMuted]
  /// rather than [ink] so a filled circle never reads as a heavy black blob; the
  /// recessed cell it sits in already says it is the puzzle's own.
  Widget? _symbol(NookColors colors, DuoCell cell, bool given) {
    final DuoRemoval? leaving = removing;
    if (leaving != null) {
      return _DuoRemoval(
        extent: extent,
        cell: leaving.cell,
        progress: removalProgress,
        cross: colors.conflictLine,
        // The symbol that is leaving was the player's own, so it fades in the
        // accent the player's symbols are drawn in.
        ink: colors.clay,
        cellKey: DuoBoard.removalKey(index),
      );
    }
    if (cell == DuoCell.empty) {
      return null;
    }
    final Color color = given
        ? colors.inkMuted
        : game.isHinted(index)
        ? colors.hintInk
        : colors.clay;
    return Icon(
      cell == DuoCell.circle ? DuoBoard.circleIcon : DuoBoard.squareIcon,
      key: DuoBoard.markKey(index),
      size: extent * 0.5,
      color: color,
    );
  }

  /// What a screen reader reads out for this cell. Rows and columns are counted
  /// from one, the way a person describes a grid.
  ///
  /// A cell in breach says *which* rule it breaks, not merely that something is
  /// wrong — the same fact a sighted player reads from the hatch, spelled out.
  /// The breach naming is by symbol, not by given-ness: the group is what is
  /// broken, and whether this particular member came with the puzzle is not.
  String _describe(
    AppLocalizations l10n,
    int row,
    int column,
    DuoCell cell,
    bool given,
    DuoBreach? breach,
  ) {
    // A symbol on its way off the board says so, so a player who cannot see it
    // fade is told why the cell they were on has emptied — the same fact either
    // way, whether or not the cross is drawn.
    final DuoRemoval? leaving = removing;
    if (leaving != null) {
      return leaving.cell == DuoCell.circle
          ? l10n.cellDuoClearedCircle(row, column)
          : l10n.cellDuoClearedSquare(row, column);
    }
    if (breach != null && cell != DuoCell.empty) {
      final bool circle = cell == DuoCell.circle;
      return switch (breach) {
        DuoBreach.triple =>
          circle
              ? l10n.cellDuoCircleBreachTriple(row, column)
              : l10n.cellDuoSquareBreachTriple(row, column),
        DuoBreach.balance =>
          circle
              ? l10n.cellDuoCircleBreachBalance(row, column)
              : l10n.cellDuoSquareBreachBalance(row, column),
        DuoBreach.badge =>
          circle
              ? l10n.cellDuoCircleBreachBadge(row, column)
              : l10n.cellDuoSquareBreachBadge(row, column),
      };
    }
    return switch (cell) {
      DuoCell.empty => l10n.cellDuoEmpty(row, column),
      DuoCell.circle =>
        given
            ? l10n.cellDuoGivenCircle(row, column)
            : l10n.cellDuoCircle(row, column),
      DuoCell.square =>
        given
            ? l10n.cellDuoGivenSquare(row, column)
            : l10n.cellDuoSquare(row, column),
    };
  }
}

/// A symbol being taken off the board by a hint, crossed out and fading.
///
/// The cross is what makes the disappearance mean something: a cell that simply
/// blanked would read as the app losing a symbol rather than as the player
/// being told, in the one way they asked for, that it was wrong. The same shape
/// Sudoku's `_Removal` and Stars' `_StarsRemoval` draw, with a circle or a
/// square where the digit would be.
class _DuoRemoval extends StatelessWidget {
  const _DuoRemoval({
    required this.extent,
    required this.cell,
    required this.progress,
    required this.cross,
    required this.ink,
    required this.cellKey,
  });

  final double extent;
  final DuoCell cell;
  final double progress;
  final Color cross;
  final Color ink;
  final Key cellKey;

  @override
  Widget build(BuildContext context) {
    // Under a request for less motion there is nothing to watch: the symbol is
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
          Icon(
            cell == DuoCell.circle ? DuoBoard.circleIcon : DuoBoard.squareIcon,
            size: extent * 0.5,
            color: ink,
          ),
          Icon(Icons.close_rounded, size: extent * 0.62, color: cross),
        ],
      ),
    );
  }
}

/// A constraint badge: a small `=` or `x` sat on the edge between two cells.
///
/// An annotation on the grid line rather than a tile: a borderless knockout in
/// the board's own surface lifts the glyph clear of the hairline and any cell
/// wash beneath, and the sign is drawn in a quiet [NookColors.inkMuted] so it
/// reads as a note on the boundary rather than competing with the circles and
/// squares in the cells. A bordered chip here made a 6x6 read as a dense field
/// twice as wide, the cells and the constraints shouting at one volume. The
/// glyph is geometry rather than a font character, so it stays crisp at any
/// board size and legible in light and dark alike.
class _BadgeMark extends StatelessWidget {
  const _BadgeMark({required this.relation, required this.extent, super.key});

  /// Whether the two cells must match (`=`) or differ (`x`).
  final DuoRelation relation;

  /// The badge's diameter, so the knockout ring around the glyph stays
  /// proportional as the badge shrinks rather than swallowing it.
  final double extent;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      label: relation == DuoRelation.equal
          ? l10n.duoBadgeEqual
          : l10n.duoBadgeUnequal,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(extent * 0.18),
          child: CustomPaint(
            painter: _BadgeGlyph(relation: relation, ink: colors.inkMuted),
          ),
        ),
      ),
    );
  }
}

/// Draws the `=` or `x` inside a badge chip.
///
/// `=` is two horizontal bars, `x` is a cross — two shapes told apart by their
/// geometry, never by colour.
class _BadgeGlyph extends CustomPainter {
  const _BadgeGlyph({required this.relation, required this.ink});

  final DuoRelation relation;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = ink
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    switch (relation) {
      case DuoRelation.equal:
        final double gap = size.height * 0.26;
        final double midY = size.height / 2;
        canvas.drawLine(
          Offset(0, midY - gap),
          Offset(size.width, midY - gap),
          stroke,
        );
        canvas.drawLine(
          Offset(0, midY + gap),
          Offset(size.width, midY + gap),
          stroke,
        );
      case DuoRelation.unequal:
        canvas.drawLine(Offset.zero, Offset(size.width, size.height), stroke);
        canvas.drawLine(Offset(size.width, 0), Offset(0, size.height), stroke);
    }
  }

  @override
  bool shouldRepaint(_BadgeGlyph oldDelegate) =>
      oldDelegate.relation != relation || oldDelegate.ink != ink;
}

/// The key to the board, shown under it.
///
/// It exists because the rules should never need memorising (Features & Usage:
/// "A legend on the screen explains both symbols"): the two symbols, and what an
/// `=` and an `x` badge each mean.
class DuoLegend extends StatelessWidget {
  const DuoLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Semantics(
      label: l10n.duoLegendLabel,
      excludeSemantics: true,
      child: Wrap(
        spacing: 14,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: <Widget>[
          _LegendItem(
            label: l10n.duoLegendCircle,
            child: Icon(DuoBoard.circleIcon, size: 15, color: colors.ink),
          ),
          _LegendItem(
            label: l10n.duoLegendSquare,
            child: Icon(DuoBoard.squareIcon, size: 15, color: colors.ink),
          ),
          _LegendItem(
            label: l10n.duoLegendEqual,
            child: const _LegendBadge(relation: DuoRelation.equal),
          ),
          _LegendItem(
            label: l10n.duoLegendUnequal,
            child: const _LegendBadge(relation: DuoRelation.unequal),
          ),
        ],
      ),
    );
  }
}

/// One entry of the legend: a swatch and the word for it.
class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.child, required this.label});

  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(width: 18, height: 18, child: Center(child: child)),
        const SizedBox(width: 5),
        Text(label, style: NookType.footnote(colors.inkMuted)),
      ],
    );
  }
}

/// A small badge chip for the legend, the same glyph the board draws.
class _LegendBadge extends StatelessWidget {
  const _LegendBadge({required this.relation});

  final DuoRelation relation;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    // A faint ring stands in for the board's borderless knockout, which would
    // vanish on the legend's own surface; the glyph is the same quiet ink the
    // board draws, so key and board read as one.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.boardRule, width: 1),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(3.5),
        child: SizedBox(
          width: 10,
          height: 10,
          child: CustomPaint(
            painter: _BadgeGlyph(relation: relation, ink: colors.inkMuted),
          ),
        ),
      ),
    );
  }
}
