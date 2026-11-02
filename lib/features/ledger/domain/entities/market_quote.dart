import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'market_quote.freezed.dart';

/// Current market price of an asset. Informative only: it never changes the
/// balance, which is derived from the ledger alone.
@freezed
abstract class MarketQuote with _$MarketQuote {
  const factory({
    required String assetId,
    required Money price,
    required DateTime fetchedAt,

    /// Percent change in the last 24 hours, when provided.
    Decimal? change24hPercent,
  }) = _MarketQuote;

  const new _();

  /// Percent change from [reference] (e.g. the trade's unit price) to the
  /// current price, exact to 4 decimal places; `null` for a zero reference.
  Decimal? changeSincePercent(Money reference) {
    if (reference.isZero) return null;
    final ratio =
        (price.toDecimal() - reference.toDecimal()) / reference.toDecimal();
    return (ratio.toDecimal(scaleOnInfinitePrecision: 8) * Decimal.fromInt(100))
        .round(scale: 4);
  }
}
