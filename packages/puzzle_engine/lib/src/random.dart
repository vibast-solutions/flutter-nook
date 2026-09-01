/// A small, self-contained pseudo-random generator.
///
/// The engine deliberately does not use `dart:math`'s [Random]: its algorithm
/// is an implementation detail of the SDK, so a puzzle generated from a given
/// seed would not be guaranteed to match on another Dart version. Nook needs
/// seed-to-puzzle to be a fixed contract — the daily puzzle is the same for
/// everyone, and a saved puzzle is stored as its seed — so the generator lives
/// here where it can never change underneath us.
///
/// The algorithm is xorshift32. It is not cryptographic and is not meant to be;
/// it is fast, reproducible, and far better than puzzle generation requires.
/// All arithmetic is masked to 32 bits so results are identical on every
/// platform, including ones without 64-bit integers.
class PuzzleRandom {
  /// Creates a generator for [seed]. Any integer is accepted; only the low
  /// 32 bits are used.
  PuzzleRandom(int seed) : _state = _sanitise(seed);

  int _state;

  static const int _mask32 = 0xFFFFFFFF;
  static const int _range32 = 0x100000000;

  /// Zero is a fixed point of xorshift, so it is replaced with a constant
  /// (the golden-ratio derived value used by many hash functions).
  static int _sanitise(int seed) {
    final int s = seed & _mask32;
    return s == 0 ? 0x9E3779B9 : s;
  }

  /// The next 32-bit value in the sequence.
  int nextUint32() {
    int x = _state;
    x ^= (x << 13) & _mask32;
    x ^= x >> 17;
    x ^= (x << 5) & _mask32;
    _state = x & _mask32;
    return _state;
  }

  /// A uniformly distributed integer in `[0, max)`.
  ///
  /// Rejection sampling keeps the distribution exactly uniform rather than
  /// leaving the modulo bias that a bare `% max` would introduce.
  int nextInt(int max) {
    if (max < 1) {
      throw ArgumentError.value(max, 'max', 'must be positive');
    }
    final int limit = _range32 - (_range32 % max);
    int value;
    do {
      value = nextUint32();
    } while (value >= limit);
    return value % max;
  }

  /// Shuffles [list] in place with a Fisher-Yates pass.
  void shuffle<T>(List<T> list) {
    for (int i = list.length - 1; i > 0; i--) {
      final int j = nextInt(i + 1);
      final T tmp = list[i];
      list[i] = list[j];
      list[j] = tmp;
    }
  }
}
