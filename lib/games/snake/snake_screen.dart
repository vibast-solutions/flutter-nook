import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../board/snake_board.dart';
import '../../chrome/how_to_play.dart';
import '../../design/tokens.dart';
import '../../design/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../store/nook_database.dart';
import '../../store/snake_score.dart';
import 'snake_naming.dart';
import 'snake_rules.dart';
import 'snake_variant.dart';

/// The screen a player lands on after choosing a Snake speed.
///
/// Unlike the puzzle games, Snake keeps no clock, no difficulty and no save, so
/// it opens none of the `GameSession`/`ProviderScope` machinery they do: it is a
/// self-contained arcade run that lives entirely in [_SnakeScreen]'s state. The
/// one thing chosen before it opens is the [speed], which sets the constant pace
/// of the loop (VIB-109).
class SnakeGamePage extends StatelessWidget {
  const SnakeGamePage({
    required this.variant,
    required this.speed,
    this.seed,
    super.key,
  });

  /// Which Snake board to play.
  final SnakeVariant variant;

  /// The pace the run is played at, chosen on the speed picker. Its
  /// `SnakeSpeed.tick` is the interval between the snake's steps.
  final SnakeSpeed speed;

  /// The seed the run starts from, or `null` to take a fresh one from the clock
  /// on each start. A test passes a seed so a run is reproducible.
  final int? seed;

  /// Builds a route to a new run at [speed].
  static Route<void> route(
    SnakeVariant variant, {
    required SnakeSpeed speed,
    int? seed,
  }) {
    return MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          SnakeGamePage(variant: variant, speed: speed, seed: seed),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SnakeScreen(variant: variant, speed: speed, seed: seed);
  }
}

class _SnakeScreen extends ConsumerStatefulWidget {
  const _SnakeScreen({required this.variant, required this.speed, this.seed});

  final SnakeVariant variant;
  final SnakeSpeed speed;
  final int? seed;

  @override
  ConsumerState<_SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends ConsumerState<_SnakeScreen>
    with WidgetsBindingObserver {
  /// The current frame. Built lazily on the first start, so before then the
  /// board shows a still snake behind the "tap to start" invitation.
  late SnakeGame _game = SnakeGame.start(
    widget.variant.spec,
    seed: widget.seed ?? _clockSeed(),
  );

  /// The loop. `null` while the game is waiting to start or is over — the timer
  /// exists only while the snake is actually moving. Cancelled in [dispose], so
  /// it never outlives the screen.
  Timer? _ticker;

  /// Whether the player has started the run. Before this the snake is drawn but
  /// still; after it the loop is running or the game is over.
  bool _started = false;

  /// What the finished run did to the best score at this speed, or `null` while a
  /// run is in play or its score has not been recorded yet. Set once, just after
  /// the snake dies, by the write that stores the score — so the game-over card
  /// can name the best as it was the moment before this run.
  SnakeScoreOutcome? _outcome;

  /// Whether the run is paused: the loop is stopped and the paused panel is up,
  /// waiting for the player to resume. A run is paused by the pause control or by
  /// the app leaving the foreground; either way the snake cannot die while it is.
  bool _paused = false;

  /// The number showing on the resume countdown, or `null` when no countdown is
  /// running. While it is counting the loop is stopped, so a returning player is
  /// never dropped straight back into a moving snake.
  int? _countdown;

  /// The countdown's own timer, separate from the game loop and cancelled with
  /// it. Ticks the [_countdown] down a second at a time until play resumes.
  Timer? _countdownTimer;

  /// Whether the app was sent to the background mid-run. Set when the loop is
  /// stopped by [didChangeAppLifecycleState] so that returning knows to resume
  /// with a countdown — a run the player paused by hand stays paused instead,
  /// because that pause was a choice, not an interruption.
  bool _interrupted = false;

  /// How many seconds the resume countdown starts from.
  static const int _countdownFrom = 3;

  /// Turns the player has asked for but that have not been taken yet.
  ///
  /// At most two are held, and each tick takes the first one that is a legal
  /// turn from the snake's *current* heading. Queuing rather than turning at
  /// once is what stops two quick inputs inside a single tick — up then left
  /// while heading right — from folding the snake straight back onto its neck:
  /// the up is taken this tick, the left only on the next, by which point it is
  /// an ordinary turn.
  final List<SnakeDirection> _inputs = <SnakeDirection>[];

  final FocusNode _focus = FocusNode();

  /// Where a swipe began, and how far it has travelled, so its dominant axis can
  /// be read when it ends.
  Offset _dragged = Offset.zero;

  int _clockSeed() => DateTime.now().microsecondsSinceEpoch & 0xFFFFFFFF;

  @override
  void initState() {
    super.initState();
    // Watch the app's lifecycle so a run can be stopped the moment it leaves the
    // foreground — the same thing PlayClock does for the timed games.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _countdownTimer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Back in the foreground: a run interrupted by backgrounding resumes with a
      // countdown; a run the player paused by hand is left as they left it.
      if (_interrupted) {
        _interrupted = false;
        _beginResume();
      }
      return;
    }
    // Leaving the foreground stops a live run so the snake cannot die while the
    // player is away, and remembers to pick it back up on return.
    _interruptForBackground();
  }

  /// Starts, or restarts, a run: a fresh snake and a running loop.
  void _start() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _game = SnakeGame.start(
        widget.variant.spec,
        seed: widget.seed ?? _clockSeed(),
      );
      _started = true;
      _outcome = null;
      _paused = false;
      _countdown = null;
      _interrupted = false;
      _inputs.clear();
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(widget.speed.tick, _onTick);
    _focus.requestFocus();
  }

  /// Whether the run is live: started, not over, and neither paused nor mid
  /// resume countdown. This is the only state a pause control belongs in and the
  /// only one steering is taken in.
  bool get _isPlaying =>
      _started && !_game.isDead && !_paused && _countdown == null;

  /// Pauses a live run: the loop stops and the paused panel comes up. Harmless if
  /// there is nothing to pause.
  void _pause() {
    if (!_isPlaying) {
      return;
    }
    _ticker?.cancel();
    _ticker = null;
    setState(() => _paused = true);
  }

  /// Stops a live or counting-down run because the app is leaving the foreground,
  /// remembering to resume it when the app comes back. A run already paused by
  /// hand, or not in play, is left untouched.
  void _interruptForBackground() {
    final bool active =
        _started && !_game.isDead && (_ticker != null || _countdown != null);
    if (!active) {
      return;
    }
    _ticker?.cancel();
    _ticker = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _interrupted = true;
    setState(() {
      _paused = true;
      _countdown = null;
    });
  }

  /// Begins the resume countdown: the paused panel gives way to a number counting
  /// down, and the loop starts again only when it reaches zero.
  void _beginResume() {
    if (!_started || _game.isDead) {
      return;
    }
    _ticker?.cancel();
    _ticker = null;
    _countdownTimer?.cancel();
    setState(() {
      _paused = false;
      _countdown = _countdownFrom;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer _) {
      final int next = (_countdown ?? 1) - 1;
      if (next > 0) {
        setState(() => _countdown = next);
        return;
      }
      _countdownTimer?.cancel();
      _countdownTimer = null;
      setState(() => _countdown = null);
      _ticker = Timer.periodic(widget.speed.tick, _onTick);
      _focus.requestFocus();
    });
  }

  void _onTick(Timer _) {
    // Take the first queued turn that is not a straight reversal of the way the
    // snake is going now; leading reversals and repeats are dropped.
    SnakeDirection heading = _game.direction;
    while (_inputs.isNotEmpty) {
      final SnakeDirection candidate = _inputs.removeAt(0);
      if (!candidate.isReverseOf(_game.direction)) {
        heading = candidate;
        break;
      }
    }

    setState(() => _game = _game.step(heading));
    if (_game.isDead) {
      _ticker?.cancel();
      _ticker = null;
      _recordScore(_game.score);
    }
  }

  /// Stores the finished run's score against its speed, and — if it beat the best
  /// kept there — says so in words and a haptic.
  ///
  /// A new best is announced by both, never by colour or motion alone (the
  /// board's doctrine): the game-over card grows a "New best!" line, and the
  /// phone gives a single medium tap. The record is one transaction that hands
  /// back what the run beat, which is the only moment the previous best is still
  /// known.
  Future<void> _recordScore(int score) async {
    final SnakeScoreOutcome outcome = await ref
        .read(snakeScoreStoreProvider)
        .record(level: widget.speed.level, score: score, at: DateTime.now());
    if (!mounted) {
      return;
    }
    if (outcome.isNewBest) {
      HapticFeedback.mediumImpact();
    }
    setState(() => _outcome = outcome);
  }

  /// Records a direction the player asked for, to be taken on a coming tick.
  void _steer(SnakeDirection direction) {
    if (!_isPlaying) {
      return;
    }
    // Keep the queue short and free of immediate repeats, so a mash of the same
    // key cannot crowd out a real turn behind it.
    if (_inputs.length >= 2 ||
        (_inputs.isNotEmpty && _inputs.last == direction)) {
      return;
    }
    _inputs.add(direction);
  }

  /// Handles a press of the on-screen d-pad, the gesture-free way to steer. It
  /// mirrors the keyboard: a press before the run has begun starts it, and every
  /// press after that is a turn — so Snake is playable by tapping alone, with no
  /// swipe (VIB-112).
  void _onDpad(SnakeDirection direction) {
    if (!_started) {
      _start();
      return;
    }
    _steer(direction);
  }

  /// What a screen reader should be told about the board right now, or `null`
  /// before the run has begun.
  ///
  /// The Snake field is one live region rather than a per-cell tree (the board
  /// rule this story documents as its intentional exception): the meaningful
  /// events are spoken in words instead. While the snake is alive that is the
  /// score and its length, which change together on each piece of food eaten; the
  /// moment it dies it is the final score. A run in play but paused keeps its
  /// last sentence — the score is not changing — so nothing is re-announced while
  /// the player is away.
  String? _spokenState(AppLocalizations l10n) {
    if (!_started) {
      return null;
    }
    if (_game.isDead) {
      return l10n.snakeGameOverAnnouncement(_game.score);
    }
    return l10n.snakeProgressAnnouncement(_game.score, _game.length);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final SnakeDirection? direction = _directionForKey(event.logicalKey);
    if (direction == null) {
      return KeyEventResult.ignored;
    }
    if (!_started) {
      _start();
      return KeyEventResult.handled;
    }
    _steer(direction);
    return KeyEventResult.handled;
  }

  SnakeDirection? _directionForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
      return SnakeDirection.up;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      return SnakeDirection.down;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      return SnakeDirection.left;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      return SnakeDirection.right;
    }
    return null;
  }

  void _onPanStart(DragStartDetails _) => _dragged = Offset.zero;

  void _onPanUpdate(DragUpdateDetails details) {
    _dragged += details.delta;
  }

  void _onPanEnd(DragEndDetails _) {
    const double threshold = 12;
    final Offset delta = _dragged;
    if (delta.distance < threshold) {
      return;
    }
    final SnakeDirection direction = delta.dx.abs() > delta.dy.abs()
        ? (delta.dx > 0 ? SnakeDirection.right : SnakeDirection.left)
        : (delta.dy > 0 ? SnakeDirection.down : SnakeDirection.up);
    _steer(direction);
  }

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SnakeVariant variant = widget.variant;

    return Scaffold(
      backgroundColor: colors.sand,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // The board's spoken commentary — the field as one live region, the
            // board rule's documented exception — sits above everything so it is
            // stable across the whole run.
            _SpokenBoardState(label: _spokenState(l10n)),
            _SnakeHeader(
              title: variant.title(l10n),
              subtitle: _started
                  ? l10n.snakeScore(_game.score)
                  : variant.subtitle(l10n),
              onHowToPlay: () =>
                  showHowToPlay(context, content: snakeRules(l10n, variant)),
              onPause: _isPlaying ? _pause : null,
            ),
            Expanded(
              child: Focus(
                focusNode: _focus,
                autofocus: true,
                onKeyEvent: _onKey,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _started ? null : _start,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: _BoardArea(
                      game: _game,
                      started: _started,
                      paused: _paused,
                      countdown: _countdown,
                      outcome: _outcome,
                      onStart: _start,
                      onRestart: _start,
                      onResume: _beginResume,
                    ),
                  ),
                ),
              ),
            ),
            // The gesture-free way to steer, so the game is playable without a
            // swipe. Swiping and the keyboard still work; this is the addition.
            _SnakeDpad(
              onDirection: _onDpad,
              reduceMotion: MediaQuery.disableAnimationsOf(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// The board, sized to fit the space it is given, with the start invitation or
/// the game-over card laid over it when the run is not in play.
class _BoardArea extends StatelessWidget {
  const _BoardArea({
    required this.game,
    required this.started,
    required this.paused,
    required this.countdown,
    required this.outcome,
    required this.onStart,
    required this.onRestart,
    required this.onResume,
  });

  final SnakeGame game;
  final bool started;

  /// Whether the run is paused, so the paused panel is shown over a still board.
  final bool paused;

  /// The resume countdown's current number, or `null` when no countdown is up.
  final int? countdown;

  /// What the finished run did to the best score, or `null` if the run is still
  /// in play or the score has not landed yet.
  final SnakeScoreOutcome? outcome;

  final VoidCallback onStart;
  final VoidCallback onRestart;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final SnakeSpec spec = game.spec;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // The board keeps the spec's aspect ratio: take the full width unless
        // that would make it taller than the space, in which case the height
        // decides instead.
        final double byWidth = constraints.maxWidth;
        final double byHeight = constraints.maxHeight * spec.cols / spec.rows;
        final double width = byWidth < byHeight ? byWidth : byHeight;

        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              SnakeBoard(game: game, width: width),
              if (!started)
                _StartOverlay(onStart: onStart)
              else if (game.isDead)
                _GameOverCard(
                  score: game.score,
                  outcome: outcome,
                  onRestart: onRestart,
                )
              else if (countdown != null)
                _ResumeCountdown(count: countdown!)
              else if (paused)
                _PausedPanel(onResume: onResume),
            ],
          ),
        );
      },
    );
  }
}

/// The invitation shown over a still board before the first move.
class _StartOverlay extends StatelessWidget {
  const _StartOverlay({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return _Panel(
      children: <Widget>[
        Text(l10n.snakeStartCta, style: NookType.title(colors.ink)),
        const SizedBox(height: 6),
        Text(
          l10n.snakeStartHint,
          textAlign: TextAlign.center,
          style: NookType.rowSubtitle(colors.inkMuted),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(label: l10n.snakeStartCta, onTap: onStart),
      ],
    );
  }
}

/// The card shown when the snake has died: how far it got, and a way to go
/// again.
class _GameOverCard extends StatelessWidget {
  const _GameOverCard({
    required this.score,
    required this.outcome,
    required this.onRestart,
  });

  /// The key of the game-over card, so a test can find it without its words.
  static const Key cardKey = ValueKey<String>('snake-game-over');

  final int score;

  /// What this run did to the best score, or `null` until the score is stored —
  /// the card shows the run's own score at once and grows its best line the
  /// instant the record write returns.
  final SnakeScoreOutcome? outcome;

  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SnakeScoreOutcome? result = outcome;
    return _Panel(
      key: cardKey,
      children: <Widget>[
        Text(l10n.snakeGameOver, style: NookType.celebration(colors.ink)),
        const SizedBox(height: 6),
        Text(l10n.snakeScore(score), style: NookType.statValue(colors.clay)),
        // The best line, once the score is in: a new best is named in words —
        // the run's score already shows the number — and a run that fell short
        // shows the best it was chasing.
        if (result != null) ...<Widget>[
          const SizedBox(height: 4),
          if (result.isNewBest)
            Text(l10n.snakeNewBest, style: NookType.rowTitle(colors.ink))
          else
            Text(
              l10n.snakeBest(result.best),
              style: NookType.rowSubtitle(colors.inkMuted),
            ),
        ],
        const SizedBox(height: 16),
        _PrimaryButton(label: l10n.snakeRestart, onTap: onRestart),
      ],
    );
  }
}

/// The panel shown over a still board while a run is paused: a way to pick it
/// back up. Resuming runs a short countdown, so the button does not drop the
/// player straight back into motion.
class _PausedPanel extends StatelessWidget {
  const _PausedPanel({required this.onResume});

  /// The key of the paused panel, so a test can find it without its words.
  static const Key panelKey = ValueKey<String>('snake-paused');

  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return _Panel(
      key: panelKey,
      children: <Widget>[
        Text(l10n.snakePaused, style: NookType.title(colors.ink)),
        const SizedBox(height: 16),
        _PrimaryButton(label: l10n.snakeResume, onTap: onResume),
      ],
    );
  }
}

/// The resume countdown: a number ticking down to the run starting again.
///
/// The number changing is the message and is always shown; the little pop it
/// makes as it changes is decoration, so it is dropped when the player has asked
/// for reduced motion — the count still counts, it just does not bounce.
class _ResumeCountdown extends StatelessWidget {
  const _ResumeCountdown({required this.count});

  /// The key of the countdown panel, so a test can find it without its words.
  static const Key countdownKey = ValueKey<String>('snake-countdown');

  final int count;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);
    final Widget number = Text(
      '$count',
      key: ValueKey<int>(count),
      style: NookType.celebration(colors.clay),
    );
    return Semantics(
      liveRegion: true,
      label: l10n.snakeResumeCountdown(count),
      excludeSemantics: true,
      child: _Panel(
        key: countdownKey,
        children: <Widget>[
          if (reduceMotion)
            number
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (Widget child, Animation<double> anim) =>
                  ScaleTransition(
                    scale: anim,
                    child: FadeTransition(opacity: anim, child: child),
                  ),
              child: number,
            ),
        ],
      ),
    );
  }
}

/// The soft card both overlays sit in.
class _Panel extends StatelessWidget {
  const _Panel({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(NookRadius.card),
        side: BorderSide(color: colors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

/// The header for the Snake screen: a way back, the game's name over a live
/// score, and the help tile.
///
/// A Snake-shaped copy of [GameHeader] rather than the shared one, because Snake
/// has no clock to show where every other game does — the score takes that
/// place instead.
class _SnakeHeader extends StatelessWidget {
  const _SnakeHeader({
    required this.title,
    required this.subtitle,
    required this.onHowToPlay,
    required this.onPause,
  });

  final String title;
  final String subtitle;
  final VoidCallback onHowToPlay;

  /// Pauses the run, or `null` when there is nothing to pause (before the first
  /// move, while already paused, or once the run is over). The pause tile takes a
  /// trailing slot beside the help tile that is always reserved, so the title
  /// stays centred and nothing shifts as the tile comes and goes — a leading
  /// slot of the same width mirrors it on the other side.
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Row(
        children: <Widget>[
          _HeaderTile(
            semanticLabel: l10n.backToGameList,
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          // Mirrors the trailing pause slot so the title is centred either way.
          const SizedBox(width: kMinTapTarget),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(title, style: NookType.title(colors.ink)),
                const SizedBox(height: 1),
                Text(subtitle, style: NookType.sectionLabel(colors.inkFaint)),
              ],
            ),
          ),
          if (onPause != null)
            _HeaderTile(
              semanticLabel: l10n.snakePause,
              icon: Icons.pause_rounded,
              onTap: onPause!,
            )
          else
            const SizedBox(width: kMinTapTarget),
          _HeaderTile(
            semanticLabel: l10n.howToPlayOpen(title),
            icon: Icons.help_outline_rounded,
            onTap: onHowToPlay,
          ),
        ],
      ),
    );
  }
}

class _HeaderTile extends StatelessWidget {
  const _HeaderTile({
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Semantics(
      label: semanticLabel,
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
          onTap: onTap,
          child: SizedBox(
            width: kMinTapTarget,
            height: kMinTapTarget,
            child: Icon(icon, size: 18, color: colors.inkMuted),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    return Material(
      color: colors.clay,
      borderRadius: const BorderRadius.all(NookRadius.key),
      child: InkWell(
        borderRadius: const BorderRadius.all(NookRadius.key),
        onTap: onTap,
        child: Container(
          height: kMinTapTarget + 6,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          child: Text(label, style: NookType.buttonLabel(colors.surface)),
        ),
      ),
    );
  }
}

/// The board's running commentary for a screen reader, as one live region.
///
/// The Snake field is deliberately **not** a per-cell `Semantics` tree — a few
/// hundred cells changing every tick would be noise rather than information, so
/// the board carries a single container label ([SnakeBoard]) and the meaningful
/// events are spoken here in words instead. This is the intentional exception to
/// Nook's "one Semantics node per cell" board rule, and it is what makes an
/// arcade field usable with a screen reader: the score and length as they change,
/// the final score when the run is over.
///
/// A `liveRegion` re-announces only when its label changes, so this speaks on
/// each piece of food eaten and once at game over, and stays silent while the
/// score holds still — including all the while a run is paused.
class _SpokenBoardState extends StatelessWidget {
  const _SpokenBoardState({required this.label});

  /// The sentence to speak, or `null` before the run has begun. The node is kept
  /// in the tree either way, so its label goes empty → spoken → spoken, each
  /// change an announcement, rather than appearing and disappearing.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: label ?? '',
      excludeSemantics: true,
      child: const SizedBox.shrink(),
    );
  }
}

/// The on-screen direction pad: a full, gesture-free way to steer the snake.
///
/// Swiping and the hardware keyboard both still work; this is the alternative
/// that needs neither, so Snake can be played by tapping alone (VIB-112). Its
/// four buttons are laid out as a plus, each at least [kMinTapTarget] across,
/// each labelled for a screen reader, and each coloured from tokens. It carries
/// no decorative motion of its own — and under reduced motion even the tap
/// ripple is dropped — so there is nothing here the player asked not to see.
class _SnakeDpad extends StatelessWidget {
  const _SnakeDpad({required this.onDirection, required this.reduceMotion});

  /// Called with the direction of the button pressed.
  final void Function(SnakeDirection direction) onDirection;

  /// Whether the player has asked for reduced motion, in which case the buttons
  /// give up their tap ripple.
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _DpadButton(
            direction: SnakeDirection.up,
            icon: Icons.keyboard_arrow_up_rounded,
            reduceMotion: reduceMotion,
            onPressed: onDirection,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _DpadButton(
                direction: SnakeDirection.left,
                icon: Icons.keyboard_arrow_left_rounded,
                reduceMotion: reduceMotion,
                onPressed: onDirection,
              ),
              const SizedBox(width: kMinTapTarget),
              _DpadButton(
                direction: SnakeDirection.right,
                icon: Icons.keyboard_arrow_right_rounded,
                reduceMotion: reduceMotion,
                onPressed: onDirection,
              ),
            ],
          ),
          const SizedBox(height: 4),
          _DpadButton(
            direction: SnakeDirection.down,
            icon: Icons.keyboard_arrow_down_rounded,
            reduceMotion: reduceMotion,
            onPressed: onDirection,
          ),
        ],
      ),
    );
  }
}

/// One button of the [_SnakeDpad].
class _DpadButton extends StatelessWidget {
  const _DpadButton({
    required this.direction,
    required this.icon,
    required this.reduceMotion,
    required this.onPressed,
  });

  /// The side of the button, comfortably above the 44px floor.
  static const double _size = kMinTapTarget + 12;

  final SnakeDirection direction;
  final IconData icon;
  final bool reduceMotion;
  final void Function(SnakeDirection direction) onPressed;

  @override
  Widget build(BuildContext context) {
    final NookColors colors = Theme.of(context).nook;
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Semantics(
      label: _label(l10n),
      button: true,
      excludeSemantics: true,
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(NookRadius.tile),
          side: BorderSide(color: colors.line),
        ),
        child: InkWell(
          // Keyed by the direction's name, never a translated word, so a test can
          // press a button without knowing the player's language.
          key: ValueKey<String>('snake-dpad-${direction.name}'),
          borderRadius: const BorderRadius.all(NookRadius.tile),
          // The ripple is the only motion a button makes; reduced motion drops it.
          splashFactory: reduceMotion ? NoSplash.splashFactory : null,
          onTap: () => onPressed(direction),
          child: SizedBox(
            width: _size,
            height: _size,
            child: Icon(icon, size: 26, color: colors.inkMuted),
          ),
        ),
      ),
    );
  }

  String _label(AppLocalizations l10n) => switch (direction) {
    SnakeDirection.up => l10n.snakeSteerUp,
    SnakeDirection.down => l10n.snakeSteerDown,
    SnakeDirection.left => l10n.snakeSteerLeft,
    SnakeDirection.right => l10n.snakeSteerRight,
  };
}
