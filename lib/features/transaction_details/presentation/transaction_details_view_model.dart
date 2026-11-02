import 'dart:async';

import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/transaction_details/presentation/transaction_details_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// One view model per transaction id, disposed when the screen closes.
final NotifierProviderFamily<
  TransactionDetailsViewModel,
  TransactionDetailsState,
  String
>
transactionDetailsViewModelProvider = NotifierProvider.autoDispose
    .family<TransactionDetailsViewModel, TransactionDetailsState, String>(
      TransactionDetailsViewModel.new,
    );

class TransactionDetailsViewModel extends Notifier<TransactionDetailsState> {
  new(this.id);

  final String id;

  /// Cancels the in-flight quote request when the user leaves the screen,
  /// so an abandoned screen never spends API quota or updates state.
  Cancellation? _quoteCancellation;

  @override
  TransactionDetailsState build() {
    ref
      ..onDispose(() => _quoteCancellation?.cancel())
      ..listen<AsyncValue<SyncInfo>>(syncInfoProvider, (previous, next) {
        final before = previous?.value?.lastSuccessAt;
        final after = next.value?.lastSuccessAt;
        // A sync may settle a pending transaction: re-read it from the
        // cache, the same source the statement uses.
        if (after != null && after != before) {
          unawaited(_loadTransaction(withQuote: false));
        }
      });
    unawaited(Future.microtask(_loadTransaction));
    return const TransactionDetailsState();
  }

  Future<void> retry() async {
    state = state.copyWith(isLoading: true, failure: null);
    await _loadTransaction();
  }

  Future<void> retryQuote() async {
    final transaction = state.transaction;
    if (transaction != null) await _loadQuote(transaction);
  }

  Future<void> _loadTransaction({bool withQuote = true}) async {
    final result = await ref.read(getTransactionDetailsProvider)(id);
    if (!ref.mounted) return;
    switch (result) {
      case Success(value: final transaction):
        state = state.copyWith(
          transaction: transaction,
          isLoading: false,
          failure: null,
        );
        if (withQuote) await _loadQuote(transaction);
      case Err(:final failure):
        state = state.copyWith(isLoading: false, failure: failure);
    }
  }

  Future<void> _loadQuote(Transaction transaction) async {
    if (transaction.metadata.assetId == null) {
      state = state.copyWith(quoteStatus: QuoteStatus.notApplicable);
      return;
    }
    _quoteCancellation?.cancel();
    final cancellation = _quoteCancellation = Cancellation();
    state = state.copyWith(
      quoteStatus: QuoteStatus.loading,
      quoteFailure: null,
    );

    final result = await ref.read(getCurrentQuoteProvider)(
      transaction,
      cancellation: cancellation,
    );
    if (!ref.mounted || cancellation.isCancelled) return;
    state = switch (result) {
      Success(value: final quote) => state.copyWith(
        quoteStatus: QuoteStatus.loaded,
        quote: quote,
      ),
      Err(:final failure) => state.copyWith(
        quoteStatus: QuoteStatus.unavailable,
        quoteFailure: failure,
      ),
    };
  }
}
