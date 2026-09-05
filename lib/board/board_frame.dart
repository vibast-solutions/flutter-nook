import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// The shadow a board frame casts, blooming into a warm glow as [glow] runs
/// from 0 to 1.
///
/// Every board — Sudoku, Stars, Duo — casts the same resting shadow, so it
/// lives here rather than being spelled out three times. When a puzzle is
/// solved the board lights up before it gives way to the finished screen: the
/// frame's borders and the shapes inside it gain a soft [NookColors.clay] halo,
/// the one beat of "you did it" the app allows itself on the board before the
/// summary flies in. [glow] is 0 during play, so an unsolved board casts only
/// its resting shadow and nothing changes for the common case.
List<BoxShadow> boardFrameShadows(NookColors colors, {double glow = 0}) {
  return <BoxShadow>[
    BoxShadow(
      color: colors.ink.withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
    if (glow > 0)
      BoxShadow(
        color: colors.clay.withValues(alpha: 0.5 * glow),
        blurRadius: 8 + 30 * glow,
        spreadRadius: 4 * glow,
      ),
  ];
}

/// How long the solved-board glow takes to bloom in.
const Duration kBoardGlowDuration = Duration(milliseconds: 550);

/// Drives a board frame's [boardFrameShadows] from 0 to 1 the moment the puzzle
/// is [solved], and hands the interpolated shadow list to [builder].
///
/// The animating child — the framed grid — is passed through untouched as
/// [child], so only the thin frame rebuilds as the glow blooms rather than the
/// whole board each frame. Under a request for less motion the board is never
/// shown in its solved state (the finished screen takes over at once), so the
/// glow simply never lights: its target stays 0.
class BoardFrameGlow extends StatelessWidget {
  const BoardFrameGlow({
    required this.solved,
    required this.child,
    required this.builder,
    super.key,
  });

  /// Whether the puzzle on this board has just been solved.
  final bool solved;

  /// The framed grid, rebuilt only when it changes rather than every glow frame.
  final Widget child;

  /// Builds the frame around [child] with the interpolated shadow list.
  final Widget Function(
    BuildContext context,
    List<BoxShadow> shadows,
    Widget child,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final bool glowing = solved && !MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: glowing ? 1 : 0),
      duration: kBoardGlowDuration,
      curve: Curves.easeOut,
      child: child,
      builder: (BuildContext context, double glow, Widget? built) =>
          builder(context, boardFrameShadows(colors, glow: glow), built!),
    );
  }
}
