import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/app_localizations.dart';
import 'play_clock.dart';

/// The bar at the top of a game screen: a way back, what you are playing, and
/// how long you have been at it.
///
/// Shared by every game, because it is the same bar in each — the back button,
/// the game's name over a line saying which grid and how hard, and the clock.
/// Only the two words differ, so they are passed in and everything else is one
/// widget rather than one per game.
class GameHeader extends StatelessWidget {
  const GameHeader({required this.title, required this.subtitle, super.key});

  /// The game's name.
  final String title;

  /// The line under it: which grid, and how hard the player asked for it.
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Row(
        children: <Widget>[
          _IconButtonTile(
            semanticLabel: AppLocalizations.of(context).backToGameList,
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(title, style: NookType.title(colors.ink)),
                const SizedBox(height: 1),
                Text(subtitle, style: NookType.sectionLabel(colors.inkFaint)),
              ],
            ),
          ),
          const _Clock(),
        ],
      ),
    );
  }
}

/// How long this puzzle has been played for.
///
/// Sits opposite the back button, wide enough to keep the title centred as the
/// digits change — a clock that shoved the game's name sideways every time it
/// ticked would be worse than no clock.
class _Clock extends ConsumerWidget {
  const _Clock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final Duration elapsed = ref.watch(playClockProvider);
    final String reading = clockReading(elapsed);

    return Semantics(
      label: AppLocalizations.of(context).gameElapsedLabel(reading),
      excludeSemantics: true,
      child: SizedBox(
        width: kMinTapTarget + 14,
        child: Text(
          reading,
          textAlign: TextAlign.end,
          style: NookType.sectionLabel(colors.inkMuted),
        ),
      ),
    );
  }
}

class _IconButtonTile extends StatelessWidget {
  const _IconButtonTile({
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(NookRadius.tile),
          side: BorderSide(color: colors.line),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.all(NookRadius.tile),
          onTap: onTap,
          child: SizedBox(
            width: kMinTapTarget,
            height: kMinTapTarget,
            child: Icon(icon, size: 18, color: colors.inkMuted),
          ),
        ),
      ),
    );
  }
}
