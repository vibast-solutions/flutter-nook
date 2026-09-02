import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nook/chrome/play_clock.dart';

import '../support/sudoku_fixture.dart';

/// A clock and the container it lives in, with time in the test's hands.
({PlayClock clock, TestClock time}) newClock({Duration? resumedAt}) {
  final TestClock time = TestClock();
  final ProviderContainer container = ProviderContainer(
    overrides: [
      nowProvider.overrideWithValue(time.call),
      if (resumedAt != null)
        resumedElapsedProvider.overrideWithValue(resumedAt),
    ],
  );
  addTearDown(container.dispose);
  return (clock: container.read(playClockProvider.notifier), time: time);
}

void main() {
  group('the clock counts the time a puzzle is actually played', () {
    test('a new puzzle starts at nothing', () {
      expect(newClock().clock.elapsed, Duration.zero);
    });

    test('a resumed puzzle starts where its save left off', () {
      expect(
        newClock(resumedAt: const Duration(minutes: 4)).clock.elapsed,
        const Duration(minutes: 4),
      );
    });

    test('time before the clock is started does not count', () {
      final ({PlayClock clock, TestClock time}) it = newClock();
      it.time.advance(const Duration(hours: 2));
      expect(it.clock.elapsed, Duration.zero);
    });

    test('time while it runs does', () {
      final ({PlayClock clock, TestClock time}) it = newClock();
      it.clock.start();
      it.time.advance(const Duration(seconds: 42));
      expect(it.clock.elapsed, const Duration(seconds: 42));
    });

    test('a night in the background is not nine hours of playing', () {
      // The whole reason the clock adds up intervals rather than subtracting
      // two wall-clock readings: a puzzle opened before bed and picked up at
      // breakfast has been played for four minutes.
      final ({PlayClock clock, TestClock time}) it = newClock();
      it.clock.start();
      it.time.advance(const Duration(minutes: 4));
      it.clock.pause();

      it.time.advance(const Duration(hours: 9));
      expect(it.clock.elapsed, const Duration(minutes: 4));

      it.clock.start();
      it.time.advance(const Duration(minutes: 1));
      expect(it.clock.elapsed, const Duration(minutes: 5));
    });

    test('pausing twice does not count the same stretch twice', () {
      // The screen is disposed and the app is backgrounded in whichever order
      // the platform likes, and both stop the clock.
      final ({PlayClock clock, TestClock time}) it = newClock();
      it.clock.start();
      it.time.advance(const Duration(seconds: 30));
      it.clock
        ..pause()
        ..pause();
      expect(it.clock.elapsed, const Duration(seconds: 30));
    });

    test('starting an already running clock does not restart it', () {
      final ({PlayClock clock, TestClock time}) it = newClock();
      it.clock.start();
      it.time.advance(const Duration(seconds: 10));
      it.clock.start();
      it.time.advance(const Duration(seconds: 10));
      expect(it.clock.elapsed, const Duration(seconds: 20));
      expect(it.clock.isRunning, isTrue);
    });
  });

  group('a clock reading', () {
    test('is minutes and seconds, padded', () {
      expect(clockReading(Duration.zero), '00:00');
      expect(clockReading(const Duration(seconds: 7)), '00:07');
      expect(clockReading(const Duration(minutes: 1, seconds: 30)), '01:30');
      expect(clockReading(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('grows an hours part only once there is one', () {
      expect(clockReading(const Duration(hours: 1)), '1:00:00');
      expect(
        clockReading(const Duration(hours: 2, minutes: 3, seconds: 4)),
        '2:03:04',
      );
    });

    test('rounds down, so a puzzle never reads longer than it has been', () {
      expect(clockReading(const Duration(milliseconds: 1999)), '00:01');
    });
  });
}
