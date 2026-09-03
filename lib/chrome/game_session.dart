import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ProviderListenable — the type a game hands in for its controller — is not in
// the main barrel; it lives here.
import 'package:flutter_riverpod/misc.dart';

import 'play_clock.dart';
import 'solve_outcome.dart';

/// Keeps a puzzle's clock honest, records it when it is solved, and — for a
/// game that saves — keeps it written to disk as it is played.
///
/// Shared by every game rather than each growing its own: whether a puzzle is
/// on screen and in front of the player, when it was finished and what time it
/// took are the same facts in Sudoku, Stars and Duo. What differs is only *what
/// a game does with a board* — Sudoku writes a save on every move and throws it
/// away when solved (VIB-75); Stars does not save at all until VIB-89 — so the
/// saving is handed in as [writeSave] and [discardSave], and a game that passes
/// neither simply keeps a clock and records its solves.
///
/// It lives beside the screen rather than inside the controller because the
/// controller is a pure transformation of the game state and is tested without
/// pumping a frame. Whether a puzzle is on screen is exactly the kind of fact
/// only a widget knows.
class GameSession<T> extends ConsumerStatefulWidget {
  const GameSession({
    required this.gameProvider,
    required this.isSolved,
    required this.wasHinted,
    required this.child,
    this.writeSave,
    this.discardSave,
    super.key,
  });

  /// The controller whose state this session watches.
  final ProviderListenable<AsyncValue<T>> gameProvider;

  /// Whether a game state is a finished puzzle.
  final bool Function(T game) isSolved;

  /// Whether a game state was ever helped along by a hint.
  final bool Function(T game) wasHinted;

  /// Writes the in-progress board to disk, or `null` for a game that does not
  /// save yet. Called with the time on the clock at the moment it was asked.
  final Future<void> Function(T game, Duration elapsed, DateTime at)? writeSave;

  /// Throws away the save for a finished board, or `null` for a game that does
  /// not save.
  final Future<void> Function(T game)? discardSave;

  /// The screen itself.
  final Widget child;

  @override
  ConsumerState<GameSession<T>> createState() => _GameSessionState<T>();
}

class _GameSessionState<T> extends ConsumerState<GameSession<T>>
    with WidgetsBindingObserver {
  late final PlayClock _clock;
  late final DateTime Function() _now;

  /// Writes wait for one another, so two moves in quick succession cannot land
  /// in the wrong order and leave the older board on disk.
  Future<void> _writes = Future<void>.value();

  T? _latest;

  /// Whether the puzzle on screen has already been counted as solved.
  ///
  /// A finished board publishes itself more than once — a tap on a spent
  /// control, a rebuild — and a puzzle is only ever finished once.
  bool _counted = false;

  @override
  void initState() {
    super.initState();
    _clock = ref.read(playClockProvider.notifier);
    _now = ref.read(nowProvider);
    WidgetsBinding.instance.addObserver(this);
    // The clock already holds the time a resumed puzzle came with; starting it
    // is all there is to do.
    _clock.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // The clock is not paused here, it is read and abandoned: it belongs to the
    // scope this screen opened and dies with it, and a provider may not be
    // written to while the tree is coming down. What it counted up to this
    // moment is what a save gets.
    _record();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _clock.start();
      return;
    }
    // Anything else means the puzzle is no longer in front of the player —
    // backgrounded, on the app switcher, or on the way out. The clock stops and
    // what it counted goes to disk, because the app may not be asked again
    // before it is killed.
    _clock.pause();
    _record();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<T>>(widget.gameProvider, (
      AsyncValue<T>? previous,
      AsyncValue<T> next,
    ) {
      final T? game = next.value;
      if (game == null) {
        return;
      }
      _latest = game;
      if (widget.isSolved(game)) {
        // The puzzle is over: the clock stops on the time the player took,
        // rather than counting on while they look at it.
        _clock.pause();
        _count(game);
      } else if (_counted) {
        // A new puzzle has arrived in place of a finished one. Its result is
        // not this puzzle's, and neither is the time the clock stopped on: both
        // go back to nothing.
        _counted = false;
        _clock.restart();
        ref.read(solveOutcomeProvider.notifier).clear();
      }
      _record();
    });
    return widget.child;
  }

  /// Counts [game] as solved, once.
  ///
  /// Only a finished puzzle is ever recorded: a player who walks away from one
  /// leaves nothing behind but the save, because Nook keeps no record of
  /// anything anybody failed to do.
  void _count(T game) {
    if (_counted) {
      return;
    }
    _counted = true;
    ref
        .read(solveOutcomeProvider.notifier)
        .record(time: _clock.elapsed, hinted: widget.wasHinted(game));
  }

  /// Writes the game as it stands, or clears the save once it is solved.
  ///
  /// A game that passes neither [GameSession.writeSave] nor
  /// [GameSession.discardSave] has nothing to write, so this is a clock-only
  /// session and the method does nothing.
  void _record() {
    final T? game = _latest;
    if (game == null) {
      return;
    }
    final Future<void> Function(T, Duration, DateTime)? write =
        widget.writeSave;
    final Future<void> Function(T)? discard = widget.discardSave;
    if (write == null && discard == null) {
      return;
    }
    // Read before queueing: by the time the write runs the player may have
    // moved on, and a save has to hold the board it was asked to hold.
    final Duration elapsed = _clock.elapsed;
    final DateTime at = _now();
    final bool solved = widget.isSolved(game);
    _writes = _writes.then((_) async {
      try {
        if (solved) {
          await discard?.call(game);
        } else {
          await write?.call(game, elapsed, at);
        }
      } catch (error, stack) {
        // A save that cannot be written is worth reporting and not worth
        // interrupting a puzzle for: there is nothing the player could do about
        // it, and the game in front of them is still perfectly playable.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'nook',
            context: ErrorDescription('saving a puzzle in progress'),
          ),
        );
      }
    });
  }
}
