import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/market_quote.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transaction_details_state.freezed.dart';

/// State of the optional "current price" section.
enum QuoteStatus {
  /// The transaction has no asset (deposit, withdrawal).
  notApplicable,
  loading,
  loaded,
  unavailable,
}

@freezed
abstract class TransactionDetailsState with _$TransactionDetailsState {
  const factory({
    Transaction? transaction,
    @Default(true) bool isLoading,
    Failure? failure,
    @Default(QuoteStatus.notApplicable) QuoteStatus quoteStatus,
    MarketQuote? quote,
    Failure? quoteFailure,
  }) = _TransactionDetailsState;

  const new _();

  bool get isNotFound => transaction == null && failure is NotFoundFailure;
}
