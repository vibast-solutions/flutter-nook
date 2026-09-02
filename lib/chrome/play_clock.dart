import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current instant.
///
/// A provider rather than a direct call to [DateTime.now] so that a test can
/// own time: a clock is the one part of a puzzle that cannot be asserted about
/// without deciding when "now" is.
final Provider<DateTime Function()> nowProvider = Provider<DateTime Function()>(
  (Ref ref) => DateTime.now,
  name: 'now',
);

/// How long the puzzle being opened has already been played for.
///
/// Zero for a new puzzle; a resumed one overrides this with the time in its
/// save, so the clock starts where the player left it rather than being wound
/// forward afterwards.
final Provider<Duration> resumedElapsedProvider = Provider<Duration>(
  (Ref ref) => Duration.zero,
  name: 'resumedElapsed',
);

/// How long the puzzle on screen has been played for.
///
/// Scoped to the game screen: it is created when a puzzle is opened and thrown
/// away with it, so no puzzle can ever inherit the clock of the one before.
final NotifierProvider<PlayClock, Duration> playClockProvider =
    NotifierProvider<PlayClock, Duration>(
      PlayClock.new,
      name: 'playClock',
      dependencies: [resumedElapsedProvider],
    );

/// A clock that only runs while the player is actually playing.
///
/// Elapsed time is **accumulated from intervals**, never measured from a start
/// timestamp. A puzzle opened before bed and finished at breakfast has to come
/// back saying four minutes, not nine hours, and the difference between those
/// two answers is exactly the difference between adding up the stretches the
/// puzzle was on screen and subtracting two wall-clock readings.
class PlayClock extends Notifier<Duration> {
  /// How often a running clock republishes itself.
  ///
  /// The display shows whole seconds, so this is as often as it can change.
  /// The value a save records is not read from here — see [elapsed] — so a
  /// slow tick can never lose time.
  ///
  /// **Starting does not publish**, which is what lets the screen start the
  /// clock as it is built: a provider may not be written to while the widget
  /// tree is. Pausing does, so that a puzzle finished between two ticks shows
  /// the time it was finished in rather than the time of the last tick.
  static const Duration tick = Duration(seconds: 1);

  late DateTime Function() _now;
  Duration _accumulated = Duration.zero;
  DateTime? _runningSince;
  Timer? _ticker;

  @override
  Duration build() {
    _now = ref.watch(nowProvider);
    _accumulated = ref.watch(resumedElapsedProvider);
    ref.onDispose(_stopTicker);
    return _accumulated;
  }

  /// Whether the clock is counting.
  bool get isRunning => _runningSince != null;

  /// The reading at this instant, to the microsecond.
  ///
  /// [state] lags this by up to a [tick], because a widget does not need to be
  /// rebuilt more often than the digits change. A save reads this instead, so
  /// closing the app never rounds a second off the player's time.
  Duration get elapsed {
    final DateTime? since = _runningSince;
    if (since == null) {
      return _accumulated;
    }
    return _accumulated + _now().difference(since);
  }

  /// Starts the clock, or leaves it running if it already is.
  void start() {
    if (_runningSince != null) {
      return;
    }
    _runningSince = _now();
    _ticker ??= Timer.periodic(tick, (Timer _) => state = elapsed);
  }

  /// Stops the clock, keeping what it has counted so far.
  ///
  /// Pausing something already paused is deliberately harmless: the app is
  /// backgrounded and the screen is disposed in whichever order the platform
  /// feels like, and neither of them should have to know about the other.
  void pause() {
    final DateTime? since = _runningSince;
    if (since != null) {
      _accumulated += _now().difference(since);
      _runningSince = null;
    }
    _stopTicker();
    state = _accumulated;
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }
}

/// A duration as a clock reading: `07:42`, or `1:07:42` past an hour.
///
/// Digits and colons, with no words in it at all, so it reads the same in
/// every language Nook is translated into.
String clockReading(Duration elapsed) {
  final int hours = elapsed.inHours;
  final String minutes = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
  final String seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  return hours == 0 ? '$minutes:$seconds' : '$hours:$minutes:$seconds';
}
