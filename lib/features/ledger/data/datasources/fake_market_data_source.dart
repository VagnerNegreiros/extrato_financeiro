import 'dart:math';

import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/data/datasources/market_data_source.dart';
import 'package:extrato_financeiro/features/ledger/data/dtos/market_dtos.dart';
import 'package:extrato_financeiro/features/ledger/data/ledger/seeded_random.dart';

/// Offline market data for the dev flavor, tests and demos.
///
/// Prices are a deterministic function of the asset and the day, built as
/// the same JSON the API returns and parsed by the same DTOs, so the whole
/// pipeline is exercised. [failure] simulates adverse scenarios.
final class FakeMarketDataSource implements MarketDataSource {
  new({
    required this._clock,
    this.failure = FakeFailure.none,
    this.latency = const Duration(milliseconds: 400),
    this._sleep = realSleep,
  });

  final Clock _clock;
  final FakeFailure failure;
  final Duration latency;
  final Sleep _sleep;

  static const _basePrices = {
    'bitcoin': 430000.0,
    'ethereum': 15500.0,
    'solana': 950.0,
  };

  @override
  Future<MarketChartDto> fetchDailyChart(
    String assetId, {
    required int days,
  }) async {
    await _simulateNetwork();
    final now = _clock.nowUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final json = {
      'prices': [
        for (var offset = days; offset >= 0; offset--)
          _point(assetId, today.subtract(Duration(days: offset))),
        // Like the real API, the last point is the partial current price.
        [now.millisecondsSinceEpoch, _price(assetId, now)],
      ],
    };
    return MarketChartDto.fromJson(json, nowUtc: now);
  }

  @override
  Future<SimplePriceDto> fetchCurrentPrice(
    String assetId, {
    Cancellation? cancellation,
  }) async {
    await _simulateNetwork();
    if (cancellation?.isCancelled ?? false) {
      throw const RequestCancelledException();
    }
    final now = _clock.nowUtc();
    final yesterday = now.subtract(const Duration(days: 1));
    final price = _price(assetId, now);
    final change = (price / _price(assetId, yesterday) - 1) * 100;
    return SimplePriceDto.fromJson({
      assetId: {'brl': price, 'brl_24h_change': change},
    }, assetId: assetId);
  }

  Future<void> _simulateNetwork() async {
    await _sleep(latency);
    switch (failure) {
      case FakeFailure.none:
        return;
      case FakeFailure.network:
        throw const NetworkException('fake: offline');
      case FakeFailure.rateLimit:
        throw const RateLimitedException(
          retryAfter: Duration(seconds: 30),
          debugMessage: 'fake: 429',
        );
      case FakeFailure.server:
        throw const HttpStatusException(503, 'fake: unavailable');
    }
  }

  List<num> _point(String assetId, DateTime dayUtc) => [
    dayUtc.millisecondsSinceEpoch,
    _price(assetId, dayUtc),
  ];

  /// Smooth waves plus seeded noise: plausible charts, fully reproducible.
  double _price(String assetId, DateTime instant) {
    final base = _basePrices[assetId] ?? 100.0;
    final day = instant.millisecondsSinceEpoch / Duration.millisecondsPerDay;
    final noise =
        SeededRandom.fromKey('$assetId|${day.floor()}').nextDouble() - 0.5;
    final factor =
        1 + 0.08 * sin(day / 7) + 0.03 * sin(day / 2.3) + 0.02 * noise;
    return double.parse((base * factor).toStringAsFixed(2));
  }
}
