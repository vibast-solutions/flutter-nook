import 'package:puzzle_engine/puzzle_engine.dart';
import 'package:test/test.dart';

void main() {
  group('SnakeSpeed', () {
    test('levels number from one upward in declaration order', () {
      expect(SnakeSpeed.values.first.level, 1);
      for (int i = 0; i < SnakeSpeed.values.length; i++) {
        expect(SnakeSpeed.values[i].level, i + 1);
      }
    });

    test('a higher level is a strictly shorter interval — monotonic', () {
      for (int i = 1; i < SnakeSpeed.values.length; i++) {
        final Duration slower = SnakeSpeed.values[i - 1].tick;
        final Duration faster = SnakeSpeed.values[i].tick;
        expect(
          faster,
          lessThan(slower),
          reason:
              '${SnakeSpeed.values[i].name} should be faster than '
              '${SnakeSpeed.values[i - 1].name}',
        );
      }
    });

    test('every level is a sane, positive frame interval', () {
      for (final SnakeSpeed speed in SnakeSpeed.values) {
        expect(speed.tick, greaterThan(Duration.zero));
        // A generous ceiling that would still catch a mapping gone wrong, and a
        // floor that keeps even the fastest above one frame at 60Hz.
        expect(speed.tick.inMilliseconds, inInclusiveRange(50, 400));
      }
    });

    test('the standard speed is the middle of the ladder', () {
      // The default is neither the slowest nor the fastest, so a player who
      // never touches the picker gets a pace with room in both directions.
      expect(SnakeSpeed.standard, isNot(SnakeSpeed.values.first));
      expect(SnakeSpeed.standard, isNot(SnakeSpeed.values.last));
    });
  });
}
