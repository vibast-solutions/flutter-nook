import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/sudoku/difficulty_screen.dart';
import '../games/sudoku/sudoku_naming.dart';
import '../games/sudoku/sudoku_variant.dart';
import '../l10n/app_localizations.dart';

/// A game in the list on the home screen.
@immutable
class _GameEntry {
  const _GameEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.open,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Whether the icon tile uses the primary or the secondary accent.
  final bool accent;

  /// How to start the game, or `null` while it is still being built.
  final void Function(BuildContext context)? open;

  bool get isPlayable => open != null;
}

/// The first screen: what you were playing, and everything you can play.
///
/// All three Sudokus are live; Stars and Duo are listed rather than hidden
/// because the list is the promise — a player should be able to see where Nook
/// is going, and a greyed row is more honest than an empty screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// The list, in the player's language.
  ///
  /// Built per locale rather than once at start-up: a row carries the words it
  /// shows, and those words are only known once there is an [AppLocalizations]
  /// to ask.
  static List<_GameEntry> _games(AppLocalizations l10n) => <_GameEntry>[
    _sudoku(l10n, SudokuVariant.classic, Icons.grid_on_rounded),
    _sudoku(l10n, SudokuVariant.light, Icons.grid_view_rounded),
    _sudoku(l10n, SudokuVariant.mini, Icons.window_rounded),
    _GameEntry(
      title: l10n.starsTitle,
      subtitle: l10n.starsSubtitle,
      icon: Icons.star_outline_rounded,
      accent: false,
    ),
    _GameEntry(
      title: l10n.duoTitle,
      subtitle: l10n.duoSubtitle,
      icon: Icons.circle_outlined,
      accent: false,
    ),
  ];

  /// A row for one of the Sudokus.
  ///
  /// Built from the variant rather than written out three times: the grid
  /// size, the title and the route all come from the one place that knows
  /// them, so a fourth variant is a line here and nothing else. The designs
  /// put a best time where the blurb sits; there is nothing honest to put
  /// there until times are kept (VIB-77).
  static _GameEntry _sudoku(
    AppLocalizations l10n,
    SudokuVariant variant,
    IconData icon,
  ) {
    return _GameEntry(
      title: variant.title(l10n),
      subtitle: l10n.gameRowSubtitle(
        variant.sizeLabel(l10n),
        variant.blurb(l10n),
      ),
      icon: icon,
      accent: true,
      open: (BuildContext context) =>
          Navigator.of(context).push(SudokuDifficultyPage.route(variant)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colors.sand,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(l10n.appTitle, style: NookType.wordmark(colors.ink)),
            ),
            Text(
              l10n.homeAllGames,
              style: NookType.sectionLabel(colors.inkFaint),
            ),
            const SizedBox(height: 9),
            for (final _GameEntry game in _games(l10n)) ...<Widget>[
              _GameRow(entry: game),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 14),
            Center(
              child: Text(
                l10n.homePromise,
                style: NookType.footnote(colors.inkGhost),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.entry});

  final _GameEntry entry;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool playable = entry.isPlayable;
    final Color tile = entry.accent ? colors.claySoft : colors.sageSoft;
    final Color glyph = entry.accent ? colors.clay : colors.sage;

    return Opacity(
      opacity: playable ? 1 : 0.55,
      child: Semantics(
        label: playable
            ? l10n.gameRowLabel(entry.title, entry.subtitle)
            : l10n.gameRowUnavailableLabel(entry.title),
        button: true,
        enabled: playable,
        excludeSemantics: true,
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(NookRadius.row),
            side: BorderSide(color: colors.line),
          ),
          child: InkWell(
            borderRadius: const BorderRadius.all(NookRadius.row),
            onTap: playable ? () => entry.open!(context) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: tile,
                      borderRadius: const BorderRadius.all(NookRadius.tile),
                    ),
                    child: Icon(entry.icon, size: 20, color: glyph),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(entry.title, style: NookType.rowTitle(colors.ink)),
                        const SizedBox(height: 1),
                        Text(
                          entry.subtitle,
                          style: NookType.rowSubtitle(colors.inkMuted),
                        ),
                      ],
                    ),
                  ),
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
