import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/play_clock.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../store/game_stats.dart';
import 'solve_outcome.dart';
import 'sudoku_controller.dart';
import 'sudoku_naming.dart';
import 'sudoku_variant.dart';

/// What a player sees when they finish a puzzle.
///
/// **Nothing is asked of them here.** No rating prompt, no tip, no "enjoying
/// Nook?", no anything: this is the most positive moment the app has, and
/// spending it on a request would be spending the one piece of goodwill Nook
/// earns. The screen says what they did, offers another puzzle, and gets out
/// of the way. That is not an oversight to be filled in later — it is the
/// feature.
///
/// The figures are the player's own and nobody else's. There is no
/// leaderboard, no percentile and no comparison with other people anywhere in
/// Nook, so the only thing a time is measured against is the same player's
/// last one.
class SudokuCompletionView extends ConsumerWidget {
  const SudokuCompletionView({super.key});

  /// The card showing how long this puzzle took.
  static const Key timeKey = ValueKey<String>('completion-time');

  /// The card showing the time the player had to beat.
  static const Key previousKey = ValueKey<String>('completion-previous');

  /// The card counting the puzzles finished here.
  static const Key solvedKey = ValueKey<String>('completion-solved');

  /// The badge shown only for a time nobody has beaten.
  static const Key personalBestKey = ValueKey<String>(
    'completion-personal-best',
  );

  /// The button that starts another puzzle at the same difficulty.
  static const Key anotherKey = ValueKey<String>('completion-another');

  /// The button that goes back to the game list.
  static const Key homeKey = ValueKey<String>('completion-home');

  /// The button that goes back to this game's difficulties.
  static const Key closeKey = ValueKey<String>('completion-close');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SudokuVariant variant = ref.watch(sudokuVariantProvider);
    final SudokuDifficulty difficulty = ref.watch(sudokuDifficultyProvider);
    final SolveOutcome? outcome = ref.watch(solveOutcomeProvider);
    // The time is on the clock the moment the last digit lands; the figures
    // beside it come from the database and arrive a beat later. Reading the
    // clock rather than waiting means the number the player cares about is
    // never the one that is missing.
    final Duration time = outcome?.time ?? ref.watch(playClockProvider);
    final String tier = difficulty.label(l10n);

    return SafeArea(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[_CloseButton(label: l10n.completionClose)],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                children: <Widget>[
                  const _Medallion(),
                  const SizedBox(height: 20),
                  Semantics(
                    liveRegion: true,
                    container: true,
                    child: Column(
                      children: <Widget>[
                        Text(
                          l10n.gameSolved,
                          style: NookType.celebration(colors.ink),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          l10n.completionSubtitle(variant.title(l10n), tier),
                          style: NookType.rowSubtitle(colors.inkMuted),
                        ),
                        if (outcome?.isPersonalBest ?? false) ...<Widget>[
                          const SizedBox(height: 14),
                          const _PersonalBestChip(),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  _Figures(time: time, outcome: outcome),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
            child: Column(
              children: <Widget>[
                _WideButton(
                  buttonKey: SudokuCompletionView.anotherKey,
                  label: l10n.completionAnother(tier),
                  onTap: () => ref
                      .read(sudokuControllerProvider.notifier)
                      .startNewPuzzle(),
                  primary: true,
                ),
                const SizedBox(height: 11),
                _WideButton(
                  buttonKey: SudokuCompletionView.homeKey,
                  label: l10n.completionBackHome,
                  // All the way out rather than one step back: "Back to Nook"
                  // means the game list, and a player who has finished is done
                  // with this game's difficulties as well as with the puzzle.
                  onTap: () =>
                      Navigator.of(context)
                          .popUntil((Route<void> route) => route.isFirst),
                  primary: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The three numbers, side by side.
class _Figures extends StatelessWidget {
  const _Figures({required this.time, required this.outcome});

  final Duration time;
  final SolveOutcome? outcome;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final Duration? previous = outcome?.previousBest;
    final int solved = outcome?.solved ?? 0;
    final String reading = clockReading(time);
    final String noTime = l10n.completionNoTime;

    // The three cards are as tall as the tallest of them, so a wrapped
    // heading in one does not leave the other two short.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _StatCard(
              cardKey: SudokuCompletionView.timeKey,
              heading: l10n.completionTime,
              value: reading,
              label: l10n.completionTimeLabel(reading),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: _StatCard(
              cardKey: SudokuCompletionView.previousKey,
              heading: l10n.completionPrevious,
              // A tier with no best time yet says so with a dash. A zero would
              // read as a time nobody could beat.
              value: previous == null ? noTime : clockReading(previous),
              label: previous == null
                  ? l10n.completionNoPreviousLabel
                  : l10n.completionPreviousLabel(clockReading(previous)),
              quiet: true,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: _StatCard(
              cardKey: SudokuCompletionView.solvedKey,
              // The designs put the daily streak here. There is no daily puzzle
              // yet (VIB-67) and so no streak, and a made-up number in the one
              // place the app is telling the player about themselves would be
              // the worst possible place to make one up. The count is true.
              heading: l10n.completionSolvedCount,
              value: '$solved',
              label: l10n.completionSolvedLabel(solved),
            ),
          ),
        ],
      ),
    );
  }
}

/// One figure, in its own card.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.cardKey,
    required this.heading,
    required this.value,
    required this.label,
    this.quiet = false,
  });

  final Key cardKey;
  final String heading;
  final String value;

  /// What a screen reader hears instead of the heading and the figure, which
  /// are two fragments of one sentence rather than two things to read out.
  final String label;

  /// Whether this is a number the player has already beaten, and so sits back
  /// from the two that are about now.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        key: cardKey,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.line),
          borderRadius: const BorderRadius.all(NookRadius.card),
        ),
        child: Column(
          children: <Widget>[
            Text(
              heading,
              textAlign: TextAlign.center,
              style: NookType.sectionLabel(colors.inkFaint),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              style: NookType.statValue(quiet ? colors.inkMuted : colors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// The badge for a time the player has never beaten before.
class _PersonalBestChip extends StatelessWidget {
  const _PersonalBestChip();

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Container(
      key: SudokuCompletionView.personalBestKey,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: colors.sageSoft,
        border: Border.all(color: colors.sageLine),
        borderRadius: const BorderRadius.all(NookRadius.tile),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.check_rounded, size: 15, color: colors.sage),
          const SizedBox(width: 7),
          Text(
            AppLocalizations.of(context).completionPersonalBest,
            style: NookType.actionLabel(colors.sageInk),
          ),
        ],
      ),
    );
  }
}

/// The star at the top of the screen.
class _Medallion extends StatelessWidget {
  const _Medallion();

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Container(
      width: 118,
      height: 118,
      decoration: BoxDecoration(
        color: colors.claySoft,
        shape: BoxShape.circle,
        border: Border.all(color: colors.clayLine, width: 2),
      ),
      child: Icon(Icons.star_rounded, size: 62, color: colors.clay),
    );
  }
}

/// A full-width button, primary or not.
class _WideButton extends StatelessWidget {
  const _WideButton({
    required this.buttonKey,
    required this.label,
    required this.onTap,
    required this.primary,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Material(
      key: buttonKey,
      color: primary ? colors.clay : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(NookRadius.card),
        side: primary ? BorderSide.none : BorderSide(color: colors.line),
      ),
      child: InkWell(
        borderRadius: const BorderRadius.all(NookRadius.card),
        onTap: onTap,
        child: Container(
          height: 58,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: NookType.buttonLabel(
              primary ? colors.surface : colors.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// The way out that is not a decision.
///
/// Goes back one step, to the difficulties for this game, so a player who
/// wants another puzzle at a different tier does not have to go home for it.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: Material(
        key: SudokuCompletionView.closeKey,
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
            child: Icon(Icons.close_rounded, size: 18, color: colors.inkMuted),
          ),
        ),
      ),
    );
  }
}
