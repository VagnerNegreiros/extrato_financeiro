import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/core/time/date_range.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/market_quote.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/statement_filter.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/market_quote_repository.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/transaction_repository.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/get_current_quote.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/get_dashboard_summary.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/get_statement_page.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/get_transaction_details.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/sync_ledger.dart';
import 'package:extrato_financeiro/features/preferences/domain/balance_visibility.dart';
import 'package:extrato_financeiro/features/preferences/domain/preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/transaction_builder.dart';

class _MockTransactionRepository extends Mock implements TransactionRepository;

class _MockQuoteRepository extends Mock implements MarketQuoteRepository;

class _MockPreferencesRepository extends Mock implements PreferencesRepository;

void main() {
  final saoPaulo = OffsetLocalCalendar.fixed(const Duration(hours: -3));
  // 22:30 on 31/10 local.
  final clock = FixedClock(DateTime.utc(2026, 11, 1, 1, 30));
  late _MockTransactionRepository repository;

  setUpAll(() {
    registerFallbackValue(TransactionQuery.all);
  });

  setUp(() => repository = _MockTransactionRepository());

  group('GetDashboardSummary', () {
    late GetDashboardSummary useCase;

    setUp(() {
      useCase = GetDashboardSummary(
        repository: repository,
        clock: clock,
        calendar: saoPaulo,
      );
    });

    test(
      'derives balance, totals, chart and recent from one snapshot',
      () async {
        final transactions = [
          credit(100000, at: DateTime.utc(2026, 8)), // before the period
          credit(5000, at: DateTime.utc(2026, 10, 30, 12)),
          debit(2000, at: DateTime.utc(2026, 11, 1, 1)), // 31/10 local
          debit(
            700,
            at: DateTime.utc(2026, 10, 29, 12),
            status: TransactionStatus.pending,
          ),
          credit(
            300,
            at: DateTime.utc(2026, 10, 28, 12),
            status: TransactionStatus.failed,
          ),
          debit(100, at: DateTime.utc(2026, 10, 27, 12)),
        ];
        when(() => repository.getAll())
            .thenAnswer((_) async => Success(transactions));

        final summary = (await useCase(PeriodSelection.last7Days)).valueOrNull!;

        expect(summary.balance.available, const Money(102200));
        expect(summary.totals.income, const Money(5000));
        expect(summary.totals.expenses, const Money(2100));
        expect(summary.firstDay, CalendarDate(2026, 10, 25));
        expect(summary.lastDay, CalendarDate(2026, 10, 31));
        expect(summary.cashflow, hasLength(7));
        expect(summary.cashflow.last.totals.expenses, const Money(2000));
        expect(summary.recent, hasLength(GetDashboardSummary.recentCount));
        expect(summary.recent.first, transactions[2]);
        expect(summary.isEmpty, isFalse);
        verify(() => repository.getAll()).called(1);
      },
    );

    test('chart and totals agree for the same period', () async {
      when(() => repository.getAll()).thenAnswer(
        (_) async => Success([
          for (var day = 1; day <= 31; day++)
            credit(day * 100, at: DateTime.utc(2026, 10, day, 15)),
        ]),
      );

      final summary = (await useCase(PeriodSelection.last30Days)).valueOrNull!;
      final chartIncome = summary.cashflow.fold(
        Money.zero,
        (sum, bucket) => sum + bucket.totals.income,
      );
      expect(chartIncome, summary.totals.income);
    });

    test('RN-09: empty ledger yields zeros', () async {
      when(() => repository.getAll())
          .thenAnswer((_) async => const Success([]));

      final summary = (await useCase(PeriodSelection.last30Days)).valueOrNull!;
      expect(summary.isEmpty, isTrue);
      expect(summary.balance.available, Money.zero);
      expect(summary.totals.net, Money.zero);
    });

    test('propagates repository failures', () async {
      when(() => repository.getAll())
          .thenAnswer((_) async => const Err(CacheFailure()));

      expect(
        await useCase(PeriodSelection.last30Days),
        const Err<Object>(CacheFailure()),
      );
    });
  });

  group('GetStatementPage', () {
    late GetStatementPage useCase;

    setUp(() {
      useCase = GetStatementPage(
        repository: repository,
        clock: clock,
        calendar: saoPaulo,
      );
    });

    test('resolves period and search into a query', () {
      final query = useCase.toQuery(
        const StatementFilter(
          direction: TransactionDirection.debit,
          statuses: {TransactionStatus.pending},
          period: PeriodSelection.last7Days,
          search: '  Depósito ',
        ),
      );

      expect(query.direction, TransactionDirection.debit);
      expect(query.statuses, {TransactionStatus.pending});
      expect(
        query.range,
        DateRange.localDays(
          CalendarDate(2026, 10, 25),
          CalendarDate(2026, 10, 31),
          saoPaulo,
        ),
      );
      expect(query.searchTerm, 'deposito');
    });

    test('short search is ignored', () {
      expect(
        useCase.toQuery(const StatementFilter(search: 'a')).searchTerm,
        isNull,
      );
    });

    test('passes cursor and page size to the repository', () async {
      const page = TransactionPage(items: []);
      when(
        () => repository.getPage(
          any(),
          cursor: any(named: 'cursor'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) async => const Success(page));

      final result = await useCase(
        StatementFilter.initial,
        cursor: const PageCursor('c1'),
        pageSize: 10,
      );

      expect(result, const Success(page));
      verify(
        () => repository.getPage(
          useCase.toQuery(StatementFilter.initial),
          cursor: const PageCursor('c1'),
          pageSize: 10,
        ),
      ).called(1);
    });
  });

  group('GetTransactionDetails', () {
    test('trims the id and reads from the repository', () async {
      final transaction = credit(100);
      when(() => repository.getById('TX-1'))
          .thenAnswer((_) async => Success(transaction));

      final result = await GetTransactionDetails(repository)(' TX-1 ');

      expect(result, Success(transaction));
    });

    test('RN-32: blank id is not found without hitting the cache', () async {
      final result = await GetTransactionDetails(repository)('  ');

      expect(result.failureOrNull, isA<NotFoundFailure>());
      verifyNever(() => repository.getById(any()));
    });
  });

  group('SyncLedger', () {
    test('forwards force and the sync stream', () async {
      final info = SyncInfo(lastSuccessAt: clock.nowUtc());
      when(() => repository.sync(force: true))
          .thenAnswer((_) async => Success(info));
      when(() => repository.watchSyncInfo())
          .thenAnswer((_) => Stream.value(info));

      final useCase = SyncLedger(repository);

      expect(await useCase(force: true), Success(info));
      expect(await useCase.watch().first, info);
    });
  });

  group('GetCurrentQuote', () {
    late _MockQuoteRepository quotes;

    setUp(() => quotes = _MockQuoteRepository());

    test('requests the quote of the traded asset with cancellation', () async {
      final quote = MarketQuote(
        assetId: 'bitcoin',
        price: const Money(35000000),
        fetchedAt: clock.nowUtc(),
      );
      final cancellation = Cancellation();
      when(() => quotes.getCurrentQuote('bitcoin', cancellation: cancellation))
          .thenAnswer((_) async => Success(quote));

      final trade = tx(
        cents: 100,
        metadata: const TransactionMetadata(
          assetId: 'bitcoin',
          assetSymbol: 'BTC',
        ),
      );

      expect(
        await GetCurrentQuote(quotes)(trade, cancellation: cancellation),
        Success(quote),
      );
    });

    test('transactions without an asset never hit the network', () async {
      final result = await GetCurrentQuote(quotes)(credit(100));

      expect(result.failureOrNull, isA<NotFoundFailure>());
      verifyZeroInteractions(quotes);
    });
  });

  group('RN-29: BalanceVisibility', () {
    late _MockPreferencesRepository preferences;

    setUp(() => preferences = _MockPreferencesRepository());

    test('loads the stored preference', () async {
      when(() => preferences.isBalanceVisible())
          .thenAnswer((_) async => const Success(false));

      expect(await BalanceVisibility(preferences).load(), isFalse);
    });

    test('defaults to visible when it cannot be read', () async {
      when(() => preferences.isBalanceVisible())
          .thenAnswer((_) async => const Err(CacheFailure()));

      expect(await BalanceVisibility(preferences).load(), isTrue);
    });

    test('saves the preference', () async {
      when(() => preferences.setBalanceVisible(visible: false))
          .thenAnswer((_) async => const Success(null));

      final result = await BalanceVisibility(preferences).save(visible: false);

      expect(result.isSuccess, isTrue);
      verify(() => preferences.setBalanceVisible(visible: false)).called(1);
    });
  });

  group('Cancellation', () {
    test('completes once and is idempotent', () async {
      final cancellation = Cancellation();
      expect(cancellation.isCancelled, isFalse);

      cancellation
        ..cancel()
        ..cancel();

      expect(cancellation.isCancelled, isTrue);
      await expectLater(cancellation.whenCancelled, completes);
    });
  });
}
