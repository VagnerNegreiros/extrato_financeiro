import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/market_quote.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/transaction_details/presentation/transaction_details_state.dart';
import 'package:extrato_financeiro/features/transaction_details/presentation/transaction_details_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mocks.dart';
import '../../helpers/test_app.dart';
import '../../helpers/transaction_builder.dart';

void main() {
  late MockedLedger ledger;
  late ProviderContainer container;

  final trade = tx(
    cents: 4347,
    id: 'TX-20261030-03',
    direction: TransactionDirection.debit,
    category: TransactionCategory.cryptoBuy,
    status: TransactionStatus.pending,
    description: 'Compra de Bitcoin (BTC)',
    metadata: TransactionMetadata(
      assetId: 'bitcoin',
      assetSymbol: 'BTC',
      assetQuantity: Decimal.parse('0.0001'),
      unitPrice: const Money(40000000),
      counterparty: 'Corretora Fluxo',
    ),
  );
  final quote = MarketQuote(
    assetId: 'bitcoin',
    price: const Money(44000000),
    fetchedAt: testNow,
    change24hPercent: Decimal.parse('1.5'),
  );

  setUpAll(() {
    registerDomainFallbacks();
    registerFallbackValue(Cancellation());
  });

  setUp(() {
    ledger = MockedLedger();
    when(() => ledger.transactions.getById(trade.id))
        .thenAnswer((_) async => Success(trade));
    when(
      () => ledger.quotes.getCurrentQuote(
        any(),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => Success(quote));
    container = ledger.container();
  });

  tearDown(() => ledger.dispose());

  final provider = transactionDetailsViewModelProvider(trade.id);
  TransactionDetailsState read() => container.read(provider);

  Future<ProviderSubscription<TransactionDetailsState>> start() async {
    final subscription = container.listen(provider, (_, _) {});
    await pumpEventQueue();
    return subscription;
  }

  test(
    'RN-32: loads the transaction from the cache and its current quote',
    () async {
      expect(read().isLoading, isTrue);
      await start();

      expect(read().transaction, trade);
      expect(read().isLoading, isFalse);
      expect(read().quoteStatus, QuoteStatus.loaded);
      expect(read().quote, quote);
      verify(
        () => ledger.quotes.getCurrentQuote(
          'bitcoin',
          cancellation: any(named: 'cancellation'),
        ),
      ).called(1);
    },
  );

  test('transactions without an asset never request a quote', () async {
    final deposit = credit(100);
    when(() => ledger.transactions.getById(trade.id))
        .thenAnswer((_) async => Success(deposit));
    await start();

    expect(read().quoteStatus, QuoteStatus.notApplicable);
    verifyZeroInteractions(ledger.quotes);
  });

  test('unknown ids are reported as not found', () async {
    when(() => ledger.transactions.getById(trade.id))
        .thenAnswer((_) async => const Err(NotFoundFailure()));
    await start();

    expect(read().isNotFound, isTrue);
  });

  test('cache errors can be retried', () async {
    when(() => ledger.transactions.getById(trade.id))
        .thenAnswer((_) async => const Err(CacheFailure()));
    await start();
    expect(read().failure, const CacheFailure());
    expect(read().isNotFound, isFalse);

    when(() => ledger.transactions.getById(trade.id))
        .thenAnswer((_) async => Success(trade));
    await container.read(provider.notifier).retry();
    expect(read().transaction, trade);
  });

  test('quote failures keep the details and can be retried', () async {
    when(
      () => ledger.quotes.getCurrentQuote(
        any(),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => const Err(RateLimitFailure()));
    await start();

    expect(read().transaction, trade);
    expect(read().quoteStatus, QuoteStatus.unavailable);
    expect(read().quoteFailure, const RateLimitFailure());

    when(
      () => ledger.quotes.getCurrentQuote(
        any(),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((_) async => Success(quote));
    await container.read(provider.notifier).retryQuote();
    expect(read().quoteStatus, QuoteStatus.loaded);
  });

  test('leaving the screen cancels the in-flight quote request', () async {
    final pending = Completer<Result<MarketQuote>>();
    Cancellation? captured;
    when(
      () => ledger.quotes.getCurrentQuote(
        any(),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer((invocation) {
      captured = invocation.namedArguments[#cancellation] as Cancellation?;
      return pending.future;
    });

    final subscription = await start();
    expect(read().quoteStatus, QuoteStatus.loading);
    expect(captured!.isCancelled, isFalse);

    subscription.close();
    await pumpEventQueue();

    expect(captured!.isCancelled, isTrue);
    pending.complete(Success(quote));
  });

  test(
    'a sync re-reads the transaction without refetching the quote',
    () async {
      ledger.syncInfo.add(SyncInfo(lastSuccessAt: testNow));
      await start();
      clearInteractions(ledger.quotes);
      final settled = trade.copyWith(status: TransactionStatus.completed);
      when(() => ledger.transactions.getById(trade.id))
          .thenAnswer((_) async => Success(settled));

      ledger.syncInfo.add(
        SyncInfo(lastSuccessAt: testNow.add(const Duration(minutes: 6))),
      );
      await pumpEventQueue();

      expect(read().transaction!.status, TransactionStatus.completed);
      verifyZeroInteractions(ledger.quotes);
    },
  );

  group('MarketQuote.changeSincePercent', () {
    test('exact percentage from the trade price', () {
      expect(
        quote.changeSincePercent(const Money(40000000)),
        Decimal.parse('10'),
      );
      expect(
        quote.changeSincePercent(const Money(48000000)),
        Decimal.parse('-8.3333'),
      );
      expect(quote.changeSincePercent(Money.zero), isNull);
    });
  });
}
