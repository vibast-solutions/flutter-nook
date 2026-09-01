import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/sudoku/sudoku_state.dart';

/// The Sudoku grid.
///
/// Built from widgets rather than a painted canvas: one [Semantics] node per
/// cell means a screen reader can describe the board, hit testing is free, and
/// animating a single cell later costs nothing. A [CustomPainter] would have
/// to reimplement all three, and accessibility is a stated goal for Nook
/// rather than a nice-to-have.
class SudokuBoard extends StatelessWidget {
  const SudokuBoard({
    required this.game,
    required this.onSelect,
    this.edge,
    super.key,
  });

  /// The game being drawn.
  final SudokuGameState game;

  /// Called with the index of a tapped cell.
  final ValueChanged<int> onSelect;

  /// The width and height of the board in logical pixels. Defaults to as much
  /// of the available width as it can take.
  final double? edge;

  /// The thickness of the board's frame and its box divisions.
  static const double ruleWidth = 2;

  /// The thickness of the line between two cells in the same box.
  static const double hairlineWidth = 1;

  /// The key of the cell at [index], so tests can reach a known cell without
  /// depending on how it happens to look at the time.
  static Key cellKey(int index) => ValueKey<String>('sudoku-cell-$index');

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
    final int size = game.size;
    // The frame sits outside the cells, so the cells share what is left.
    final double cell = (edge - ruleWidth * 2) / size;

    return Semantics(
      container: true,
      label: '${game.variant.title} board, $size by $size',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (int row = 0; row < size; row++)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (int column = 0; column < size; column++)
                      _SudokuCell(
                        game: game,
                        index: row * size + column,
                        extent: cell,
                        onTap: onSelect,
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

/// One cell: its background says how it relates to the selection, its digit
/// says who put it there.
class _SudokuCell extends StatelessWidget {
  const _SudokuCell({
    required this.game,
    required this.index,
    required this.extent,
    required this.onTap,
  });

  final SudokuGameState game;
  final int index;
  final double extent;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final int size = game.size;
    final int row = game.spec.rowOf(index);
    final int column = game.spec.columnOf(index);
    final int value = game.cells[index];
    final bool given = game.isGiven(index);
    final int? selected = game.selectedIndex;
    final bool isSelected = selected == index;

    Color background = colors.surface;
    if (selected != null) {
      final int selectedDigit = game.selectedDigit;
      if (isSelected) {
        background = colors.cellSelected;
      } else if (selectedDigit != 0 && value == selectedDigit) {
        background = colors.cellMatching;
      } else if (game.sharesUnit(index, selected)) {
        background = colors.cellPeer;
      }
    }

    // Boxes are divided by the heavy rule, cells inside a box by the hairline.
    // The board's own frame covers the outer edges, so they get nothing.
    final bool boxEdgeRight = (column + 1) % game.spec.boxWidth == 0;
    final bool boxEdgeBottom = (row + 1) % game.spec.boxHeight == 0;
    final BorderSide right = column == size - 1
        ? BorderSide.none
        : BorderSide(
            color: boxEdgeRight ? colors.boardRule : colors.boardHairline,
            width: boxEdgeRight
                ? SudokuBoard.ruleWidth
                : SudokuBoard.hairlineWidth,
          );
    final BorderSide bottom = row == size - 1
        ? BorderSide.none
        : BorderSide(
            color: boxEdgeBottom ? colors.boardRule : colors.boardHairline,
            width: boxEdgeBottom
                ? SudokuBoard.ruleWidth
                : SudokuBoard.hairlineWidth,
          );

    return Semantics(
      label: _describe(row: row, column: column, value: value, given: given),
      selected: isSelected,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        key: SudokuBoard.cellKey(index),
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Container(
          width: extent,
          height: extent,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            border: Border(right: right, bottom: bottom),
          ),
          child: value == 0
              ? null
              : Text(
                  '$value',
                  style: NookType.cellDigit(
                    given ? colors.ink : colors.clay,
                    extent * 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  /// What a screen reader reads out for this cell. Rows and columns are
  /// counted from one, because that is how a person describes a grid.
  String _describe({
    required int row,
    required int column,
    required int value,
    required bool given,
  }) {
    final String position = 'Row ${row + 1}, column ${column + 1}';
    if (value == 0) {
      return '$position, empty';
    }
    return '$position, $value, ${given ? 'given' : 'your answer'}';
  }
}
