import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chrome/difficulty_naming.dart';
import '../chrome/discard_dialog.dart';
import '../chrome/play_clock.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../games/sudoku/sudoku_variant.dart';
import '../home/home_screen.dart';
import '../l10n/app_localizations.dart';
import '../store/nook_database.dart';
import '../store/saved_game.dart';
import 'daily_launch.dart';
import 'daily_puzzle.dart';

/// The "today's puzzle" section of the home screen: its heading and its card.
///
/// There is always a today, so the section is always shown once the saves have
/// been read — before that it shows nothing at all, for the same reason the
/// Continue card does not: a card that changed state a frame after appearing
/// would flicker on every launch.
class DailySection extends ConsumerWidget {
  const DailySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<SavedGame>? saves = ref.watch(savedGamesProvider).value;
    if (saves == null) {
      return const SizedBox.shrink();
    }
    // Read at build and captured by the tap: the puzzle a player opens is
    // pinned, and a card sitting on screen across midnight opens the day it
    // was built for rather than swapping under the tap.
    final DailyPuzzle daily = dailyPuzzleFor(ref.watch(nowProvider)());
    SavedGame? leftover;
    for (final SavedGame save in saves) {
      if (save.gameId == dailySlotId) {
        leftover = save;
        break;
      }
    }
    final DailyResume? resume = leftover == null
        ? null
        : dailyResume(ref, daily, leftover);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(l10n.homeDaily, style: NookType.sectionLabel(colors.inkFaint)),
        const SizedBox(height: 9),
        _DailyCard(daily: daily, resume: resume, leftover: leftover),
        const SizedBox(height: 20),
      ],
    );
  }
}

/// The card itself: today's game, today's date, and where the player is with
/// it.
class _DailyCard extends ConsumerWidget {
  const _DailyCard({
    required this.daily,
    required this.resume,
    required this.leftover,
  });

  /// The key of the card, so a test can point at it.
  static const Key cardKey = ValueKey<String>('daily-card');

  final DailyPuzzle daily;

  /// Today's puzzle in progress, or `null` when there is nothing to resume.
  final DailyResume? resume;

  /// Whatever the daily slot holds, resumable or not — an unfinished daily
  /// from an earlier date is asked about before it is replaced.
  final SavedGame? leftover;

  /// Opens today's puzzle: resumes it, or starts it — asking first when
  /// starting means throwing an earlier day's unfinished daily away.
  ///
  /// The same discard-first dance as the difficulty screens, and for the same
  /// reason: the player said to throw the old puzzle away, so it is deleted
  /// rather than left to be overwritten. A leftover nobody can name — a seed
  /// that is not a date, a payload this build cannot read — is replaced
  /// without a question, because a resume it stands for could never be
  /// honoured anyway.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final NavigatorState navigator = Navigator.of(context);
    final DailyResume? saved = resume;
    if (saved != null) {
      await navigator.push(saved.route());
      return;
    }
    final SavedGame? old = leftover;
    if (old != null) {
      final DailyPuzzle? named = dailyPuzzleForSeed(old.seed);
      if (named != null && named.seed != daily.seed) {
        final bool discard = await DiscardDialog.ask(
          context,
          gameName: _titleOf(named.game, l10n),
        );
        if (!discard) {
          return;
        }
      }
      await ref.read(savedGameStoreProvider).discard(dailySlotId);
    }
    await navigator.push(dailyStartRoute(ref, daily));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DailyResume? saved = resume;
    final String title = _titleOf(daily.game, l10n);
    final String tier = daily.difficulty.label(l10n);
    final String details;
    final String semanticLabel;
    if (saved == null) {
      details = l10n.dailyDetails(daily.date, tier);
      semanticLabel = l10n.dailyLabel(title, daily.date, tier);
    } else {
      final String time = clockReading(saved.elapsed);
      final int percent = (saved.progress * 100).round();
      details = l10n.dailyDetailsProgress(daily.date, time, percent);
      semanticLabel = l10n.dailyLabelProgress(title, daily.date, time, percent);
    }

    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: Material(
        key: cardKey,
        color: colors.claySoft,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(NookRadius.row),
          side: BorderSide(color: colors.clayLine),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.all(NookRadius.row),
          onTap: () => _open(context, ref, l10n),
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
                  child: Icon(
                    _iconOf(daily.game),
                    size: 20,
                    color: colors.clay,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: NookType.rowTitle(colors.ink)),
                      const SizedBox(height: 1),
                      Text(
                        details,
                        style: NookType.rowSubtitle(colors.inkMuted),
                      ),
                    ],
                  ),
                ),
                Icon(
                  saved == null
                      ? Icons.arrow_forward_ios_rounded
                      : Icons.play_arrow_rounded,
                  size: saved == null ? 15 : 20,
                  color: colors.clay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The daily game's name, from the same messages its own screens use.
String _titleOf(DailyGame game, AppLocalizations l10n) => switch (game) {
  DailyGame.sudokuClassic => l10n.sudokuClassicTitle,
  DailyGame.stars => l10n.starsTitle,
  DailyGame.duo => l10n.duoTitle,
};

/// The daily game's glyph — the same constants the game rows are drawn with,
/// so the card and the row can never disagree about which game today is.
IconData _iconOf(DailyGame game) => switch (game) {
  DailyGame.sudokuClassic => sudokuIcon(SudokuVariant.classic),
  DailyGame.stars => starsIcon,
  DailyGame.duo => duoIcon,
};

/// The key of the daily card, for tests: private widgets keep their keys
/// reachable through the section.
const Key dailyCardKey = _DailyCard.cardKey;
