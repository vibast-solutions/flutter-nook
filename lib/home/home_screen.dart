import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../chrome/continue_card.dart';
import '../chrome/difficulty_naming.dart';
import '../chrome/play_clock.dart';
import '../chrome/resume.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/duo/duo_screen.dart';
import '../games/duo/duo_variant.dart';
import '../games/stars/stars_difficulty.dart';
import '../games/stars/stars_naming.dart';
import '../games/stars/stars_save.dart';
import '../games/stars/stars_screen.dart';
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
      icon: starsIcon,
      accent: false,
      open: (BuildContext context) =>
          Navigator.of(context)
              .push(StarsDifficultyPage.route(StarsVariant.standard)),
    ),
    _GameEntry(
      title: l10n.duoTitle,
      subtitle: l10n.duoSubtitle,
      icon: duoIcon,
      accent: false,
      open: (BuildContext context) => Navigator.of(
        context,
      ).push(DuoGamePage.route(DuoVariant.standard, PuzzleDifficulty.gentle)),
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

  /// How each game turns a saved row into a resume card, tried in turn.
  ///
  /// The whole of what makes the Continue card game-agnostic: a new game is a
  /// reader added here, not a branch grown in [build]. Order does not matter —
  /// a row belongs to at most one game — so this is a list, not a chain.
  static const List<ResumeReader> _resumeReaders = <ResumeReader>[
    _sudokuResume,
    _starsResume,
  ];

  /// A saved Sudoku as a resume card, or `null` if the row is not a Sudoku this
  /// build can open.
  static ResumableGame? _sudokuResume(SavedGame save, AppLocalizations l10n) {
    final SudokuSave? sudoku = SudokuSave.read(save);
    if (sudoku == null) {
      return null;
    }
    final String title = sudoku.variant.title(l10n);
    final String tier = sudoku.difficulty.label(l10n);
    final String time = clockReading(sudoku.elapsed);
    final int percent = (sudoku.progress * 100).round();
    return ResumableGame(
      icon: sudokuIcon(sudoku.variant),
      title: title,
      details: l10n.continueDetails(tier, time, percent),
      semanticLabel: l10n.continueLabel(title, tier, time, percent),
      openRoute: () => SudokuGamePage.resumeRoute(sudoku),
    );
  }

  /// A saved Stars puzzle as a resume card, or `null` if the row is not one this
  /// build can open.
  static ResumableGame? _starsResume(SavedGame save, AppLocalizations l10n) {
    final StarsSave? stars = StarsSave.read(save);
    if (stars == null) {
      return null;
    }
    final String title = stars.variant.title(l10n);
    final String tier = stars.difficulty.label(l10n);
    final String time = clockReading(stars.elapsed);
    final int percent = (stars.progress * 100).round();
    return ResumableGame(
      icon: starsIcon,
      title: title,
      details: l10n.continueDetails(tier, time, percent),
      semanticLabel: l10n.continueLabel(title, tier, time, percent),
      openRoute: () => StarsGamePage.resumeRoute(stars),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    // No card at all until the saves have been read: an empty Continue slot
    // that fills in a frame later would flicker on every launch.
    final ResumableGame? resume = mostRecentResumable(
      ref.watch(savedGamesProvider).value,
      l10n,
      _resumeReaders,
    );

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

/// The glyph Stars is drawn with, on its game row and its Continue card alike.
///
/// A constant, not a function of the variant: there is one Stars board, and the
/// card and the row must never disagree about which game the player is looking
/// at.
const IconData starsIcon = Icons.star_outline_rounded;

/// The glyph Duo is drawn with, on its game row.
///
/// A constant, not a function of the variant: there is one Duo board, and the
/// row must always show the same game the player is looking at.
const IconData duoIcon = Icons.contrast_rounded;

/// The puzzle waiting to be carried on with, at the top of the home screen.
///
/// Game-agnostic: it is handed a [ResumableGame] a reader has already resolved,
/// so it draws the same card whether the puzzle is a Sudoku or Stars.
class _ContinueRow extends StatelessWidget {
  const _ContinueRow({required this.resume});

  final ResumableGame resume;

  @override
  Widget build(BuildContext context) {
    return ContinueCard(
      icon: resume.icon,
      title: resume.title,
      details: resume.details,
      semanticLabel: resume.semanticLabel,
      onTap: () => Navigator.of(context).push(resume.openRoute()),
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
