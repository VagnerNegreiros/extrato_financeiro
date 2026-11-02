import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/data/datasources/fake_market_data_source.dart';
import 'package:extrato_financeiro/features/ledger/data/datasources/market_data_source.dart';
import 'package:extrato_financeiro/features/ledger/data/dtos/market_dtos.dart';
import 'package:extrato_financeiro/features/ledger/data/tracked_asset.dart';

/// Fake market without latency.
FakeMarketDataSource instantFakeMarket(
  Clock clock, {
  FakeFailure failure = FakeFailure.none,
}) => FakeMarketDataSource(
  clock: clock,
  failure: failure,
  latency: Duration.zero,
  sleep: (_) async {},
);

/// Daily charts for every tracked asset covering [days] days up to the
/// clock's current day.
Future<Map<TrackedAsset, MarketChartDto>> chartsFor(
  Clock clock, {
  required int days,
}) async {
  final market = instantFakeMarket(clock);
  return {
    for (final asset in TrackedAsset.values)
      asset: await market.fetchDailyChart(asset.id, days: days),
  };
}

CalendarDate utcDay(DateTime instant) =>
    CalendarDate(instant.year, instant.month, instant.day);

/// Wraps a data source, counting calls and optionally failing them.
final class CountingMarket implements MarketDataSource {
  new(this.delegate);

  final MarketDataSource delegate;
  int chartCalls = 0;
  int priceCalls = 0;
  Exception? errorToThrow;

  @override
  Future<MarketChartDto> fetchDailyChart(
    String assetId, {
    required int days,
  }) async {
    chartCalls++;
    final error = errorToThrow;
    if (error != null) throw error;
    return await delegate.fetchDailyChart(assetId, days: days);
  }

  @override
  Future<SimplePriceDto> fetchCurrentPrice(
    String assetId, {
    Cancellation? cancellation,
  }) async {
    priceCalls++;
    final error = errorToThrow;
    if (error != null) throw error;
    return await delegate.fetchCurrentPrice(
      assetId,
      cancellation: cancellation,
    );
  }
}
