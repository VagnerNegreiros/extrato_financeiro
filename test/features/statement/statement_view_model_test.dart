import 'dart:async';

import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/statement_filter.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';
import 'package:extrato_financeiro/features/statement/presentation/statement_state.dart';
import 'package:extrato_financeiro/features/statement/presentation/statement_view_model.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mocks.dart';
import '../../helpers/transaction_builder.dart';

void main() {
  late MockedLedger ledger;
  late ProviderContainer container;

  // 25 transactions, one per hour, newest first.
  final all = [
    for (var i = 0; i < 25; i++)
      credit(
        100 + i,
        at: DateTime.utc(2026, 11, 2, 14).subtract(Duration(hours: i)),
      ),
  ];
  final firstPage = TransactionPage(
    items: all.take(20).toList(),
    nextCursor: const PageCursor('p2'),
  );
  final secondPage = TransactionPage(items: all.skip(20).toList());

  setUpAll(registerDomainFallbacks);

  setUp(() {
    ledger = MockedLedger();
    when(
      () => ledger.transactions.getPage(
        any(),
        cursor: any(named: 'cursor'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((invocation) async {
      final cursor = invocation.namedArguments[#cursor] as PageCursor?;
      return Success(cursor == null ? firstPage : secondPage);
    });
    container = ledger.container();
  });

  tearDown(() => ledger.dispose());

  StatementState read() => container.read(statementViewModelProvider);
  StatementViewModel viewModel() =>
      container.read(statementViewModelProvider.notifier);

  Future<void> start() async {
    container.listen(statementViewModelProvider, (_, _) {});
    await pumpEventQueue();
  }

  TransactionQuery lastQuery() =>
      verify(
            () => ledger.transactions.getPage(
              captureAny(),
              cursor: any(named: 'cursor'),
              pageSize: any(named: 'pageSize'),
            ),
          ).captured.last
          as TransactionQuery;

  test('loads the first page grouped by local day', () async {
    expect(read().content, StatementContent.loading);
    await start();

    final state = read();
    expect(state.content, StatementContent.ready);
    expect(state.items, firstPage.items);
    expect(state.hasMore, isTrue);
    // 20 hourly entries from 11:00 local back: 2 local days.
    expect(
      state.groups.map((g) => g.transactions.length).reduce((a, b) => a + b),
      20,
    );
    expect(state.groups.length, 2);
  });

  test('RN-21: loadMore appends the next page and stops at the end', () async {
    await start();
    await viewModel().loadMore();

    expect(read().items, all);
    expect(read().hasMore, isFalse);

    clearInteractions(ledger.transactions);
    await viewModel().loadMore();
    verifyNever(
      () => ledger.transactions.getPage(
        any(),
        cursor: any(named: 'cursor'),
        pageSize: any(named: 'pageSize'),
      ),
    );
  });

  test('concurrent loadMore calls make a single request', () async {
    await start();
    clearInteractions(ledger.transactions);

    await Future.wait([
      viewModel().loadMore(),
      viewModel().loadMore(),
      viewModel().loadMore(),
    ]);

    verify(
      () => ledger.transactions.getPage(
        any(),
        cursor: const PageCursor('p2'),
        pageSize: any(named: 'pageSize'),
      ),
    ).called(1);
  });

  test('a failed page keeps loaded items and can be retried', () async {
    await start();
    when(
      () => ledger.transactions.getPage(
        any(),
        cursor: const PageCursor('p2'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const Err(TimeoutFailure()));

    await viewModel().loadMore();
    expect(read().items, firstPage.items);
    expect(read().loadMoreFailure, const TimeoutFailure());
    expect(read().content, StatementContent.ready);

    when(
      () => ledger.transactions.getPage(
        any(),
        cursor: const PageCursor('p2'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => Success(secondPage));
    await viewModel().loadMore();
    expect(read().loadMoreFailure, isNull);
    expect(read().items, all);
  });

  test('RN-16/22: changing filters reloads from the first page', () async {
    await start();
    await viewModel().loadMore();
    final token = read().resetToken;

    await viewModel().setDirection(TransactionDirection.debit);
    expect(lastQuery().direction, TransactionDirection.debit);
    expect(read().items, firstPage.items);
    expect(read().resetToken, token + 1);

    await viewModel().toggleStatus(TransactionStatus.pending);
    await viewModel().setPeriod(PeriodSelection.last7Days);
    final query = lastQuery();
    expect(query.statuses, {TransactionStatus.pending});
    expect(query.range!.duration, const Duration(days: 7));
    expect(read().filter.activeCount, 3);

    await viewModel().toggleStatus(TransactionStatus.pending);
    expect(read().filter.statuses, isEmpty);
  });

  test('applying the same filter again does not reload', () async {
    await start();
    clearInteractions(ledger.transactions);
    await viewModel().applyFilter(StatementFilter.initial);
    verifyNever(
      () => ledger.transactions.getPage(
        any(),
        cursor: any(named: 'cursor'),
        pageSize: any(named: 'pageSize'),
      ),
    );
  });

  test('responses of superseded filters are discarded', () async {
    await start();
    final slow = Completer<Result<TransactionPage>>();
    final pages = [
      slow.future,
      Future.value(Success(secondPage) as Result<TransactionPage>),
    ];
    when(
      () => ledger.transactions.getPage(
        any(),
        cursor: any(named: 'cursor'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) => pages.removeAt(0));

    final first = viewModel().setDirection(TransactionDirection.credit);
    final second = viewModel().setDirection(TransactionDirection.debit);
    await second;
    slow.complete(Success(firstPage));
    await first;

    expect(read().filter.direction, TransactionDirection.debit);
    expect(read().items, secondPage.items);
  });

  test(
    'a page from an old filter is not appended after a filter change',
    () async {
      await start();
      final slowMore = Completer<Result<TransactionPage>>();
      when(
        () => ledger.transactions.getPage(
          any(),
          cursor: const PageCursor('p2'),
          pageSize: any(named: 'pageSize'),
        ),
      ).thenAnswer((_) => slowMore.future);

      final more = viewModel().loadMore();
      await viewModel().setDirection(TransactionDirection.debit);
      slowMore.complete(Success(secondPage));
      await more;

      expect(read().items, firstPage.items);
    },
  );

  test('RN-17: search is debounced and sends only the last term', () {
    fakeAsync((async) {
      container.listen(statementViewModelProvider, (_, _) {});
      async.flushMicrotasks();
      clearInteractions(ledger.transactions);

      viewModel()
        ..updateSearch('b')
        ..updateSearch('bt')
        ..updateSearch('btc');
      expect(read().filter.search, 'btc');

      async.elapse(const Duration(milliseconds: 399));
      verifyNever(
        () => ledger.transactions.getPage(
          any(),
          cursor: any(named: 'cursor'),
          pageSize: any(named: 'pageSize'),
        ),
      );

      async
        ..elapse(const Duration(milliseconds: 1))
        ..flushMicrotasks();
      expect(lastQuery().searchTerm, 'btc');
    });
  });

  test('search edits that do not change the term skip the query', () {
    fakeAsync((async) {
      container.listen(statementViewModelProvider, (_, _) {});
      async.flushMicrotasks();
      clearInteractions(ledger.transactions);

      viewModel().updateSearch('a'); // below the 2-character minimum
      async
        ..elapse(StatementViewModel.searchDebounce)
        ..flushMicrotasks();

      verifyNever(
        () => ledger.transactions.getPage(
          any(),
          cursor: any(named: 'cursor'),
          pageSize: any(named: 'pageSize'),
        ),
      );
    });
  });

  test('a sync with new data refreshes the loaded rows in place', () async {
    await start();
    await viewModel().loadMore();
    final token = read().resetToken;
    clearInteractions(ledger.transactions);

    ledger.syncInfo.add(SyncInfo(lastSuccessAt: DateTime.utc(2026, 11, 2, 16)));
    await pumpEventQueue();

    verify(() => ledger.transactions.getPage(any(), pageSize: 25)).called(1);
    expect(read().resetToken, token);
  });

  test('first page failure shows the error; retry recovers', () async {
    when(
      () => ledger.transactions.getPage(
        any(),
        cursor: any(named: 'cursor'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => const Err(CacheFailure()));
    await start();
    expect(read().content, StatementContent.error);
    expect(read().displayedFailure, const CacheFailure());

    when(
      () => ledger.transactions.getPage(
        any(),
        cursor: any(named: 'cursor'),
        pageSize: any(named: 'pageSize'),
      ),
    ).thenAnswer((_) async => Success(firstPage));
    await viewModel().retry();
    expect(read().content, StatementContent.ready);
  });

  test('refresh forces a sync', () async {
    await start();
    await viewModel().refresh();
    verify(() => ledger.transactions.sync(force: true)).called(1);
  });

  group('content', () {
    const empty = StatementState(status: StatementStatus.ready);

    test('empty with filters suggests clearing them', () {
      expect(
        empty
            .copyWith(
              filter: const StatementFilter(search: 'zz'),
              syncInfo: SyncInfo(lastSuccessAt: DateTime.utc(2026)),
            )
            .content,
        StatementContent.emptyFiltered,
      );
    });

    test('empty without data depends on the first sync', () {
      expect(empty.content, StatementContent.loading);
      expect(
        empty
            .copyWith(syncInfo: const SyncInfo(lastFailure: NetworkFailure()))
            .content,
        StatementContent.offline,
      );
      expect(
        empty
            .copyWith(syncInfo: const SyncInfo(lastFailure: ServerFailure()))
            .content,
        StatementContent.error,
      );
      expect(
        empty
            .copyWith(syncInfo: SyncInfo(lastSuccessAt: DateTime.utc(2026)))
            .content,
        StatementContent.empty,
      );
      expect(const StatementState().displayedFailure, isA<UnexpectedFailure>());
    });
  });
}
