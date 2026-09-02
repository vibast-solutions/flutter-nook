import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/app_localizations.dart';

/// The row of digits under the board, each showing how many of it are left to
/// place.
///
/// A digit that has been placed as often as the grid can hold it is greyed but
/// stays tappable. Disabling it would be a trap: with four 3s down and one of
/// them wrong, the count reads zero, and the way to take the wrong one back is
/// to tap that same 3 again.
class NumberPad extends StatelessWidget {
  const NumberPad({
    required this.digits,
    required this.remaining,
    required this.onDigit,
    super.key,
  });

  /// The largest digit on the pad; keys run from 1 to this.
  final int digits;

  /// How many of [digit] are still to be placed.
  final int Function(int digit) remaining;

  /// Called with the tapped digit.
  final ValueChanged<int> onDigit;

  /// The most keys Nook will put in one row.
  ///
  /// Past this the keys get too narrow to hit comfortably on the smallest
  /// phone the app supports, so the pad takes a second row instead.
  static const int maxPerRow = 5;

  /// How many keys go in each row of a pad with [digits] of them.
  ///
  /// Rows are balanced rather than filled to the brim: six digits become two
  /// rows of three, not a row of five and a lone key, and nine become the five
  /// and four the designs draw. Four still fit on one row.
  static int columnsFor(int digits) {
    if (digits <= maxPerRow) {
      return digits;
    }
    final int rows = (digits / maxPerRow).ceil();
    return (digits / rows).ceil();
  }

  /// The key of the pad key for [digit].
  static Key keyFor(int digit) => ValueKey<String>('pad-key-$digit');

  @override
  Widget build(BuildContext context) {
    final int columns = columnsFor(digits);
    final List<Widget> rows = <Widget>[];
    for (int start = 1; start <= digits; start += columns) {
      final int end = (start + columns - 1).clamp(start, digits);
      rows.add(
        Row(
          children: <Widget>[
            for (int digit = start; digit <= end; digit++) ...<Widget>[
              if (digit != start) const SizedBox(width: 9),
              Expanded(
                child: _PadKey(
                  digit: digit,
                  remaining: remaining(digit),
                  onTap: onDigit,
                ),
              ),
            ],
            // Keeps a short final row aligned with the one above it.
            for (
              int filler = end + 1;
              filler < start + columns;
              filler++
            ) ...<Widget>[
              const SizedBox(width: 9),
              const Expanded(child: SizedBox.shrink()),
            ],
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < rows.length; i++) ...<Widget>[
          if (i != 0) const SizedBox(height: 9),
          rows[i],
        ],
      ],
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({
    required this.digit,
    required this.remaining,
    required this.onTap,
  });

  final int digit;
  final int remaining;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool spent = remaining == 0;
    // Both of these are plural messages rather than a count glued to a word:
    // English gets away with one form, most languages do not, and "none left"
    // is its own case in several.
    final String caption = l10n.padCaption(remaining);

    return Semantics(
      label: l10n.padKeyLabel(digit, remaining),
      button: true,
      excludeSemantics: true,
      child: Material(
        key: NumberPad.keyFor(digit),
        color: spent ? colors.disabledSurface : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(NookRadius.key),
          side: BorderSide(color: spent ? colors.disabledLine : colors.line),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.all(NookRadius.key),
          onTap: () => onTap(digit),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '$digit',
                  style: NookType.padDigit(
                    spent ? colors.disabledInk : colors.ink,
                    25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: NookType.padCount(
                    spent ? colors.disabledInkFaint : colors.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
