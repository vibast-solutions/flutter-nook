import 'package:flutter/material.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/duo/duo_state.dart';
import '../l10n/app_localizations.dart';
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
class DuoBoard extends StatelessWidget {
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

  /// The glyph a circle is drawn with.
  static const IconData circleIcon = Icons.circle;

  /// The glyph a square is drawn with — a different shape, never merely a
  /// different colour.
  static const IconData squareIcon = Icons.square_rounded;

  /// The key of the cell at [index], so a test can reach a known cell without
  /// depending on how it happens to look.
  static Key cellKey(int index) => ValueKey<String>('duo-cell-$index');

  /// The key of the symbol drawn in the cell at [index], if it holds one.
  static Key markKey(int index) => ValueKey<String>('duo-mark-$index');

  /// The key of the hatch across the cell at [index], drawn when the symbol it
  /// holds breaks a rule.
  static Key breachKey(int index) => ValueKey<String>('duo-breach-$index');

  /// The key of the badge on the edge between cells [a] and [b].
  ///
  /// The two cells are folded into one number so the key is a single
  /// interpolation with no literal in the middle — a separator between two
  /// `$a`/`$b` interpolations would read as player-facing copy to the string
  /// guard, and a widget key is neither a word nor translated.
  static Key badgeKey(int a, int b) =>
      ValueKey<String>('duo-badge-${a * 10000 + b}');

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
    final double cell = (edge - ruleWidth * 2) / size;
    final double inner = cell * size;
    final double badgeExtent = (cell * 0.42).clamp(15.0, 22.0);

    return Semantics(
      container: true,
      label: l10n.boardLabel(l10n.duoTitle, size),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.boardRule, width: ruleWidth),
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
          child: SizedBox(
            width: inner,
            height: inner,
            child: Stack(
              children: <Widget>[
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int row = 0; row < size; row++)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          for (int column = 0; column < size; column++)
                            _DuoCellTile(
                              game: game,
                              index: row * size + column,
                              extent: cell,
                              onTap: onTap,
                            ),
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
    );
  }

  /// Places a badge over the edge it sits on, centred on the line between its
  /// two cells.
  Widget _positionBadge(DuoBadge badge, double cell, double extent) {
    final int size = game.spec.size;
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
        key: badgeKey(badge.a, badge.b),
        relation: badge.relation,
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
  });

  final DuoGameState game;
  final int index;
  final double extent;
  final ValueChanged<int> onTap;

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
  /// A given is drawn in [NookColors.ink], the player's own in the accent, and a
  /// hinted one (VIB-97) in the hint ink — three voices, the way the other games
  /// tell a given from an answer from a hint.
  Widget? _symbol(NookColors colors, DuoCell cell, bool given) {
    if (cell == DuoCell.empty) {
      return null;
    }
    final Color color = given
        ? colors.ink
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

/// A constraint badge: a small chip carrying `=` or `x`, sat on the edge between
/// two cells.
///
/// A chip on a surface so it reads over either cell it straddles, and its glyph
/// is geometry rather than a font character, so it stays crisp at any board size
/// and legible in light and dark alike.
class _BadgeMark extends StatelessWidget {
  const _BadgeMark({required this.relation, super.key});

  /// Whether the two cells must match (`=`) or differ (`x`).
  final DuoRelation relation;

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
          border: Border.all(color: colors.boardRule, width: 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(6)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: CustomPaint(
            painter: _BadgeGlyph(relation: relation, ink: colors.ink),
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
      ..strokeWidth = 2
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.boardRule, width: 1.5),
        borderRadius: const BorderRadius.all(Radius.circular(5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3.5),
        child: SizedBox(
          width: 10,
          height: 10,
          child: CustomPaint(
            painter: _BadgeGlyph(relation: relation, ink: colors.ink),
          ),
        ),
      ),
    );
  }
}
