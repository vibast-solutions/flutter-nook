import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// The card that offers a puzzle the player left unfinished.
///
/// The same card on the home screen and on a game's own screen, because it is
/// the same offer: one tap and the board comes back exactly as it was. It is
/// only ever built when there is a save, so there is no empty state to design
/// — nothing in progress means no card, which is what the designs show.
class ContinueCard extends StatelessWidget {
  const ContinueCard({
    required this.icon,
    required this.title,
    required this.details,
    required this.semanticLabel,
    required this.onTap,
    super.key,
  });

  /// The key of the card, so a test can say whether one is being offered.
  static const Key cardKey = ValueKey<String>('continue-card');

  /// The glyph on the tile, matching the game's own.
  final IconData icon;

  /// The first line: which game, or which tier where the game is already
  /// named above.
  final String title;

  /// The second line: how long it has been played for and how far it has got.
  final String details;

  /// What a screen reader says instead of reading the two lines apart.
  final String semanticLabel;

  /// Called when the player asks to carry on.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;

    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: Material(
        key: cardKey,
        color: colors.sageSoft,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(NookRadius.row),
          side: BorderSide(color: colors.sageLine),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.all(NookRadius.row),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: const BorderRadius.all(NookRadius.tile),
                  ),
                  child: Icon(icon, size: 20, color: colors.sage),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: NookType.rowTitle(colors.sageInk)),
                      const SizedBox(height: 1),
                      Text(
                        details,
                        style: NookType.rowSubtitle(colors.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.play_arrow_rounded, size: 20, color: colors.sage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
