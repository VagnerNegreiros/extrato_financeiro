/// Small deterministic PRNG (mulberry32).
///
/// `dart:math`'s `Random(seed)` is not guaranteed to produce the same
/// sequence across SDK versions; the ledger must be identical forever for
/// the same market data, so the algorithm is pinned here.
final class SeededRandom {
  new(int seed) : _state = seed & _mask;

  /// 32-bit FNV-1a hash, used to derive seeds from stable strings.
  factory fromKey(String key) {
    var hash = 0x811C9DC5;
    for (final unit in key.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & _mask;
    }
    return SeededRandom(hash);
  }

  static const _mask = 0xFFFFFFFF;

  int _state;

  /// Uniform in [0, 1).
  double nextDouble() => _nextUint32() / 0x100000000;

  /// Uniform integer in [0, max).
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'must be positive');
    return (nextDouble() * max).floor();
  }

  int _nextUint32() {
    _state = (_state + 0x6D2B79F5) & _mask;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    // The sum must wrap to 32 bits like JavaScript's int32 conversion,
    // otherwise high bits leak into the final shift.
    t ^= (t + _imul(t ^ (t >>> 7), t | 61)) & _mask;
    return (t ^ (t >>> 14)) & _mask;
  }

  static int _imul(int a, int b) => (a * b) & _mask;
}
