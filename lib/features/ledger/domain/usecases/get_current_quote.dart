import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/market_quote.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/market_quote_repository.dart';

final class GetCurrentQuote {
  const new(this._repository);

  final MarketQuoteRepository _repository;

  /// Current price of the asset traded in [transaction]. Transactions
  /// without an asset (deposits, withdrawals) resolve to `NotFoundFailure`
  /// without touching the network.
  Future<Result<MarketQuote>> call(
    Transaction transaction, {
    Cancellation? cancellation,
  }) async {
    final assetId = transaction.metadata.assetId;
    if (assetId == null) return const Err(NotFoundFailure('no asset'));
    return await _repository.getCurrentQuote(
      assetId,
      cancellation: cancellation,
    );
  }
}
