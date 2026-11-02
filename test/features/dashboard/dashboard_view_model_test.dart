import 'dart:async';

import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/core/security/biometric_authenticator.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/features/dashboard/presentation/dashboard_state.dart';
import 'package:extrato_financeiro/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/dashboard_summary.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_totals.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mocks.dart';
import '../../helpers/test_app.dart';
import '../../helpers/transaction_builder.dart';

void main() {
  late MockedLedger ledger;
  late ProviderContainer container;
  final transactions = [
    credit(100000, at: DateTime.utc(2026, 11, 1, 15)),
    debit(2500, at: DateTime.utc(2026, 11, 2, 12)),
  ];

  setUpAll(registerDomainFallbacks);

  setUp(() {
    ledger = MockedLedger();
    when(() => ledger.transactions.getAll())
        .thenAnswer((_) async => Success(transactions));
    container = ledger.container();
  });

  tearDown(() => ledger.dispose());

  DashboardState read() => container.read(dashboardViewModelProvider);
  DashboardViewModel viewModel() =>
      container.read(dashboardViewModelProvider.notifier);

  Future<void> start() async {
    container.listen(dashboardViewModelProvider, (_, _) {});
    await pumpEventQueue();
  }

  test('loads the stored visibility and the summary from the cache', () async {
    when(() => ledger.preferences.isBalanceVisible())
        .thenAnswer((_) async => const Success(false));

    expect(read().content, DashboardContent.loading);
    await start();

    final state = read();
    expect(state.isBalanceVisible, isFalse);
    expect(state.summary!.balance.available, const Money(97500));
    expect(state.summary!.recent.first, transactions[1]);
  });

  test('RN-29: toggling the balance persists the choice', () async {
    await start();
    await viewModel().toggleBalanceVisibility();

    expect(read().isBalanceVisible, isFalse);
    verify(() => ledger.preferences.setBalanceVisible(visible: false))
        .called(1);
  });

  group('RN-30: revealing the balance', () {
    ProviderContainer withBiometrics(BiometricResult result) {
      ledger = MockedLedger(biometrics: FakeBiometrics(result));
      when(() => ledger.preferences.isBalanceVisible())
          .thenAnswer((_) async => const Success(false));
      when(() => ledger.transactions.getAll())
          .thenAnswer((_) async => Success(transactions));
      return container = ledger.container();
    }

    test('requires authentication when the device supports it', () async {
      withBiometrics(BiometricResult.denied);
      await start();

      expect(await viewModel().toggleBalanceVisibility(), isFalse);
      expect(read().isBalanceVisible, isFalse);
      verifyNever(
        () => ledger.preferences.setBalanceVisible(
          visible: any(named: 'visible'),
        ),
      );
    });

    test('reveals after a successful authentication', () async {
      withBiometrics(BiometricResult.authenticated);
      await start();

      expect(await viewModel().toggleBalanceVisibility(), isTrue);
      expect(read().isBalanceVisible, isTrue);
      verify(() => ledger.preferences.setBalanceVisible(visible: true))
          .called(1);
    });

    test('reveals directly on devices without a lock screen', () async {
      withBiometrics(BiometricResult.unavailable);
      await start();

      expect(await viewModel().toggleBalanceVisibility(), isTrue);
      expect(read().isBalanceVisible, isTrue);
    });

    test('hiding never asks for authentication', () async {
      withBiometrics(BiometricResult.denied);
      when(() => ledger.preferences.isBalanceVisible())
          .thenAnswer((_) async => const Success(true));
      await start();

      expect(await viewModel().toggleBalanceVisibility(), isTrue);
      expect(read().isBalanceVisible, isFalse);
    });
  });

  test('changing the period reloads; stale results are discarded', () async {
    await start();
    final slow = Completer<Result<List<Transaction>>>();
    final fast = Completer<Result<List<Transaction>>>();
    final answers = [slow, fast];
    when(() => ledger.transactions.getAll())
        .thenAnswer((_) => answers.removeAt(0).future);

    final first = viewModel().selectPeriod(PeriodSelection.last7Days);
    final second = viewModel().selectPeriod(PeriodSelection.last90Days);
    fast.complete(Success(transactions));
    await second;
    slow.complete(Success(transactions));
    await first;

    expect(read().period, PeriodSelection.last90Days);
    expect(read().summary!.firstDay, CalendarDate(2026, 11, 2).addDays(-89));
  });

  test('selecting the same period does nothing', () async {
    await start();
    clearInteractions(ledger.transactions);
    await viewModel().selectPeriod(PeriodSelection.defaultPeriod);
    verifyNever(() => ledger.transactions.getAll());
  });

  test('a sync with new data reloads the summary', () async {
    await start();
    clearInteractions(ledger.transactions);

    ledger.syncInfo.add(const SyncInfo(isSyncing: true));
    await pumpEventQueue();
    verifyNever(() => ledger.transactions.getAll());
    expect(read().syncInfo.isSyncing, isTrue);

    ledger.syncInfo.add(SyncInfo(lastSuccessAt: testNow));
    await pumpEventQueue();
    verify(() => ledger.transactions.getAll()).called(1);
  });

  test('refresh forces a sync', () async {
    await start();
    final result = await viewModel().refresh();

    expect(result.isSuccess, isTrue);
    verify(() => ledger.transactions.sync(force: true)).called(1);
  });

  test('a cache failure shows the error and retry reloads', () async {
    when(() => ledger.transactions.getAll())
        .thenAnswer((_) async => const Err(CacheFailure()));
    await start();
    expect(read().content, DashboardContent.error);
    expect(read().displayedFailure, const CacheFailure());

    when(() => ledger.transactions.getAll())
        .thenAnswer((_) async => Success(transactions));
    await viewModel().retry();
    expect(read().content, DashboardContent.ready);
  });

  group('content (RN-09/27)', () {
    final empty = DashboardSummary(
      balance: BalanceBreakdown.empty,
      totals: PeriodTotals.empty,
      cashflow: const [],
      recent: const [],
      firstDay: CalendarDate(2026, 10, 4),
      lastDay: CalendarDate(2026, 11, 2),
    );

    DashboardContent content(SyncInfo info, {Failure? failure}) =>
        DashboardState(
          summary: empty,
          syncInfo: info,
          failure: failure,
        ).content;

    test('empty cache before the first sync is still loading', () {
      expect(content(SyncInfo.never), DashboardContent.loading);
      expect(
        content(const SyncInfo(isSyncing: true)),
        DashboardContent.loading,
      );
    });

    test('first sync failures: offline or error', () {
      expect(
        content(const SyncInfo(lastFailure: NetworkFailure())),
        DashboardContent.offline,
      );
      expect(
        content(const SyncInfo(lastFailure: RateLimitFailure())),
        DashboardContent.error,
      );
      expect(
        const DashboardState(
          syncInfo: SyncInfo(lastFailure: RateLimitFailure()),
        ).copyWith(summary: empty).displayedFailure,
        const RateLimitFailure(),
      );
    });

    test('synced with no transactions is empty, not an error', () {
      expect(content(SyncInfo(lastSuccessAt: testNow)), DashboardContent.empty);
    });

    test('unknown failure fallback', () {
      expect(const DashboardState().displayedFailure, isA<UnexpectedFailure>());
    });
  });
}
