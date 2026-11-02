import 'dart:io';
import 'dart:math';

import 'package:extrato_financeiro/core/network/retry_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RetryPolicy.delayFor', () {
    test('grows exponentially with jitter between 50% and 100%', () {
      final policy = RetryPolicy(random: Random(42));
      for (var attempt = 0; attempt < 3; attempt++) {
        final full = Duration(seconds: pow(2, attempt).toInt());
        final delay = policy.delayFor(attempt)!;
        expect(delay, greaterThanOrEqualTo(full * 0.5));
        expect(delay, lessThan(full));
      }
    });

    test('is capped at the maximum delay', () {
      final policy = RetryPolicy(
        maxRetries: 10,
        maxDelay: const Duration(seconds: 4),
        random: Random(1),
      );
      expect(policy.delayFor(8), lessThanOrEqualTo(const Duration(seconds: 4)));
    });

    test('gives up after the last retry', () {
      expect(RetryPolicy(maxRetries: 2).delayFor(2), isNull);
    });

    test('Retry-After wins, unless it is too long to wait', () {
      final policy = RetryPolicy();
      expect(
        policy.delayFor(0, retryAfter: const Duration(seconds: 7)),
        const Duration(seconds: 7),
      );
      expect(
        policy.delayFor(0, retryAfter: const Duration(minutes: 5)),
        isNull,
      );
    });

    test('only transient statuses are retryable', () {
      final policy = RetryPolicy();
      for (final status in [429, 502, 503, 504]) {
        expect(policy.shouldRetryStatus(status), isTrue, reason: '$status');
      }
      for (final status in [null, 400, 401, 404, 500]) {
        expect(policy.shouldRetryStatus(status), isFalse, reason: '$status');
      }
    });
  });

  group('RetryPolicy.parseRetryAfter', () {
    final now = DateTime.utc(2026, 11, 2, 12);

    test('parses delta seconds', () {
      expect(
        RetryPolicy.parseRetryAfter(' 30 ', now: now),
        const Duration(seconds: 30),
      );
    });

    test('parses HTTP dates relative to now', () {
      final header = HttpDate.format(now.add(const Duration(seconds: 45)));
      expect(
        RetryPolicy.parseRetryAfter(header, now: now),
        const Duration(seconds: 45),
      );
      final past = HttpDate.format(now.subtract(const Duration(minutes: 1)));
      expect(RetryPolicy.parseRetryAfter(past, now: now), Duration.zero);
    });

    test('ignores missing, negative or malformed values', () {
      expect(RetryPolicy.parseRetryAfter(null, now: now), isNull);
      expect(RetryPolicy.parseRetryAfter('', now: now), isNull);
      expect(RetryPolicy.parseRetryAfter('-5', now: now), isNull);
      expect(RetryPolicy.parseRetryAfter('soon', now: now), isNull);
    });
  });
}
