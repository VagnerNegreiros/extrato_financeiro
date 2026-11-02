import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/data/datasources/fake_market_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/fake_market.dart';

void main() {
  final clock = FixedClock(DateTime.utc(2026, 11, 2, 15, 30));

  test('produces one point per day plus the current price', () async {
    final chart = await instantFakeMarket(clock)
        .fetchDailyChart('bitcoin', days: 7);

    expect(chart.prices, hasLength(9));
    expect(chart.prices.first.timestamp, DateTime.utc(2026, 10, 26));
    expect(chart.prices.last.timestamp, clock.nowUtc());
  });

  test('is deterministic', () async {
    final a = await instantFakeMarket(clock)
        .fetchDailyChart('ethereum', days: 30);
    final b = await instantFakeMarket(clock)
        .fetchDailyChart('ethereum', days: 30);
    expect(a.prices.map((p) => p.price), b.prices.map((p) => p.price));
  });

  test('current price includes the 24h change', () async {
    final price = await instantFakeMarket(clock).fetchCurrentPrice('solana');
    expect(price.price.toDouble(), greaterThan(0));
    expect(price.change24hPercent, isNotNull);
  });

  test('honours cancellation', () async {
    await expectLater(
      instantFakeMarket(clock)
          .fetchCurrentPrice('solana', cancellation: Cancellation()..cancel()),
      throwsA(isA<RequestCancelledException>()),
    );
  });

  test('simulates adverse scenarios', () async {
    await expectLater(
      instantFakeMarket(
        clock,
        failure: FakeFailure.network,
      ).fetchDailyChart('bitcoin', days: 1),
      throwsA(isA<NetworkException>()),
    );
    await expectLater(
      instantFakeMarket(
        clock,
        failure: FakeFailure.rateLimit,
      ).fetchDailyChart('bitcoin', days: 1),
      throwsA(isA<RateLimitedException>()),
    );
    await expectLater(
      instantFakeMarket(
        clock,
        failure: FakeFailure.server,
      ).fetchCurrentPrice('bitcoin'),
      throwsA(isA<HttpStatusException>()),
    );
  });

  test('waits for the simulated latency', () async {
    final waits = <Duration>[];
    await FakeMarketDataSource(
      clock: clock,
      sleep: (duration) async => waits.add(duration),
    ).fetchDailyChart('bitcoin', days: 1);
    expect(waits, [const Duration(milliseconds: 400)]);
  });
}
