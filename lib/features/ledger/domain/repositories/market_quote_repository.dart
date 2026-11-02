import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/market_quote.dart';

abstract interface class MarketQuoteRepository {
  /// Latest price of [assetId] in BRL. Abandoned requests are aborted when
  /// [cancellation] fires (e.g. the user leaves the details screen).
  Future<Result<MarketQuote>> getCurrentQuote(
    String assetId, {
    Cancellation? cancellation,
  });
}
