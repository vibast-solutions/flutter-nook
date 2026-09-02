import 'package:flutter/material.dart';

import '../chrome/note_marks.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/sudoku/sudoku_naming.dart';
import '../games/sudoku/sudoku_state.dart';
import '../l10n/app_localizations.dart';

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

  /// The key of the answer drawn in the cell at [index], if it holds one.
  static Key valueKey(int index) => ValueKey<String>('sudoku-value-$index');

  /// The key of the pencil marks drawn in the cell at [index], if it shows
  /// them.
  static Key notesKey(int index) => ValueKey<String>('sudoku-notes-$index');

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
    final int size = game.size;
    // The frame sits outside the cells, so the cells share what is left.
    final double cell = (edge - ruleWidth * 2) / size;

    // Every glyph on the board is a fraction of a cell, and a cell is a
    // fraction of the screen — so the board already grows with the device.
    // Letting the system text setting scale it a second time only pushes a
    // 9x9's digits past the cell that holds them, which is the opposite of
    // legible. Everything outside the board scales normally.
    return MediaQuery.withNoTextScaling(
      child: Semantics(
        container: true,
        label: l10n.boardLabel(game.variant.title(l10n), size),
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
      label: _describe(
        AppLocalizations.of(context),
        row: row,
        column: column,
        value: value,
        given: given,
      ),
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
          child: value != 0
              ? Text(
                  '$value',
                  key: SudokuBoard.valueKey(index),
                  style: NookType.cellDigit(
                    given ? colors.ink : colors.clay,
                    extent * 0.5,
                  ),
                )
              : game.showsNotes(index)
              ? _CellNotes(
                  key: SudokuBoard.notesKey(index),
                  marks: game.notesAt(index),
                  digits: size,
                  columns: game.spec.boxWidth,
                  extent: extent,
                )
              : null,
        ),
      ),
    );
  }

  /// What a screen reader reads out for this cell. Rows and columns are
  /// counted from one, because that is how a person describes a grid.
  ///
  /// One whole message per state rather than a position with an ending stuck
  /// on it: where the coordinates fall in the sentence is a property of the
  /// language, and a translator needs the whole sentence to move them.
  String _describe(
    AppLocalizations l10n, {
    required int row,
    required int column,
    required int value,
    required bool given,
  }) {
    final int line = row + 1;
    final int column1 = column + 1;
    if (value == 0) {
      final NoteMarks marks = game.notesAt(index);
      if (marks.isNotEmpty) {
        return l10n.cellNotes(
          line,
          column1,
          marks.digits.join(l10n.listSeparator),
        );
      }
      return l10n.cellEmpty(line, column1);
    }
    return given
        ? l10n.cellGiven(line, column1, value)
        : l10n.cellAnswer(line, column1, value);
  }
}

/// The pencil marks in one cell, laid out where their digits would sit.
///
/// A mark keeps the same place whatever else is noted — a 7 is always bottom
/// left of a 9x9's marks — so a player reads the block by position rather than
/// by hunting through it. The block is shaped like the puzzle's own box, which
/// gives a 9x9 the 3x3 of the designs and a 4x4 a sensible 2x2.
class _CellNotes extends StatelessWidget {
  const _CellNotes({
    required this.marks,
    required this.digits,
    required this.columns,
    required this.extent,
    super.key,
  });

  final NoteMarks marks;
  final int digits;
  final int columns;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final int rows = (digits / columns).ceil();
    final TextStyle style = NookType.cellNote(colors.noteInk, extent * 0.24);

    return SizedBox(
      width: extent * 0.9,
      height: extent * 0.82,
      child: Column(
        children: <Widget>[
          for (int row = 0; row < rows; row++)
            Expanded(
              child: Row(
                children: <Widget>[
                  for (int column = 0; column < columns; column++)
                    Expanded(
                      child: Center(
                        child: _mark(row * columns + column + 1, style),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _mark(int digit, TextStyle style) {
    if (digit > digits || !marks.contains(digit)) {
      return const SizedBox.shrink();
    }
    return Text('$digit', style: style);
  }
}
