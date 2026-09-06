import 'package:flutter/material.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../design/tokens.dart';
import '../l10n/app_localizations.dart';
import 'board_frame.dart';

/// The Snake board: the snake, the food, and the grid they move on.
///
/// Built from widgets rather than a painted canvas, the same house rule every
/// other board follows — one tile per cell, coloured from the theme and never
/// from a literal.
///
/// **A deliberate exception to "one `Semantics` node per cell".** A Sudoku or
/// Duo cell is a thing a player reaches for, so each is its own node; an arcade
/// field of a few hundred cells changing every tick is not — it is one live
/// region, described as a whole. So this board carries a single container label
/// and no per-cell semantics. The spoken running commentary a screen-reader
/// player needs (score, length, game over) and an on-screen control that does
/// not depend on a swipe are added wholesale in VIB-112; this story lays out the
/// field.
///
/// The snake is drawn in [NookColors.clay] and the food in [NookColors.sage] —
/// two colours Nook already uses for "the player's own" and "something come out
/// right".
///
/// **Meaning is carried by shape, never colour alone (VIB-111).** The board is a
/// retro segment style — each cell an inset rounded square with the grid showing
/// between the segments — and the three things on it are told apart without
/// reading any hue: the body is a plain rounded segment, the *head* the same
/// segment with a pair of eyes looking the way it travels, and the *food* a
/// round pip rather than a square. A player who cannot tell clay from sage still
/// reads head from body from food. It stays inside the app's one theme: it is a
/// way of drawing the tokens, not a new palette, so no literal colour appears
/// and no theme-switching machinery is added.
class SnakeBoard extends StatelessWidget {
  const SnakeBoard({required this.game, this.width, super.key});

  /// The frame of the game being drawn.
  final SnakeGame game;

  /// The width of the board in logical pixels; its height follows from the
  /// board's aspect ratio. Defaults to as much of the available width as it can
  /// take.
  final double? width;

  /// The thickness of the board's frame.
  static const double ruleWidth = 2;

  /// The thickness of the line between two cells.
  static const double hairlineWidth = 0.5;

  /// The key of the snake's head cell, so a test can watch it move without
  /// depending on how the board happens to look.
  static const Key headKey = ValueKey<String>('snake-head');

  /// The key of the food cell.
  static const Key foodKey = ValueKey<String>('snake-food');

  @override
  Widget build(BuildContext context) {
    final double? fixed = width;
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
    final SnakeSpec spec = game.spec;
    final double cell = (edge - ruleWidth * 2) / spec.cols;
    final double innerWidth = cell * spec.cols;
    final double innerHeight = cell * spec.rows;

    return Semantics(
      container: true,
      label: l10n.snakeBoardLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.boardRule, width: ruleWidth),
          borderRadius: const BorderRadius.all(NookRadius.board),
          boxShadow: boardFrameShadows(colors),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(NookRadius.board),
          child: SizedBox(
            width: innerWidth,
            height: innerHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int row = 0; row < spec.rows; row++)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int column = 0; column < spec.cols; column++)
                        _cellAt(colors, spec.indexOf(row, column), cell),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cellAt(NookColors colors, int index, double extent) {
    final SnakeSpec spec = game.spec;
    final bool isHead = index == game.head;
    final bool isSnake = game.occupies(index);
    final bool isFood = index == game.food;

    // The head and the food are keyed so a test can find them; ordinary body and
    // empty cells need no identity. The key stays on the cell itself, not the
    // shape inside it, so it marks the same spot however the segment is drawn.
    final Key? key = isHead
        ? headKey
        : isFood
        ? foodKey
        : null;

    final BorderSide hairline = BorderSide(
      color: colors.boardHairline,
      width: hairlineWidth,
    );

    // The retro shape that sits inside the cell, or nothing for an empty one.
    final Widget? piece = isHead
        ? _SnakeHead(colors: colors, extent: extent, facing: game.direction)
        : isSnake
        ? _SnakeSegment(colors: colors, extent: extent)
        : isFood
        ? _SnakeFood(colors: colors, extent: extent)
        : null;

    // The empty grid stays the board's surface; the segments and food are drawn
    // over it, inset so the surface reads between them as the grid.
    return Container(
      key: key,
      width: extent,
      height: extent,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: spec.columnOf(index) == spec.cols - 1
              ? BorderSide.none
              : hairline,
          bottom: spec.rowOf(index) == spec.rows - 1
              ? BorderSide.none
              : hairline,
        ),
      ),
      child: piece,
    );
  }
}

/// A body segment: an inset rounded square in the snake's colour, the surface
/// showing around it as the grid.
class _SnakeSegment extends StatelessWidget {
  const _SnakeSegment({required this.colors, required this.extent});

  final NookColors colors;
  final double extent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(extent * 0.09),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.clay,
          borderRadius: BorderRadius.all(Radius.circular(extent * 0.28)),
        ),
      ),
    );
  }
}

/// The head: a body segment with a pair of eyes looking the way it travels, so
/// it is told from the body by shape rather than by any change of colour.
class _SnakeHead extends StatelessWidget {
  const _SnakeHead({
    required this.colors,
    required this.extent,
    required this.facing,
  });

  final NookColors colors;
  final double extent;
  final SnakeDirection facing;

  @override
  Widget build(BuildContext context) {
    final double eye = extent * 0.16;
    // Two eye centres, as fractions of the cell, pushed toward the leading edge
    // and set apart across it — so they point where the snake is going.
    final List<Offset> centres = _eyeCentres(facing);

    return Padding(
      padding: EdgeInsets.all(extent * 0.09),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.clay,
          borderRadius: BorderRadius.all(Radius.circular(extent * 0.28)),
        ),
        child: Stack(
          children: <Widget>[
            for (final Offset c in centres)
              Positioned(
                left: c.dx * extent - eye / 2 - extent * 0.09,
                top: c.dy * extent - eye / 2 - extent * 0.09,
                child: Container(
                  width: eye,
                  height: eye,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The two eye centres as fractions of the cell, for the way the head faces.
  static List<Offset> _eyeCentres(SnakeDirection facing) {
    switch (facing) {
      case SnakeDirection.up:
        return const <Offset>[Offset(0.34, 0.28), Offset(0.66, 0.28)];
      case SnakeDirection.down:
        return const <Offset>[Offset(0.34, 0.72), Offset(0.66, 0.72)];
      case SnakeDirection.left:
        return const <Offset>[Offset(0.28, 0.34), Offset(0.28, 0.66)];
      case SnakeDirection.right:
        return const <Offset>[Offset(0.72, 0.34), Offset(0.72, 0.66)];
    }
  }
}

/// The food: a round pip, a shape apart from the square segments so it is read
/// as food without reading its colour.
class _SnakeFood extends StatelessWidget {
  const _SnakeFood({required this.colors, required this.extent});

  final NookColors colors;
  final double extent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(extent * 0.18),
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.sage, shape: BoxShape.circle),
      ),
    );
  }
}
