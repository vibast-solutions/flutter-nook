import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/app_localizations.dart';

/// Asks before throwing away the puzzle the player has not finished.
///
/// The only destructive thing Nook can do, so it is the only thing that asks.
/// The buttons say what they do rather than yes and no: a player who reads one
/// word of a dialogue should still be able to tell which way is back.
class DiscardDialog extends StatelessWidget {
  const DiscardDialog({required this.gameName, super.key});

  /// The key of the button that throws the saved puzzle away.
  static const Key confirmKey = ValueKey<String>('discard-confirm');

  /// The key of the button that leaves it alone.
  static const Key keepKey = ValueKey<String>('discard-keep');

  /// The game whose saved puzzle is at stake, in the player's language.
  final String gameName;

  /// Shows the question, and answers whether the player said to go ahead.
  ///
  /// Dismissing the dialogue any other way — the back gesture, a tap outside —
  /// counts as keeping the puzzle. The safe answer is the default in every
  /// direction.
  static Future<bool> ask(BuildContext context, {required String gameName}) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => DiscardDialog(gameName: gameName),
    ).then((bool? answer) => answer ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(NookRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(l10n.discardTitle, style: NookType.title(colors.ink)),
            const SizedBox(height: 10),
            Text(
              l10n.discardBody(gameName),
              style: NookType.rowSubtitle(colors.inkMuted),
            ),
            const SizedBox(height: 20),
            // Wrapped rather than in a row: both labels are translated, and
            // two buttons that fit side by side in English are two buttons
            // that run off the edge in German.
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                _DialogButton(
                  buttonKey: keepKey,
                  label: l10n.discardKeep,
                  onTap: () => Navigator.of(context).pop(false),
                  background: colors.sunk,
                  ink: colors.ink,
                ),
                _DialogButton(
                  buttonKey: confirmKey,
                  label: l10n.discardConfirm,
                  onTap: () => Navigator.of(context).pop(true),
                  background: colors.clay,
                  ink: colors.surface,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.buttonKey,
    required this.label,
    required this.onTap,
    required this.background,
    required this.ink,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onTap;
  final Color background;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: buttonKey,
      color: background,
      borderRadius: const BorderRadius.all(NookRadius.key),
      child: InkWell(
        borderRadius: const BorderRadius.all(NookRadius.key),
        onTap: onTap,
        child: Container(
          height: kMinTapTarget,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(label, style: NookType.actionLabel(ink)),
        ),
      ),
    );
  }
}
