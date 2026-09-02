import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../design/tokens.dart';
import '../../design/typography.dart';
import 'sudoku_screen.dart';
import 'sudoku_variant.dart';

/// The screen between picking a Sudoku and playing one.
///
/// Its whole job is to let the player say how hard they want to think, and to
/// say plainly what Nook promises about the puzzle they will get. Tiers are
/// never locked: a player who has never opened the app can start on Fiendish.
///
/// Only the tiers the grid can actually produce are listed, and that list is a
/// measurement rather than a decision — see [SudokuRater.tiersFor]. Offering a
/// tier a 4x4 cannot make would mean five buttons handing back the same puzzle,
/// which is a worse kind of dishonesty than a short list.
class SudokuDifficultyPage extends StatelessWidget {
  const SudokuDifficultyPage({required this.variant, super.key});

  /// The Sudoku whose difficulties are being offered.
  final SudokuVariant variant;

  /// How many rungs the meter draws. The five tiers map onto four bars because
  /// Fiendish says "needs notes" instead of showing a full meter.
  static const int meterRungs = 4;

  /// What each tier feels like to play. Screen copy, so it lives here rather
  /// than on the engine's enum.
  static const Map<SudokuDifficulty, String> _describe =
      <SudokuDifficulty, String>{
        SudokuDifficulty.gentle: 'One cell at a time',
        SudokuDifficulty.easy: 'A little more looking',
        SudokuDifficulty.medium: 'Some ruling out',
        SudokuDifficulty.hard: 'A lot of ruling out',
        SudokuDifficulty.fiendish: 'Chains across the grid',
      };

  /// Builds a route to this page.
  static Route<void> route(SudokuVariant variant) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) => SudokuDifficultyPage(variant: variant),
    );
  }

  /// The key of the row that starts a [difficulty] game.
  static Key tierKey(SudokuDifficulty difficulty) =>
      ValueKey<String>('difficulty-${difficulty.name}');

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final List<SudokuDifficulty> tiers = variant.tiers;

    return Scaffold(
      backgroundColor: colors.sand,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _Header(title: variant.title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 8),
                children: <Widget>[
                  // The designs open with an In-progress card. It arrives with
                  // save and resume (VIB-75); until a saved game can exist,
                  // there is nothing true to put here.
                  Text(
                    'START A NEW ONE',
                    style: NookType.sectionLabel(colors.inkFaint),
                  ),
                  const SizedBox(height: 10),
                  for (final SudokuDifficulty tier in tiers) ...<Widget>[
                    _TierRow(
                      difficulty: tier,
                      description: _describe[tier]!,
                      onTap: () =>
                          Navigator.of(context)
                              .push(SudokuGamePage.route(variant, tier)),
                    ),
                    const SizedBox(height: 9),
                  ],
                  if (tiers.length <
                      SudokuDifficulty.values.length) ...<Widget>[
                    const SizedBox(height: 4),
                    _ShortLadderNote(variant: variant),
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
            label: 'Back to the game list',
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
    required this.description,
    required this.onTap,
  });

  final SudokuDifficulty difficulty;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    // The designs mark Fiendish with words rather than a full meter: four
    // filled bars would say "hardest", where what a player needs to know is
    // that this is the tier they will want to write notes for.
    final bool needsNotes = difficulty == SudokuDifficulty.fiendish;

    return Semantics(
      label:
          '${difficulty.label}. $description'
          '${needsNotes ? '. Needs notes' : ''}',
      button: true,
      excludeSemantics: true,
      child: Material(
        key: SudokuDifficultyPage.tierKey(difficulty),
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
                        Text(
                          difficulty.label,
                          style: NookType.rowTitle(colors.ink),
                        ),
                        const SizedBox(height: 3),
                        // The designs put a best time and a solved count here.
                        // Neither exists until statistics do (VIB-77), and a
                        // row of zeroes would be worse than saying what the
                        // tier is like.
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
                      'needs notes',
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

  final SudokuDifficulty difficulty;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    // A tier's rung is its place on the whole ladder, not its place in this
    // grid's list — so Fiendish on a 6x6 still reads as the top of the ladder
    // even though the middle of it is missing there.
    final int filled = difficulty.index + 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int rung = 0; rung < SudokuDifficultyPage.meterRungs; rung++)
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

/// Why a grid offers fewer than five tiers.
///
/// A player who knows Classic has five and finds three on Light deserves the
/// reason rather than a shrug — and the reason is a property of the grid, not
/// a feature Nook is holding back.
class _ShortLadderNote extends StatelessWidget {
  const _ShortLadderNote({required this.variant});

  final SudokuVariant variant;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final bool single = variant.tiers.length == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        single
            ? 'A ${variant.sizeLabel} grid always leaves a cell you can read '
                  'on its own, so it only comes one way.'
            : 'A ${variant.sizeLabel} grid is too small for the middle of the '
                  'ladder — it either falls out or it needs a chain.',
        style: NookType.footnote(colors.inkGhost),
      ),
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
                  'Every puzzle has exactly one solution — you will never '
                  'need to guess.',
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
///
/// Dashes rather than a solid rule because this is the one card on the screen
/// that is not a control, and the border is what says so before the words do.
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
