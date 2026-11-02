/// Source of the current instant (RN-15).
///
/// Domain code never calls `DateTime.now()` directly, so time-dependent rules
/// (periods, "today", pending status ageing) are deterministic in tests.
abstract interface class Clock {
  /// The current instant, always in UTC.
  DateTime nowUtc();
}

final class SystemClock implements Clock {
  const new();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// Clock frozen at a given instant; used by tests and the dev flavor.
final class FixedClock implements Clock {
  new(DateTime instant) : _instant = instant.toUtc();

  DateTime _instant;

  @override
  DateTime nowUtc() => _instant;

  void advance(Duration duration) => _instant = _instant.add(duration);
}
