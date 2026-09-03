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
import '../store/daily_streak.dart';
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
    // The streak is read alongside the saves, and the section waits for both:
    // whether today is already solved and how long the run is are as much a part
    // of the card as which puzzle it is, and a card that filled either in a
    // frame later would flicker on every launch, exactly as the Continue card
    // guards against.
    final DailyStreakStatus? status = ref.watch(dailyStreakProvider).value;
    if (saves == null || status == null) {
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
        _DailyCard(
          daily: daily,
          resume: resume,
          leftover: leftover,
          status: status,
        ),
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
    required this.status,
  });

  /// The key of the card, so a test can point at it.
  static const Key cardKey = ValueKey<String>('daily-card');

  /// The key of the streak figure on the card, so a test can read it.
  static const Key streakKey = ValueKey<String>('daily-streak');

  final DailyPuzzle daily;

  /// Today's puzzle in progress, or `null` when there is nothing to resume.
  final DailyResume? resume;

  /// Whatever the daily slot holds, resumable or not — an unfinished daily
  /// from an earlier date is asked about before it is replaced.
  final SavedGame? leftover;

  /// The daily's streak, and whether today's has already been solved.
  final DailyStreakStatus status;

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
    // Once today's daily is solved there is nothing left to open, so the card
    // stops being a button and simply says so. Solving discards today's save,
    // so this and a resume can never both be true — but the solved state is
    // read first, because it is the more final of the two.
    final bool solved = status.solvedToday;
    final String title = _titleOf(daily.game, l10n);
    final String tier = daily.difficulty.label(l10n);
    final String details;
    final String semanticLabel;
    final IconData trailingIcon;
    final double trailingSize;
    if (solved) {
      details = l10n.dailySolvedDetails(daily.date);
      semanticLabel = l10n.dailyLabelSolved(title, daily.date, status.streak);
      trailingIcon = Icons.check_circle_rounded;
      trailingSize = 20;
    } else if (saved == null) {
      details = l10n.dailyDetails(daily.date, tier);
      semanticLabel = l10n.dailyLabel(title, daily.date, tier, status.streak);
      trailingIcon = Icons.arrow_forward_ios_rounded;
      trailingSize = 15;
    } else {
      final String time = clockReading(saved.elapsed);
      final int percent = (saved.progress * 100).round();
      details = l10n.dailyDetailsProgress(daily.date, time, percent);
      semanticLabel = l10n.dailyLabelProgress(
        title,
        daily.date,
        time,
        percent,
        status.streak,
      );
      trailingIcon = Icons.play_arrow_rounded;
      trailingSize = 20;
    }

    // The whole card is one labelled control (or, once solved, one labelled
    // panel): the game, the day, where the player is with it and the streak read
    // as a single sentence, so a screen reader hears the card once rather than
    // piece by piece. The streak figure it also draws is inside this label, so
    // it is not read out a second time as a bare number.
    //
    // `container: true` forces the label its own node. A button carries actions
    // that keep its node alive on their own, but a solved card is only a label —
    // and a lone label with nothing to do gets folded away without this.
    return Semantics(
      label: semanticLabel,
      button: !solved,
      container: true,
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
          // A solved card is informational: nothing to open, so nothing to tap.
          onTap: solved ? null : () => _open(context, ref, l10n),
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
                const SizedBox(width: 10),
                _StreakChip(streak: status.streak),
                const SizedBox(width: 10),
                Icon(trailingIcon, size: trailingSize, color: colors.clay),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The daily streak on the card: a flame and the number of days.
///
/// Shown in every state — not started, in progress, solved — because the run is
/// a fact about the player, not about today's puzzle. It carries no semantics of
/// its own: the streak is part of the card's one spoken label, and the figure
/// here would only be read out again as a bare digit.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.all(NookRadius.tile),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.local_fire_department_rounded,
            size: 15,
            color: colors.clay,
          ),
          const SizedBox(width: 4),
          Text(
            '$streak',
            key: _DailyCard.streakKey,
            style: NookType.actionLabel(colors.clay),
          ),
        ],
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

/// The key of the streak figure on the daily card, for tests.
const Key dailyStreakKey = _DailyCard.streakKey;
