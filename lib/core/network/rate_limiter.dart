import 'dart:async';

import 'package:extrato_financeiro/core/time/clock.dart';

/// Token bucket shared by every request to the same API.
///
/// Up to [capacity] requests may go out at once; after that, tokens refill
/// at `capacity / period`. Callers wait for a token instead of failing.
final class RateLimiter {
  new({
    required Clock clock,
    this.capacity = 25,
    this.period = const Duration(minutes: 1),
    this._sleep = realSleep,
  }) : _clock = clock,
       _tokens = capacity.toDouble(),
       _lastRefill = clock.nowUtc();

  final Clock _clock;
  final int capacity;
  final Duration period;
  final Sleep _sleep;

  double _tokens;
  DateTime _lastRefill;

  // Serializes waiters so tokens are handed out in request order.
  Future<void> _queue = Future.value();

  double get availableTokens {
    _refill();
    return _tokens;
  }

  Future<void> acquire() {
    final next = _queue.then((_) => _take());
    _queue = next;
    return next;
  }

  Future<void> _take() async {
    _refill();
    while (_tokens < 1) {
      final missing = 1 - _tokens;
      final wait = Duration(
        microseconds: (missing * period.inMicroseconds / capacity).ceil(),
      );
      await _sleep(wait);
      _refill();
    }
    _tokens -= 1;
  }

  void _refill() {
    final now = _clock.nowUtc();
    final elapsed = now.difference(_lastRefill);
    if (elapsed <= Duration.zero) return;
    _tokens =
        (_tokens + elapsed.inMicroseconds * capacity / period.inMicroseconds)
            .clamp(0, capacity.toDouble());
    _lastRefill = now;
  }
}
