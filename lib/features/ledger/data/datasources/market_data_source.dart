import 'package:dio/dio.dart';
import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/network/dio_factory.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/data/dtos/market_dtos.dart';

/// Remote market data. Implementations throw `ApiException` or
/// `ParsingException`; they never return partial garbage.
abstract interface class MarketDataSource {
  /// Daily BRL prices for the last [days] days (plus the current price).
  Future<MarketChartDto> fetchDailyChart(String assetId, {required int days});

  Future<SimplePriceDto> fetchCurrentPrice(
    String assetId, {
    Cancellation? cancellation,
  });
}

final class CoinGeckoMarketDataSource implements MarketDataSource {
  new({required this._dio, required this._clock});

  final Dio _dio;
  final Clock _clock;

  /// CoinGecko ids are lower-case slugs; anything else would let input
  /// change the request path.
  static final _validId = RegExp(r'^[a-z0-9-]{1,64}$');

  @override
  Future<MarketChartDto> fetchDailyChart(
    String assetId, {
    required int days,
  }) async {
    final json = await _get(
      '/coins/${_checkId(assetId)}/market_chart',
      query: {
        'vs_currency': 'brl',
        'days': days.clamp(1, 365),
        'interval': 'daily',
      },
    );
    return MarketChartDto.fromJson(json, nowUtc: _clock.nowUtc());
  }

  @override
  Future<SimplePriceDto> fetchCurrentPrice(
    String assetId, {
    Cancellation? cancellation,
  }) async {
    final id = _checkId(assetId);
    final json = await _get(
      '/simple/price',
      query: {'ids': id, 'vs_currencies': 'brl', 'include_24hr_change': true},
      cancellation: cancellation,
    );
    return SimplePriceDto.fromJson(json, assetId: id);
  }

  String _checkId(String assetId) {
    if (!_validId.hasMatch(assetId)) {
      throw const ParsingException('invalid asset id');
    }
    return assetId;
  }

  Future<Object?> _get(
    String path, {
    required Map<String, Object> query,
    Cancellation? cancellation,
  }) async {
    final cancelToken = CancelToken();
    if (cancellation != null) {
      if (cancellation.isCancelled) throw const RequestCancelledException();
      cancellation.whenCancelled.then((_) => cancelToken.cancel()).ignore();
    }
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: query,
        cancelToken: cancelToken,
      );
      return response.data;
    } on DioException catch (error) {
      throw mapDioException(error, clock: _clock);
    }
  }
}
