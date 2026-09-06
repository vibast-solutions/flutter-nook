import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../store/nook_database.dart';
import 'snake_naming.dart';
import 'snake_screen.dart';
import 'snake_variant.dart';

/// The screen between choosing Snake and playing it: a pace to run at.
///
/// It deliberately borrows the shell and spacing of the puzzle games'
/// [DifficultyPage] — a titled header, a labelled list of tappable rows — but it
/// is not that page and does not carry a [PuzzleDifficulty]. A puzzle's
/// difficulty is *measured*; a Snake speed is simply *chosen*, so this is a small
/// screen of its own over a Snake-native [SnakeSpeed]. There is no guarantee card
/// and no in-progress card: Snake keeps no save and makes no promise about the
/// board it will hand back.
class SnakeSpeedPage extends ConsumerWidget {
  const SnakeSpeedPage({required this.variant, super.key});

  /// The Snake variant a speed is being chosen for.
  final SnakeVariant variant;

  /// Builds a route to the speed picker for [variant].
  static Route<void> route(SnakeVariant variant) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => SnakeSpeedPage(variant: variant),
    );
  }

  /// The key of the row that starts a run at [speed].
  ///
  /// Built from the enum name, never the translated label, so a test can find a
  /// row without knowing the player's language.
  static Key speedKey(SnakeSpeed speed) =>
      ValueKey<String>('snake-speed-${speed.name}');

  /// Opens a run at the chosen speed, remembering it as the last-used speed so
  /// the picker opens on it next time. The write happens as the run starts, not
  /// when it ends: choosing a speed is the preference, whatever the run does.
  ///
  /// The picker stays underneath, so leaving the game returns here rather than
  /// all the way home.
  void _start(BuildContext context, WidgetRef ref, SnakeSpeed speed) {
    ref.read(snakeSpeedPrefStoreProvider).setLastLevel(speed.level);
    Navigator.of(context).push(SnakeGamePage.route(variant, speed: speed));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    // The best score at each level, keyed by level. Absent until a run sets one,
    // so a level with no best simply has no entry.
    final Map<int, int> bests =
        ref.watch(snakeScoresProvider).value ?? const <int, int>{};
    // The speed to open on: the one the player last ran at, or the standard
    // middle rung when nothing has been played yet.
    final int selectedLevel =
        ref.watch(snakeLastLevelProvider).value ?? SnakeSpeed.standard.level;

    return Scaffold(
      backgroundColor: colors.sand,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(title: l10n.snakeSpeedTitle),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
                children: <Widget>[
                  Text(
                    l10n.snakeSpeedHeading,
                    style: NookType.sectionLabel(colors.inkFaint),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.snakeSpeedBlurb,
                    style: NookType.rowSubtitle(colors.inkMuted),
                  ),
                  const SizedBox(height: 14),
                  for (final SnakeSpeed speed in SnakeSpeed.values) ...<Widget>[
                    _SpeedRow(
                      speed: speed,
                      best: bests[speed.level],
                      selected: speed.level == selectedLevel,
                      onTap: () => _start(context, ref, speed),
                    ),
                    const SizedBox(height: 9),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The header: a way back, and the game's name. A Snake copy of the difficulty
/// screen's header rather than the shared one, so this file stays free of the
/// puzzle chrome.
class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 4),
      child: Row(
        children: <Widget>[
          Semantics(
            label: AppLocalizations.of(context).backToGameList,
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
                onTap: () => Navigator.of(context).maybePop(),
                child: SizedBox(
                  width: kMinTapTarget,
                  height: kMinTapTarget,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: colors.inkMuted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: NookType.screenTitle(colors.ink))),
        ],
      ),
    );
  }
}

/// One speed, and the way into a run at it.
class _SpeedRow extends StatelessWidget {
  const _SpeedRow({
    required this.speed,
    required this.best,
    required this.selected,
    required this.onTap,
  });

  final SnakeSpeed speed;

  /// The best score reached at this speed, or `null` if it has never been played.
  final int? best;

  /// Whether this is the speed the picker opens on — the one the player last ran
  /// at, or the standard speed before any run. It carries a "Last played" marker
  /// and a heavier border so the pre-selection reads without relying on colour,
  /// takes the initial focus, and tells a screen reader it is selected.
  final bool selected;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = speed.label(l10n);
    final String description = speed.blurb(l10n);
    final int? bestScore = best;

    return Semantics(
      // The best rides in the same spoken sentence once there is one, so a
      // screen reader hears the row's whole story rather than a stray number.
      label: bestScore == null
          ? l10n.snakeSpeedRowLabel(name, description)
          : l10n.snakeSpeedRowLabelBest(name, description, bestScore),
      button: true,
      // The pre-selected row is spoken as selected — a screen reader's own copy
      // of the marker and border a sighted player sees.
      selected: selected,
      excludeSemantics: true,
      child: Material(
        key: SnakeSpeedPage.speedKey(speed),
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(NookRadius.row),
          // The selected row is walled off by a heavier rule in the same colour
          // the meter and best use, so the pre-selection is a shape (a thicker
          // border plus the marker below), never a hue alone.
          side: selected
              ? BorderSide(color: colors.clay, width: 2)
              : BorderSide(color: colors.line),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.all(NookRadius.row),
          onTap: onTap,
          // The pre-selected row takes focus as the picker opens, so a keyboard
          // or switch lands on the speed the player last used.
          autofocus: selected,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kMinTapTarget + 10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                name,
                                style: NookType.rowTitle(colors.ink),
                              ),
                            ),
                            // The word that carries the pre-selection to a
                            // sighted player, so it never rides on colour alone.
                            if (selected) ...<Widget>[
                              const SizedBox(width: 8),
                              _LastPlayedTag(label: l10n.snakeSpeedLastPlayed),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: NookType.rowSubtitle(colors.inkMuted),
                        ),
                        // A speed that has been played talks about the player's
                        // best there too; one that has not stays silent, the way
                        // a difficulty row does before its first solve.
                        if (bestScore != null) ...<Widget>[
                          const SizedBox(height: 3),
                          Text(
                            l10n.snakeBest(bestScore),
                            style: NookType.rowSubtitle(colors.clay),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  _SpeedMeter(speed: speed),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: colors.inkGhost,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The small "Last played" marker on the pre-selected speed row.
///
/// A pill in the clay the row's border and best use, its text
/// [ExcludeSemantics] because the row already tells a screen reader it is
/// selected — the tag is the sighted player's copy of that.
class _LastPlayedTag extends StatelessWidget {
  const _LastPlayedTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.claySoft,
        borderRadius: const BorderRadius.all(NookRadius.tile),
      ),
      child: ExcludeSemantics(
        child: Text(label, style: NookType.sectionLabel(colors.clay)),
      ),
    );
  }
}

/// The little climbing bars beside a speed, one rung per level — a mirror of the
/// difficulty screen's meter. Colour is decorative here: the row's name already
/// says which speed it is, so the bars never carry the meaning alone.
class _SpeedMeter extends StatelessWidget {
  const _SpeedMeter({required this.speed});

  final SnakeSpeed speed;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final int filled = speed.level;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int rung = 0; rung < SnakeSpeed.values.length; rung++)
          Padding(
            padding: EdgeInsets.only(left: rung == 0 ? 0 : 3),
            child: Container(
              width: 5,
              height: 6 + rung * 3,
              decoration: BoxDecoration(
                color: rung < filled ? colors.clay : colors.sunk,
                borderRadius: const BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
      ],
    );
  }
}
