import 'dart:async';

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
    this.pacing,
    this.pacedReason,
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

  /// How long the control waits before it can be used again, or `null` for a
  /// control that can be tapped as fast as a player likes.
  ///
  /// Pacing, not rationing: nothing is being counted, spent or held back, and
  /// there is no budget anywhere behind this. It is the room a hint needs to
  /// land — an invitation to look at the board again rather than to tap again
  /// — and it is why a player cannot fall into asking and checking in a
  /// rhythm that takes the puzzle away from them.
  final Duration? pacing;

  /// Why the control is unavailable while it is pacing itself, read out after
  /// the label the way [unavailableReason] is.
  final String? pacedReason;

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

  /// The key of the colour wiping back into the tile for the action with this
  /// [id] while it waits out its [BoardAction.pacing].
  static Key paceKey(String id) => ValueKey<String>('board-pace-$id');

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < actions.length; i++) ...<Widget>[
          if (i != 0) const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              // Keyed by what the control is, so a tile that is pacing itself
              // keeps its own timer if the row is ever rebuilt in a different
              // order.
              key: ValueKey<String>(actions[i].id),
              action: actions[i],
            ),
          ),
        ],
      ],
    );
  }
}

/// A control, and the wait after it when it has one.
///
/// Stateful only for the pacing: the tile owns the clock rather than the game,
/// because how often a control offers itself is a property of the control and
/// every game gets the same one.
class _ActionTile extends StatefulWidget {
  const _ActionTile({required this.action, super.key});

  final BoardAction action;

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pace = AnimationController(
    vsync: this,
    duration: widget.action.pacing ?? Duration.zero,
  );

  @override
  void didUpdateWidget(_ActionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final Duration? pacing = widget.action.pacing;
    if (pacing != null && pacing != oldWidget.action.pacing) {
      _pace.duration = pacing;
    }
  }

  @override
  void dispose() {
    _pace.dispose();
    super.dispose();
  }

  /// Whether the control is in the middle of its wait.
  bool get _pacing => _pace.isAnimating;

  void _tap() {
    final VoidCallback? onTap = widget.action.onTap;
    if (onTap == null) {
      return;
    }
    onTap();
    if (widget.action.pacing != null) {
      unawaited(_pace.forward(from: 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pace,
      builder: (BuildContext context, Widget? child) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final BoardAction action = widget.action;
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool paced = _pacing;
    final bool enabled = action.isEnabled && !paced;
    final String? reason = paced
        ? (action.pacedReason ?? action.unavailableReason)
        : action.unavailableReason;
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
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: const BorderRadius.all(NookRadius.key),
          onTap: enabled ? _tap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            // The label sizes the tile and the wipe fills whatever that comes
            // to, so a pacing control is exactly the same shape as a waiting
            // one and the row does not shuffle as the colour comes back.
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                if (paced) _wipe(colors),
                Column(
                  mainAxisSize: MainAxisSize.min,
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The control's own colour coming back, left edge first.
  ///
  /// A filling bar rather than a number: what a player needs to know is that
  /// the wait is short and already going, and a countdown would turn a pause
  /// into something to watch.
  Widget _wipe(NookColors colors) {
    // A wipe is motion, so a player who has asked for less of it gets a plain
    // greyed control that comes back when it comes back.
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      key: BoardActionRow.paceKey(widget.action.id),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: _pace.value,
          heightFactor: 1,
          child: ColoredBox(color: colors.surface),
        ),
      ),
    );
  }
}
