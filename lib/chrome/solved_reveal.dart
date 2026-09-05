import 'package:flutter/material.dart';

/// The little ceremony between finishing a puzzle and the finished screen.
///
/// A solved puzzle still gives the whole screen over to its summary — the board
/// has nothing left to do and the clock has stopped — but rather than cutting
/// there in one frame, this holds on the [playing] board for a beat while it
/// lights up (the board draws its own solved glow), then flies the [completion]
/// summary in from far away: it grows from small to full size and fades in, the
/// "coming towards you" of a modal opening.
///
/// It is shared by every game because the moment is the same for all of them,
/// and it changes nothing a test relies on: the summary it ends on is exactly
/// the widget each screen used to swap to. **Motion is optional** — under a
/// request for less motion there is no hold and no flight, only the finished
/// screen at once, and the board is never shown in its solved state so its glow
/// never lights either.
class SolvedReveal extends StatefulWidget {
  const SolvedReveal({
    required this.solved,
    required this.playing,
    required this.completion,
    super.key,
  });

  /// Whether the puzzle has just been solved.
  final bool solved;

  /// The board and its furniture, shown while playing and held through the glow.
  final Widget playing;

  /// The finished screen the reveal flies in and ends on.
  final Widget completion;

  /// How long the whole ceremony runs, hold and flight together.
  static const Duration duration = Duration(milliseconds: 820);

  /// The point in that run where the hold ends and the summary starts to fly
  /// in, as a fraction — a little over half is the hold, the rest the flight.
  static const double holdEnd = 0.55;

  @override
  State<SolvedReveal> createState() => _SolvedRevealState();
}

class _SolvedRevealState extends State<SolvedReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ceremony = AnimationController(
    vsync: this,
    duration: SolvedReveal.duration,
  );

  /// The flight: 0 to 1 over the tail of the run, eased so the summary settles
  /// rather than snapping to place.
  late final Animation<double> _flight = CurvedAnimation(
    parent: _ceremony,
    curve: const Interval(SolvedReveal.holdEnd, 1, curve: Curves.easeOutCubic),
  );

  /// Set when the widget is built already solved, to start the ceremony once a
  /// [MediaQuery] is in scope to ask about motion.
  bool _armInitial = false;

  @override
  void initState() {
    super.initState();
    _armInitial = widget.solved;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_armInitial) {
      _armInitial = false;
      _startIfMoving();
    }
  }

  @override
  void didUpdateWidget(SolvedReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.solved && !oldWidget.solved) {
      _startIfMoving();
    } else if (!widget.solved && oldWidget.solved) {
      // A fresh puzzle after this one was solved: back to the start, ready to
      // run again when it too is finished.
      _ceremony.reset();
    }
  }

  @override
  void dispose() {
    _ceremony.dispose();
    super.dispose();
  }

  /// Runs the ceremony, unless motion is turned down — then it stays at zero and
  /// [build] shows the finished screen outright.
  void _startIfMoving() {
    if (MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _ceremony.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.solved) {
      return widget.playing;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.completion;
    }
    return AnimatedBuilder(
      animation: _ceremony,
      builder: (BuildContext context, Widget? child) {
        final double t = _ceremony.value;
        // The hold: the solved board sits and glows, its finish sinking in.
        if (t < SolvedReveal.holdEnd) {
          return widget.playing;
        }
        // Landed: the plain finished screen, no transform left over it so every
        // button hit-tests exactly where it looks.
        if (t >= 1) {
          return widget.completion;
        }
        // The flight: the summary grows from far off and fades in as the board
        // it replaces fades out behind it.
        final double r = _flight.value;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (r < 1)
              Opacity(opacity: (1 - r).clamp(0, 1), child: widget.playing),
            Opacity(
              opacity: r.clamp(0, 1),
              child: Transform.scale(
                scale: 0.6 + 0.4 * r,
                child: widget.completion,
              ),
            ),
          ],
        );
      },
    );
  }
}
