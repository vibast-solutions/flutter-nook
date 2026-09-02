import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:puzzle_engine/puzzle_engine.dart';

import '../../chrome/play_clock.dart';
import '../../store/nook_database.dart';
import 'sudoku_controller.dart';
import 'sudoku_save.dart';
import 'sudoku_state.dart';

/// Keeps the puzzle on screen written to disk, and its clock honest.
///
/// This is the whole of "progress is saved continuously": every change the
/// player makes is written as it happens, so there is no such thing as an
/// unsaved move and nothing depends on the app being closed politely. The one
/// thing it does *not* save is a finished puzzle — solving throws the save
/// away, because a solved grid is a result rather than something to come back
/// to.
///
/// It lives beside the screen rather than inside the controller because the
/// controller is a pure transformation of [SudokuGameState] and is tested
/// without pumping a frame. Whether a puzzle is on screen and in front of the
/// player is exactly the kind of fact only a widget knows.
class SudokuSession extends ConsumerStatefulWidget {
  const SudokuSession({
    required this.difficulty,
    required this.child,
    super.key,
  });

  /// The tier the player asked for, which is what the save records.
  final SudokuDifficulty difficulty;

  /// The screen itself.
  final Widget child;

  @override
  ConsumerState<SudokuSession> createState() => _SudokuSessionState();
}

class _SudokuSessionState extends ConsumerState<SudokuSession>
    with WidgetsBindingObserver {
  late final SavedGameStore _store;
  late final PlayClock _clock;
  late final DateTime Function() _now;

  /// Writes wait for one another, so two moves in quick succession cannot land
  /// in the wrong order and leave the older board on disk.
  Future<void> _writes = Future<void>.value();

  SudokuGameState? _latest;

  @override
  void initState() {
    super.initState();
    _store = ref.read(savedGameStoreProvider);
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
    // The clock is not paused here, it is read and abandoned: it belongs to
    // the scope this screen opened and dies with it, and a provider may not be
    // written to while the tree is coming down. What it counted up to this
    // moment is what the save gets.
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
    // backgrounded, on the app switcher, or on the way out. The clock stops
    // and what it counted goes to disk, because the app may not be asked
    // again before it is killed.
    _clock.pause();
    _record();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SudokuGameState>>(sudokuControllerProvider, (
      AsyncValue<SudokuGameState>? previous,
      AsyncValue<SudokuGameState> next,
    ) {
      final SudokuGameState? game = next.value;
      if (game == null) {
        return;
      }
      _latest = game;
      if (game.isSolved) {
        // The puzzle is over: the clock stops on the time the player took,
        // rather than counting on while they look at it.
        _clock.pause();
      }
      _record();
    });
    return widget.child;
  }

  /// Writes the game as it stands, or clears the save once it is solved.
  void _record() {
    final SudokuGameState? game = _latest;
    if (game == null) {
      return;
    }
    // Read before queueing: by the time the write runs the player may have
    // moved on, and a save has to hold the board it was asked to hold.
    final Duration elapsed = _clock.elapsed;
    final DateTime at = _now();
    _writes = _writes.then((_) async {
      try {
        if (game.isSolved) {
          await _store.discard(game.variant.id);
        } else {
          await _store.save(
            savedGameFor(
              game,
              difficulty: widget.difficulty,
              elapsed: elapsed,
              at: at,
            ),
          );
        }
      } catch (error, stack) {
        // A save that cannot be written is worth reporting and not worth
        // interrupting a puzzle for: there is nothing the player could do
        // about it, and the game in front of them is still perfectly playable.
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
