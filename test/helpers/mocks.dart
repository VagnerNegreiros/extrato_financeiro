import 'dart:async';

import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/core/connectivity/connectivity_service.dart';
import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/core/security/biometric_authenticator.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/market_quote_repository.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/transaction_repository.dart';
import 'package:extrato_financeiro/features/preferences/domain/preferences_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:mocktail/mocktail.dart';

import 'test_app.dart';

class MockTransactionRepository extends Mock implements TransactionRepository;

class MockPreferencesRepository extends Mock implements PreferencesRepository;

class MockMarketQuoteRepository extends Mock implements MarketQuoteRepository;

void registerDomainFallbacks() {
  registerFallbackValue(TransactionQuery.all);
  registerFallbackValue(const PageCursor(''));
}

/// Mocked repositories plus a controllable sync stream, for ViewModel tests
/// that need precise control over timing and results.
final class MockedLedger {
  new({
    Clock? clock,
    this.biometrics = const FakeBiometrics(BiometricResult.unavailable),
  }) : clock = clock ?? FixedClock(testNow) {
    when(transactions.watchSyncInfo).thenAnswer((_) => syncInfo.stream);
    when(() => transactions.sync(force: any(named: 'force'))).thenAnswer(
      (_) async => Success(SyncInfo(lastSuccessAt: this.clock.nowUtc())),
    );
    when(preferences.isBalanceVisible)
        .thenAnswer((_) async => const Success(true));
    when(() => preferences.setBalanceVisible(visible: any(named: 'visible')))
        .thenAnswer((_) async => const Success(null));
  }

  final Clock clock;
  final BiometricAuthenticator biometrics;
  final transactions = MockTransactionRepository();
  final preferences = MockPreferencesRepository();
  final quotes = MockMarketQuoteRepository();
  final syncInfo = StreamController<SyncInfo>.broadcast();

  /// Cache already synced and nothing on the dashboard, for tests of the
  /// screens opened from it.
  void stubSyncedCache() {
    when(transactions.getAll).thenAnswer((_) async => const Success([]));
    when(transactions.watchSyncInfo)
        .thenAnswer((_) => Stream.value(SyncInfo(lastSuccessAt: testNow)));
  }

  /// Only the repositories, to combine with `appTestOverrides`.
  List<Override> get repositoryOverrides => [
    transactionRepositoryProvider.overrideWithValue(transactions),
    preferencesRepositoryProvider.overrideWithValue(preferences),
    marketQuoteRepositoryProvider.overrideWithValue(quotes),
  ];

  List<Override> get overrides => [
    ...repositoryOverrides,
    clockProvider.overrideWithValue(clock),
    localCalendarProvider.overrideWithValue(testCalendar),
    loggerProvider.overrideWithValue(const AppLogger(enabled: false)),
    connectivityProvider.overrideWithValue(const AlwaysOnlineConnectivity()),
    biometricAuthenticatorProvider.overrideWithValue(biometrics),
  ];

  ProviderContainer container() => ProviderContainer.test(overrides: overrides);

  Future<void> dispose() => syncInfo.close();
}
