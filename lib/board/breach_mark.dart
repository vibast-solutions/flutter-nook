import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// The mark a breaching cell wears: its own slot in the grid outlined in the
/// conflict line.
///
/// It is drawn as a full four-sided border rather than the earlier inset wash
/// so it reads as **the box going red**, not a ring floating around the symbol
/// inside it — the cell whose value is wrong is the thing flagged. There is no
/// fill: the outline is the mark, so a Stars region colour or a selected Duo
/// cell still shows through underneath and the breach never hides the state the
/// player is standing on. The stroke is heavier than the grid's hairlines so the
/// outline is a weight a player reads with the colour taken away — the shape,
/// not the hue, carries the meaning — and a screen reader still names the rule
/// that broke, with the same words now set under the board by [BreachCaption].
///
/// Shared by the Stars and Duo boards so the two mark a breach in one language.
/// Sudoku keeps its hatch: a hatch over a bare digit reads cleanly, where over
/// Duo's circles, squares and badges it did not.
class BreachOutline extends StatelessWidget {
  const BreachOutline({super.key});

  /// The stroke of the outline. Bold enough that the cell's edge reads as having
  /// gone red, against the thin hairlines the rest of the grid is ruled with.
  static const double strokeWidth = 2.5;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colors.conflictLine, width: strokeWidth),
      ),
    );
  }
}

/// The line under the board that names, in the conflict colour, the rule the
/// board is currently breaking.
///
/// It is the same fact the breaching cell already gives a screen reader, said
/// once for the eye: a player who cannot see *why* a cell is outlined is told in
/// words, quietly, under the board. It keeps its line whether or not there is a
/// breach — an empty string still lays out one line high — so the board and the
/// controls beneath it do not jump as a breach comes and goes (and, for Duo, as
/// it waits out its delay).
///
/// Excluded from the semantics tree: the breaching cell itself already reads the
/// rule to a screen reader, so voicing it a second time here would only repeat
/// it. This caption is the sighted player's copy of that sentence.
class BreachCaption extends StatelessWidget {
  const BreachCaption({required this.message, super.key});

  /// The rule to name, or `null` when nothing is in breach — the line is still
  /// drawn, empty, to hold its height.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          message ?? '',
          textAlign: TextAlign.center,
          style: NookType.footnote(colors.conflictLine),
        ),
      ),
    );
  }
}
