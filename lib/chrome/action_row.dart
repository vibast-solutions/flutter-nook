import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// One control in the row under a board.
///
/// An action with no [onTap] reads as unavailable: greyed, and inert to a tap
/// rather than doing nothing invisibly.
@immutable
class BoardAction {
  const BoardAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.unavailableReason,
  });

  /// The word under the icon.
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

  /// Whether the action can be used right now.
  bool get isEnabled => onTap != null;
}

/// The row of controls between a board and its number pad.
///
/// Shared rather than Sudoku's own: Stars and Duo get the same row, and the
/// remaining Sudoku controls — notes (VIB-72) and hints (VIB-76) — are further
/// entries in the same list rather than a second row.
class BoardActionRow extends StatelessWidget {
  const BoardActionRow({required this.actions, super.key});

  /// The controls, left to right. They share the width evenly.
  final List<BoardAction> actions;

  /// The key of the tile for the action labelled [label].
  static Key keyFor(String label) =>
      ValueKey<String>('board-action-${label.toLowerCase()}');

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
    final bool enabled = action.isEnabled;
    final String? reason = action.unavailableReason;

    return Semantics(
      label: enabled || reason == null
          ? action.label
          : '${action.label}, $reason',
      button: true,
      enabled: enabled,
      excludeSemantics: true,
      child: Material(
        key: BoardActionRow.keyFor(action.label),
        color: enabled ? colors.surface : colors.disabledSurface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(NookRadius.key),
          side: BorderSide(color: enabled ? colors.line : colors.disabledLine),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.all(NookRadius.key),
          onTap: action.onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  action.icon,
                  size: 19,
                  color: enabled ? colors.inkMuted : colors.disabledInk,
                ),
                const SizedBox(height: 3),
                Text(
                  action.label,
                  style: NookType.actionLabel(
                    enabled ? colors.inkMuted : colors.disabledInk,
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
