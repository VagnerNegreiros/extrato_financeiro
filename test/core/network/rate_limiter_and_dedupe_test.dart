import 'dart:async';

import 'package:extrato_financeiro/core/network/rate_limiter.dart';
import 'package:extrato_financeiro/core/network/request_deduplicator.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RateLimiter', () {
    late FixedClock clock;
    late List<Duration> sleeps;
    late RateLimiter limiter;

    setUp(() {
      clock = FixedClock(DateTime.utc(2026, 11, 2, 12));
      sleeps = [];
      limiter = RateLimiter(
        clock: clock,
        capacity: 2,
        sleep: (duration) async {
          sleeps.add(duration);
          clock.advance(duration);
        },
      );
    });

    test('lets a burst up to capacity through without waiting', () async {
      await limiter.acquire();
      await limiter.acquire();
      expect(sleeps, isEmpty);
      expect(limiter.availableTokens, lessThan(1));
    });

    test('waits for a token once the bucket is empty', () async {
      await Future.wait([
        limiter.acquire(),
        limiter.acquire(),
        limiter.acquire(),
      ]);
      // Two tokens per minute: the third request waits ~30 seconds.
      expect(sleeps, hasLength(1));
      expect(sleeps.single.inSeconds, 30);
    });

    test('refills over time up to capacity', () async {
      await limiter.acquire();
      await limiter.acquire();
      clock.advance(const Duration(minutes: 10));
      expect(limiter.availableTokens, 2);
    });
  });

  group('RequestDeduplicator', () {
    test('concurrent calls with the same key share one execution', () async {
      final deduplicator = RequestDeduplicator<String, int>();
      final completer = Completer<int>();
      var calls = 0;

      Future<int> task() {
        calls++;
        return completer.future;
      }

      final first = deduplicator.run('sync', task);
      final second = deduplicator.run('sync', task);
      expect(deduplicator.isRunning('sync'), isTrue);
      completer.complete(7);

      expect(await first, 7);
      expect(await second, 7);
      expect(calls, 1);
      expect(deduplicator.isRunning('sync'), isFalse);
    });

    test('a finished call releases the key', () async {
      final deduplicator = RequestDeduplicator<String, int>();
      var calls = 0;
      await deduplicator.run('k', () async => ++calls);
      await deduplicator.run('k', () async => ++calls);
      expect(calls, 2);
    });

    test('different keys run independently', () async {
      final deduplicator = RequestDeduplicator<String, String>();
      final results = await Future.wait([
        deduplicator.run('a', () async => 'A'),
        deduplicator.run('b', () async => 'B'),
      ]);
      expect(results, ['A', 'B']);
    });

    test('errors reach every caller and release the key', () async {
      final deduplicator = RequestDeduplicator<String, int>();
      final first = deduplicator.run('k', () async => throw StateError('x'));
      final second = deduplicator.run('k', () async => 1);

      await expectLater(first, throwsStateError);
      await expectLater(second, throwsStateError);
      expect(await deduplicator.run('k', () async => 2), 2);
    });
  });
}
