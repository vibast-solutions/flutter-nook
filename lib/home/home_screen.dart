import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/sudoku/sudoku_screen.dart';
import '../games/sudoku/sudoku_variant.dart';

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
/// Only Sudoku Mini is live. The rest are listed rather than hidden because
/// the list is the promise — a player should be able to see where Nook is
/// going, and a greyed row is more honest than an empty screen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static final List<_GameEntry> _games = <_GameEntry>[
    _GameEntry(
      title: SudokuVariant.classic.title,
      subtitle: '${SudokuVariant.classic.sizeLabel} · coming soon',
      icon: Icons.grid_on_rounded,
      accent: true,
    ),
    _GameEntry(
      title: SudokuVariant.light.title,
      subtitle: '${SudokuVariant.light.sizeLabel} · coming soon',
      icon: Icons.grid_view_rounded,
      accent: true,
    ),
    _GameEntry(
      title: SudokuVariant.mini.title,
      subtitle: '${SudokuVariant.mini.sizeLabel} · a few quiet minutes',
      icon: Icons.window_rounded,
      accent: true,
      open: _openMini,
    ),
    const _GameEntry(
      title: 'Stars',
      subtitle: 'One star per row, column and region · coming soon',
      icon: Icons.star_outline_rounded,
      accent: false,
    ),
    const _GameEntry(
      title: 'Duo',
      subtitle: 'Circles and squares, never three in a row · coming soon',
      icon: Icons.circle_outlined,
      accent: false,
    ),
  ];

  static void _openMini(BuildContext context) {
    Navigator.of(context).push(SudokuGamePage.route(SudokuVariant.mini));
  }

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;

    return Scaffold(
      backgroundColor: colors.sand,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 22),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text('Nook', style: NookType.wordmark(colors.ink)),
            ),
            Text('ALL GAMES', style: NookType.sectionLabel(colors.inkFaint)),
            const SizedBox(height: 9),
            for (final _GameEntry game in _games) ...<Widget>[
              _GameRow(entry: game),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 14),
            Center(
              child: Text(
                'No ads. No tracking. No account. Ever.',
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
    final bool playable = entry.isPlayable;
    final Color tile = entry.accent ? colors.claySoft : colors.sageSoft;
    final Color glyph = entry.accent ? colors.clay : colors.sage;

    return Opacity(
      opacity: playable ? 1 : 0.55,
      child: Semantics(
        label: playable
            ? '${entry.title}. ${entry.subtitle}'
            : '${entry.title}. Not available yet',
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
