import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../l10n/app_localizations.dart';
import '../store/game_stats.dart';
import '../store/nook_database.dart';
import 'difficulty_naming.dart';
import 'play_clock.dart';

/// The screen between picking a game and playing one, shared by every game.
///
/// Its whole job is to let a player say how hard they want to think, and to say
/// plainly what Nook promises about the puzzle they will get. Tiers are never
/// locked: a player who has never opened the app can start on the hardest.
///
/// Game-agnostic on purpose — Sudoku and Stars both go through it. What differs
/// between games is handed in: the [tiers] a grid can produce (a measurement,
/// never a wish — offering a tier a grid cannot make would be five buttons
/// handing back the same puzzle), how a tier is [onStart]ed, an optional
/// [inProgress] card for a game that saves, and an optional [shortLadderNote]
/// for a grid that offers fewer than the whole ladder. The tier words, the
/// best-time figures, the meter and the guarantee are the same everywhere and
/// live here.
class DifficultyPage extends ConsumerWidget {
  const DifficultyPage({
    required this.title,
    required this.gameId,
    required this.tiers,
    required this.onStart,
    this.inProgress,
    this.shortLadderNote,
    super.key,
  });

  /// The game's name, in the header.
  final String title;

  /// The stable game id the statistics are keyed on.
  final String gameId;

  /// The tiers to offer, easiest first.
  final List<PuzzleDifficulty> tiers;

  /// Starts a puzzle at the chosen tier. A game that saves does its
  /// discard-first dance here; one that does not just opens a board.
  final Future<void> Function(
    BuildContext context,
    WidgetRef ref,
    PuzzleDifficulty tier,
  )
  onStart;

  /// The "in progress" section for a game that has an unfinished puzzle, or
  /// `null` — either because the game does not save yet, or because it has
  /// nothing saved. Built lazily so it can watch the saves.
  final Widget? Function(BuildContext context, WidgetRef ref)? inProgress;

  /// The note under the tiers explaining why a grid offers fewer than five, or
  /// `null` for a grid that offers the whole ladder.
  final Widget? shortLadderNote;

  /// How many rungs the meter draws. The five tiers map onto four bars because
  /// the hardest says "needs notes" instead of showing a full meter.
  static const int meterRungs = 4;

  /// The key of the row that starts a [difficulty] game.
  static Key tierKey(PuzzleDifficulty difficulty) =>
      ValueKey<String>('difficulty-${difficulty.name}');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<GameStats> figures =
        ref.watch(gameStatsProvider).value ?? const <GameStats>[];
    final Widget? progress = inProgress?.call(context, ref);

    return Scaffold(
      backgroundColor: colors.sand,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(title: title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
                children: <Widget>[
                  if (progress != null) ...<Widget>[
                    Text(
                      l10n.difficultyInProgress,
                      style: NookType.sectionLabel(colors.inkFaint),
                    ),
                    const SizedBox(height: 10),
                    progress,
                    const SizedBox(height: 20),
                  ],
                  Text(
                    l10n.difficultyStartNew,
                    style: NookType.sectionLabel(colors.inkFaint),
                  ),
                  const SizedBox(height: 10),
                  for (final PuzzleDifficulty tier in tiers) ...<Widget>[
                    _TierRow(
                      difficulty: tier,
                      stats: statsFor(
                        figures,
                        gameId: gameId,
                        difficulty: tier.name,
                      ),
                      onTap: () => onStart(context, ref, tier),
                    ),
                    const SizedBox(height: 9),
                  ],
                  if (shortLadderNote != null) ...<Widget>[
                    const SizedBox(height: 4),
                    shortLadderNote!,
                  ],
                ],
              ),
            ),
            const _Guarantee(),
          ],
        ),
      ),
    );
  }
}

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

/// One difficulty, and the way in.
class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.difficulty,
    required this.stats,
    required this.onTap,
  });

  final PuzzleDifficulty difficulty;

  /// What the player has done here before, or `null` if this is new ground.
  final GameStats? stats;

  final VoidCallback onTap;

  /// The line under the tier's name.
  ///
  /// A tier the player has finished something at talks about them — their best
  /// time and how many they have done. One they have not talks about the puzzle
  /// instead, because "not solved yet" tells nobody anything, and what a player
  /// choosing a tier for the first time wants to know is what it will be like.
  String _line(AppLocalizations l10n) {
    final GameStats? figures = stats;
    if (figures == null || figures.solved == 0) {
      return difficulty.blurb(l10n);
    }
    final Duration? best = figures.bestTime;
    if (best == null) {
      return l10n.difficultyTierSolved(figures.solved);
    }
    return l10n.difficultyTierBest(clockReading(best), figures.solved);
  }

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String name = difficulty.label(l10n);
    final String description = _line(l10n);
    // The designs mark the hardest tier with words rather than a full meter:
    // four filled bars would say "hardest", where what a player needs to know
    // is that this is the tier they will want to write notes for.
    final bool needsNotes = difficulty == PuzzleDifficulty.fiendish;

    return Semantics(
      // Two whole messages rather than one with a bolted-on tail: a language
      // that puts the warning first has nowhere to put it otherwise.
      label: needsNotes
          ? l10n.difficultyTierLabelNeedsNotes(name, description)
          : l10n.difficultyTierLabel(name, description),
      button: true,
      excludeSemantics: true,
      child: Material(
        key: DifficultyPage.tierKey(difficulty),
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(NookRadius.row),
          side: BorderSide(color: colors.line),
        ),
        child: InkWell(
          borderRadius: const BorderRadius.all(NookRadius.row),
          onTap: onTap,
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
                        Text(name, style: NookType.rowTitle(colors.ink)),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: NookType.rowSubtitle(colors.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  if (needsNotes)
                    Text(
                      l10n.difficultyNeedsNotes,
                      style: NookType.actionLabel(colors.inkMuted),
                    )
                  else
                    _DifficultyMeter(difficulty: difficulty),
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

/// The little climbing bars beside a tier.
class _DifficultyMeter extends StatelessWidget {
  const _DifficultyMeter({required this.difficulty});

  final PuzzleDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    // A tier's rung is its place on the whole ladder, not its place in this
    // grid's list — so the top tier still reads as the top of the ladder even
    // when the middle of it is missing.
    final int filled = difficulty.index + 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int rung = 0; rung < DifficultyPage.meterRungs; rung++)
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

/// The promise, stated on the way in rather than buried in a settings screen.
class _Guarantee extends StatelessWidget {
  const _Guarantee();

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 26),
      child: CustomPaint(
        painter: _DashedOutline(color: colors.line, radius: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.sunk,
            borderRadius: const BorderRadius.all(Radius.circular(16)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.add_rounded, size: 18, color: colors.inkMuted),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).difficultyGuarantee,
                  style: NookType.rowSubtitle(colors.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashed edge the designs give the guarantee card.
class _DashedOutline extends CustomPainter {
  const _DashedOutline({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final Path outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final PathMetric metric in outline.computeMetrics()) {
      double start = 0;
      while (start < metric.length) {
        final double end = (start + _dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), stroke);
        start = end + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOutline old) =>
      old.color != color || old.radius != radius;
}
