import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/app_localizations.dart';

/// One control in the row under a board.
///
/// An action with no [onTap] reads as unavailable: greyed, and inert to a tap
/// rather than doing nothing invisibly.
@immutable
class BoardAction {
  const BoardAction({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
    this.unavailableReason,
    this.isOn,
  });

  /// What this control is, independent of what it is called.
  ///
  /// Keys are built from this rather than from [label] because the label is
  /// translated: a widget key that changes with the player's language is not a
  /// key, and a test looking for one would pass or fail by locale.
  final String id;

  /// The word under the icon, already in the player's language.
  final String label;

  /// The glyph above it.
  final IconData icon;

  /// What the action does, or `null` when it is unavailable.
  final VoidCallback? onTap;

  /// Why the action is unavailable, read out after the label.
  ///
  /// A greyed control tells a sighted player it cannot be used; this is how
  /// the same thing reaches a player using a screen reader.
  final String? unavailableReason;

  /// Whether this control is a switch, and whether it is currently on.
  ///
  /// `null` for the controls that simply do something when tapped. A switch
  /// changes what every later tap of the pad means, so it says so twice over:
  /// it fills with the accent, and its label spells out `on` or `off`. A
  /// player who cannot tell will write marks they meant as answers.
  final bool? isOn;

  /// Whether the action can be used right now.
  bool get isEnabled => onTap != null;
}

/// The row of controls between a board and its number pad.
///
/// Shared rather than Sudoku's own: Stars and Duo get the same row, and the
/// remaining Sudoku control — hints (VIB-76) — is a further entry in the same
/// list rather than a second row.
class BoardActionRow extends StatelessWidget {
  const BoardActionRow({required this.actions, super.key});

  /// The controls, left to right. They share the width evenly.
  final List<BoardAction> actions;

  /// The key of the tile for the action with this [id].
  static Key keyFor(String id) => ValueKey<String>('board-action-$id');

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < actions.length; i++) ...<Widget>[
          if (i != 0) const SizedBox(width: 10),
          Expanded(child: _ActionTile(action: actions[i])),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});

  final BoardAction action;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool enabled = action.isEnabled;
    final String? reason = action.unavailableReason;
    final bool? isOn = action.isOn;
    final bool lit = enabled && (isOn ?? false);

    // A switch that is on is filled with the accent and reads back out of it;
    // everything else sits on a surface. Unavailable wins over both, because a
    // control that cannot be used should not look like the loudest thing on
    // the screen.
    final Color background = !enabled
        ? colors.disabledSurface
        : lit
        ? colors.clay
        : colors.surface;
    final Color edge = !enabled
        ? colors.disabledLine
        : lit
        ? colors.clay
        : colors.line;
    final Color content = !enabled
        ? colors.disabledInk
        : lit
        ? colors.surface
        : colors.inkMuted;

    return Semantics(
      label: enabled || reason == null
          ? action.label
          : l10n.actionUnavailableLabel(action.label, reason),
      button: true,
      enabled: enabled,
      toggled: isOn,
      excludeSemantics: true,
      child: Material(
        key: BoardActionRow.keyFor(action.id),
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(NookRadius.key),
          side: BorderSide(color: edge),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.all(NookRadius.key),
          onTap: action.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(action.icon, size: 19, color: content),
                const SizedBox(height: 3),
                Text(switch (isOn) {
                  null => action.label,
                  true => l10n.actionToggleOn(action.label),
                  false => l10n.actionToggleOff(action.label),
                }, style: NookType.actionLabel(content)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
