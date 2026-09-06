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
/// right". Telling the head from the body, and the retro segment look, are
/// VIB-111; here the whole snake is one solid colour on a plain grid.
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
    // empty cells need no identity.
    final Key? key = isHead
        ? headKey
        : isFood
        ? foodKey
        : null;

    final Color fill = isSnake
        ? colors.clay
        : isFood
        ? colors.sage
        : colors.surface;

    final BorderSide hairline = BorderSide(
      color: colors.boardHairline,
      width: hairlineWidth,
    );

    return Container(
      key: key,
      width: extent,
      height: extent,
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          right: spec.columnOf(index) == spec.cols - 1
              ? BorderSide.none
              : hairline,
          bottom: spec.rowOf(index) == spec.rows - 1
              ? BorderSide.none
              : hairline,
        ),
      ),
    );
  }
}
