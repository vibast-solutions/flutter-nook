import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chrome/continue_card.dart';
import '../chrome/difficulty_naming.dart';
import '../chrome/play_clock.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/stars/stars_difficulty.dart';
import '../games/stars/stars_variant.dart';
import '../games/sudoku/difficulty_screen.dart';
import '../games/sudoku/sudoku_naming.dart';
import '../games/sudoku/sudoku_save.dart';
import '../games/sudoku/sudoku_screen.dart';
import '../games/sudoku/sudoku_variant.dart';
import '../l10n/app_localizations.dart';
import '../store/nook_database.dart';
import '../store/saved_game.dart';

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
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// The list, in the player's language.
  ///
  /// Built per locale rather than once at start-up: a row carries the words it
  /// shows, and those words are only known once there is an [AppLocalizations]
  /// to ask.
  static List<_GameEntry> _games(AppLocalizations l10n) => <_GameEntry>[
    _sudoku(l10n, SudokuVariant.classic),
    _sudoku(l10n, SudokuVariant.light),
    _sudoku(l10n, SudokuVariant.mini),
    _GameEntry(
      title: l10n.starsTitle,
      subtitle: l10n.starsSubtitle,
      icon: Icons.star_outline_rounded,
      accent: false,
      open: (BuildContext context) =>
          Navigator.of(context)
              .push(StarsDifficultyPage.route(StarsVariant.standard)),
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
  static _GameEntry _sudoku(AppLocalizations l10n, SudokuVariant variant) {
    return _GameEntry(
      title: variant.title(l10n),
      subtitle: l10n.gameRowSubtitle(
        variant.sizeLabel(l10n),
        variant.blurb(l10n),
      ),
      icon: sudokuIcon(variant),
      accent: true,
      open: (BuildContext context) =>
          Navigator.of(context).push(SudokuDifficultyPage.route(variant)),
    );
  }

  /// The most recent unfinished puzzle this build can open, if there is one.
  ///
  /// Skips a save it cannot read rather than stopping at it: a puzzle written
  /// by a newer build sits harmlessly in the database, and the player is
  /// offered the newest one that does open.
  static SudokuSave? _resumable(List<SavedGame>? saves) {
    for (final SavedGame save in saves ?? const <SavedGame>[]) {
      final SudokuSave? sudoku = SudokuSave.read(save);
      if (sudoku != null) {
        return sudoku;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    // No card at all until the saves have been read: an empty Continue slot
    // that fills in a frame later would flicker on every launch.
    final SudokuSave? resume = _resumable(ref.watch(savedGamesProvider).value);

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
            if (resume != null) ...<Widget>[
              Text(
                l10n.homeContinue,
                style: NookType.sectionLabel(colors.inkFaint),
              ),
              const SizedBox(height: 9),
              _ContinueRow(resume: resume),
              const SizedBox(height: 20),
            ],
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

/// The glyph a Sudoku is drawn with.
///
/// In one place so the Continue card and the game row cannot disagree about
/// which grid the player is looking at.
IconData sudokuIcon(SudokuVariant variant) {
  return switch (variant.id) {
    SudokuVariant.miniId => Icons.window_rounded,
    SudokuVariant.lightId => Icons.grid_view_rounded,
    _ => Icons.grid_on_rounded,
  };
}

/// The puzzle waiting to be carried on with, at the top of the home screen.
class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.resume});

  final SudokuSave resume;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String title = resume.variant.title(l10n);
    final String tier = resume.difficulty.label(l10n);
    final String time = clockReading(resume.elapsed);
    final int percent = (resume.progress * 100).round();

    return ContinueCard(
      icon: sudokuIcon(resume.variant),
      title: title,
      details: l10n.continueDetails(tier, time, percent),
      semanticLabel: l10n.continueLabel(title, tier, time, percent),
      onTap: () =>
          Navigator.of(context).push(SudokuGamePage.resumeRoute(resume)),
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
