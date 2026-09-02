import 'dart:math' as math;

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
/// animating a single cell costs nothing. A [CustomPainter] would have to
/// reimplement all three, and accessibility is a stated goal for Nook rather
/// than a nice-to-have. The one thing that is painted is the hatch across a
/// conflicting cell, which has nothing to hit and nothing to read out — the
/// sentence a screen reader hears is on the cell itself.
///
/// Stateful for the two things the board says by moving: a unit pulsing as it
/// is completed, and a wrong digit being crossed out as a hint takes it away.
/// Both are transitions rather than states, so they are found by comparing the
/// game that arrives with the one before it — the state itself only ever
/// describes the board as it stands.
class SudokuBoard extends StatefulWidget {
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

  /// How long a completed row, column or box is washed with colour for.
  ///
  /// Short enough to read as a nod rather than an interruption: a player
  /// finishing a 9x9 sets this off dozens of times.
  static const Duration pulseDuration = Duration(milliseconds: 300);

  /// How long the cross a hint draws over a wrong digit stays up for.
  static const Duration removalDuration = Duration(milliseconds: 300);

  /// The key of the cell at [index], so tests can reach a known cell without
  /// depending on how it happens to look at the time.
  static Key cellKey(int index) => ValueKey<String>('sudoku-cell-$index');

  /// The key of the answer drawn in the cell at [index], if it holds one.
  static Key valueKey(int index) => ValueKey<String>('sudoku-value-$index');

  /// The key of the pencil marks drawn in the cell at [index], if it shows
  /// them.
  static Key notesKey(int index) => ValueKey<String>('sudoku-notes-$index');

  /// The key of the hatch across the cell at [index], drawn when its digit is
  /// repeated in a row, column or box it belongs to.
  static Key conflictKey(int index) =>
      ValueKey<String>('sudoku-conflict-$index');

  /// The key of the wash over the cell at [index] while the unit it just
  /// completed is being celebrated.
  static Key pulseKey(int index) => ValueKey<String>('sudoku-pulse-$index');

  /// The key of the cross drawn over the cell at [index] as a hint takes a
  /// wrong digit out of it.
  static Key removalKey(int index) => ValueKey<String>('sudoku-removal-$index');

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends State<SudokuBoard>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: SudokuBoard.pulseDuration,
  )..addStatusListener(_pulseEnded);

  /// Runs whether or not the board is allowed to move: it is what times the
  /// sentence a screen reader is given about the cell, and holding a label for
  /// a moment is not motion.
  late final AnimationController _removal = AnimationController(
    vsync: this,
    duration: SudokuBoard.removalDuration,
  )..addStatusListener(_removalEnded);

  /// The cells of the units completed by the move that just landed.
  Set<int> _pulsing = const <int>{};

  /// The digit a hint is in the middle of taking off the board.
  HintRemoval? _removing;

  @override
  void didUpdateWidget(SudokuBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startPulse(oldWidget.game);
    _startRemoval(oldWidget.game);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _removal.dispose();
    super.dispose();
  }

  /// Pulses whatever the last move completed, if anything.
  ///
  /// The union of the newly completed units rather than one pulse each: a
  /// digit can finish a row and its box at once, and two washes over the cell
  /// they share would read as a mistake rather than as two pieces of good
  /// news.
  void _startPulse(SudokuGameState before) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    final Set<int> completed = widget.game.completedUnits.difference(
      before.completedUnits,
    );
    if (completed.isEmpty) {
      return;
    }
    setState(() => _pulsing = completed);
    _pulse.forward(from: 0);
  }

  void _pulseEnded(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() => _pulsing = const <int>{});
    }
  }

  /// Crosses out a digit a hint has just taken away.
  void _startRemoval(SudokuGameState before) {
    final HintRemoval? removal = widget.game.hintRemoval;
    if (removal == null || removal == before.hintRemoval) {
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
    final SudokuGameState game = widget.game;
    final int size = game.size;
    // The frame sits outside the cells, so the cells share what is left.
    final double cell = (edge - SudokuBoard.ruleWidth * 2) / size;

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
            border: Border.all(
              color: colors.boardRule,
              width: SudokuBoard.ruleWidth,
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
              animation: Listenable.merge(<Listenable>[_pulse, _removal]),
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
      ),
    );
  }

  Widget _cellAt(int index, double extent) {
    final HintRemoval? removing = _removing;
    return _SudokuCell(
      game: widget.game,
      index: index,
      extent: extent,
      onTap: widget.onSelect,
      // A wash that swells and falls away again rather than one that fades in
      // and cuts: the unit is being nodded at, not switched on.
      pulse: _pulsing.contains(index) ? math.sin(math.pi * _pulse.value) : 0,
      removing: removing != null && removing.index == index ? removing : null,
      removalProgress: _removal.value,
    );
  }
}

/// One cell: its background says how it relates to the selection, its digit
/// says who put it there, and a hatch across it says the digit is repeated
/// somewhere it can see.
class _SudokuCell extends StatelessWidget {
  const _SudokuCell({
    required this.game,
    required this.index,
    required this.extent,
    required this.onTap,
    required this.pulse,
    required this.removing,
    required this.removalProgress,
  });

  final SudokuGameState game;
  final int index;
  final double extent;
  final ValueChanged<int> onTap;

  /// How strongly to wash this cell with the completed-unit colour, 0 to 1.
  final double pulse;

  /// The digit a hint is taking out of this cell, or `null` if it is not this
  /// cell's turn to be crossed out.
  final HintRemoval? removing;

  /// How far through the crossing-out the board is, 0 to 1.
  final double removalProgress;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final int size = game.size;
    final int row = game.spec.rowOf(index);
    final int column = game.spec.columnOf(index);
    final int value = game.cells[index];
    final bool given = game.isGiven(index);
    final bool hinted = game.isHinted(index);
    final bool conflicting = game.isConflicting(index);
    final int? selected = game.selectedIndex;
    final bool isSelected = selected == index;

    // The selection wins over the conflict wash, because a player who has lost
    // track of where the pad is pointing has a worse problem than a repeat
    // they can still see hatched.
    Color background = colors.surface;
    if (conflicting) {
      background = colors.cellConflict;
    }
    if (selected != null) {
      final int selectedDigit = game.selectedDigit;
      if (isSelected) {
        background = colors.cellSelected;
      } else if (!conflicting && selectedDigit != 0 && value == selectedDigit) {
        background = colors.cellMatching;
      } else if (!conflicting && game.sharesUnit(index, selected)) {
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
        hinted: hinted,
        conflicting: conflicting,
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
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Colour never carries a meaning by itself on a Nook board, so
              // the wash comes with a hatch a player can read without it.
              if (conflicting)
                Positioned.fill(
                  child: CustomPaint(
                    key: SudokuBoard.conflictKey(index),
                    painter: _ConflictHatch(
                      colour: colors.conflictLine.withValues(alpha: 0.30),
                    ),
                  ),
                ),
              if (pulse > 0)
                Positioned.fill(
                  key: SudokuBoard.pulseKey(index),
                  child: ColoredBox(
                    color: colors.cellComplete.withValues(alpha: 0.85 * pulse),
                  ),
                ),
              ?_content(colors),
            ],
          ),
        ),
      ),
    );
  }

  /// What the cell has to show: a digit going away, an answer, or its marks.
  Widget? _content(NookColors colors) {
    final HintRemoval? removal = removing;
    if (removal != null) {
      return _Removal(
        digit: removal.digit,
        extent: extent,
        progress: removalProgress,
        cross: colors.conflictLine,
        ink: colors.clay,
        cellKey: SudokuBoard.removalKey(index),
      );
    }
    final int value = game.cells[index];
    if (value != 0) {
      return Text(
        '$value',
        key: SudokuBoard.valueKey(index),
        // Three voices on one board: the puzzle's digits, the player's, and
        // the ones a hint gave away. A hint stays marked for as long as it
        // holds the cell, so where the player got to is still readable
        // afterwards. A conflict is said by the cell around the digit rather
        // than by a fourth colour, which would leave no way to tell whose
        // digit it was.
        style: NookType.cellDigit(
          game.isGiven(index)
              ? colors.ink
              : game.isHinted(index)
              ? colors.hintInk
              : colors.clay,
          extent * 0.5,
        ),
      );
    }
    if (game.showsNotes(index)) {
      return _CellNotes(
        key: SudokuBoard.notesKey(index),
        marks: game.notesAt(index),
        digits: game.size,
        columns: game.spec.boxWidth,
        extent: extent,
      );
    }
    return null;
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
    required bool hinted,
    required bool conflicting,
  }) {
    final int line = row + 1;
    final int column1 = column + 1;
    // A digit on its way off the board says so, so a player who cannot see it
    // fade is told why the cell they were on has emptied.
    final HintRemoval? removal = removing;
    if (removal != null) {
      return l10n.cellCleared(line, column1, removal.digit);
    }
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
    if (given) {
      return conflicting
          ? l10n.cellGivenConflict(line, column1, value)
          : l10n.cellGiven(line, column1, value);
    }
    // A colour is how a sighted player tells a hint from their own answer;
    // this is the same fact for a player who is not reading colours. The hatch
    // saying the digit is repeated is spelled out the same way.
    if (hinted) {
      return conflicting
          ? l10n.cellHintConflict(line, column1, value)
          : l10n.cellHint(line, column1, value);
    }
    return conflicting
        ? l10n.cellAnswerConflict(line, column1, value)
        : l10n.cellAnswer(line, column1, value);
  }
}

/// A digit being taken off the board by a hint, crossed out and fading.
///
/// The cross is what makes the disappearance mean something: a cell that
/// simply blanked would read as the app losing an answer rather than as the
/// player being told, in the one way they asked for, that it was wrong.
class _Removal extends StatelessWidget {
  const _Removal({
    required this.digit,
    required this.extent,
    required this.progress,
    required this.cross,
    required this.ink,
    required this.cellKey,
  });

  final int digit;
  final double extent;
  final double progress;
  final Color cross;
  final Color ink;
  final Key cellKey;

  @override
  Widget build(BuildContext context) {
    // Under a request for less motion there is nothing to watch: the digit is
    // already gone from the grid, and this draws nothing over the gap. The
    // cell still says what happened to a screen reader.
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
          Text('$digit', style: NookType.cellDigit(ink, extent * 0.5)),
          Icon(Icons.close_rounded, size: extent * 0.62, color: cross),
        ],
      ),
    );
  }
}

/// Diagonal lines across a cell, so a conflict is readable without colour.
class _ConflictHatch extends CustomPainter {
  const _ConflictHatch({required this.colour});

  final Color colour;

  /// The gap between one line and the next, in logical pixels.
  ///
  /// Fixed rather than a fraction of the cell: the hatch has to stay a hatch
  /// on a 9x9's small cells, and a pattern that scaled with them would turn
  /// into two fat stripes.
  static const double step = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = colour
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_ConflictHatch oldDelegate) =>
      oldDelegate.colour != colour;
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
