import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/data/datasources/market_data_source.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/market_quote.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/market_quote_repository.dart';

/// Current prices with a short in-memory cache, so moving back and forth
/// between transaction details does not spend API quota.
///
/// Requests are not deduplicated on purpose: each caller owns its
/// cancellation, and sharing a request would let one screen cancel
/// another's. The cache absorbs repeated reads instead.
final class MarketQuoteRepositoryImpl implements MarketQuoteRepository {
  new({
    required this._remote,
    required this._clock,
    this.cacheTtl = const Duration(seconds: 60),
  });

  final MarketDataSource _remote;
  final Clock _clock;
  final Duration cacheTtl;
  final _cache = <String, MarketQuote>{};

  @override
  Future<Result<MarketQuote>> getCurrentQuote(
    String assetId, {
    Cancellation? cancellation,
  }) async {
    final now = _clock.nowUtc();
    final cached = _cache[assetId];
    if (cached != null && now.difference(cached.fetchedAt) < cacheTtl) {
      return Success(cached);
    }
    try {
      final dto = await _remote.fetchCurrentPrice(
        assetId,
        cancellation: cancellation,
      );
      final quote = MarketQuote(
        assetId: assetId,
        price: Money.fromDecimal(dto.price),
        fetchedAt: now,
        change24hPercent: dto.change24hPercent,
      );
      _cache[assetId] = quote;
      return Success(quote);
    } on Object catch (error) {
      return Err(toFailure(error));
    }
  }
}
