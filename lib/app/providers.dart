import 'package:dio/dio.dart';
import 'package:extrato_financeiro/app/sync_coordinator.dart';
import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:extrato_financeiro/core/connectivity/connectivity_service.dart';
import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:extrato_financeiro/core/money/money_formatter.dart';
import 'package:extrato_financeiro/core/network/dio_factory.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/core/time/date_formatter.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:extrato_financeiro/features/ledger/data/datasources/fake_market_data_source.dart';
import 'package:extrato_financeiro/features/ledger/data/datasources/market_data_source.dart';
import 'package:extrato_financeiro/features/ledger/data/local/app_database.dart';
import 'package:extrato_financeiro/features/ledger/data/local/ledger_local_data_source.dart';
import 'package:extrato_financeiro/features/ledger/data/repositories/market_quote_repository_impl.dart';
import 'package:extrato_financeiro/features/ledger/data/repositories/transaction_repository_impl.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/market_quote_repository.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/transaction_repository.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/get_current_quote.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/get_dashboard_summary.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/get_statement_page.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/get_transaction_details.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/sync_ledger.dart';
import 'package:extrato_financeiro/features/preferences/data/preferences_repository_impl.dart';
import 'package:extrato_financeiro/features/preferences/domain/balance_visibility.dart';
import 'package:extrato_financeiro/features/preferences/domain/preferences_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Composition root. Every dependency is created here and only here, so
// tests and flavors swap implementations by overriding a provider.

// --- Platform & configuration (overridden in main/tests) -------------------

final appConfigProvider = Provider<AppConfig>(
  (ref) => throw UnimplementedError('appConfigProvider must be overridden'),
);

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not set'),
);

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(database.close);
  return database;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final localCalendarProvider = Provider<LocalCalendar>(
  (ref) => const DeviceLocalCalendar(),
);

final loggerProvider = Provider<AppLogger>((ref) => const AppLogger());

final connectivityProvider = Provider<ConnectivityService>(
  (ref) => ref.watch(appConfigProvider).usesFakeData
      ? const AlwaysOnlineConnectivity()
      : PluginConnectivityService(),
);

// --- Formatting -------------------------------------------------------------

final moneyFormatterProvider = Provider<MoneyFormatter>(
  (ref) => const MoneyFormatter(),
);

final dateFormatterProvider = Provider<AppDateFormatter>(
  (ref) => AppDateFormatter(
    calendar: ref.watch(localCalendarProvider),
    clock: ref.watch(clockProvider),
  ),
);

// --- Data -------------------------------------------------------------------

final dioProvider = Provider<Dio>((ref) {
  final dio = DioFactory.create(
    config: ref.watch(appConfigProvider),
    clock: ref.watch(clockProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});

final marketDataSourceProvider = Provider<MarketDataSource>((ref) {
  final config = ref.watch(appConfigProvider);
  final clock = ref.watch(clockProvider);
  return config.usesFakeData
      ? FakeMarketDataSource(clock: clock, failure: config.fakeFailure)
      : CoinGeckoMarketDataSource(dio: ref.watch(dioProvider), clock: clock);
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final repository = TransactionRepositoryImpl(
    local: LedgerLocalDataSource(ref.watch(appDatabaseProvider)),
    remote: ref.watch(marketDataSourceProvider),
    clock: ref.watch(clockProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final marketQuoteRepositoryProvider = Provider<MarketQuoteRepository>(
  (ref) => MarketQuoteRepositoryImpl(
    remote: ref.watch(marketDataSourceProvider),
    clock: ref.watch(clockProvider),
  ),
);

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepositoryImpl(ref.watch(sharedPreferencesProvider)),
);

// --- Use cases --------------------------------------------------------------

final getDashboardSummaryProvider = Provider<GetDashboardSummary>(
  (ref) => GetDashboardSummary(
    repository: ref.watch(transactionRepositoryProvider),
    clock: ref.watch(clockProvider),
    calendar: ref.watch(localCalendarProvider),
  ),
);

final getStatementPageProvider = Provider<GetStatementPage>(
  (ref) => GetStatementPage(
    repository: ref.watch(transactionRepositoryProvider),
    clock: ref.watch(clockProvider),
    calendar: ref.watch(localCalendarProvider),
  ),
);

final getTransactionDetailsProvider = Provider<GetTransactionDetails>(
  (ref) => GetTransactionDetails(ref.watch(transactionRepositoryProvider)),
);

final getCurrentQuoteProvider = Provider<GetCurrentQuote>(
  (ref) => GetCurrentQuote(ref.watch(marketQuoteRepositoryProvider)),
);

final syncLedgerProvider = Provider<SyncLedger>(
  (ref) => SyncLedger(ref.watch(transactionRepositoryProvider)),
);

final balanceVisibilityProvider = Provider<BalanceVisibility>(
  (ref) => BalanceVisibility(ref.watch(preferencesRepositoryProvider)),
);

// --- App-wide state ---------------------------------------------------------

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  final coordinator = SyncCoordinator(
    syncLedger: ref.watch(syncLedgerProvider),
    connectivity: ref.watch(connectivityProvider),
    logger: ref.watch(loggerProvider),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

/// Sync state shared by every screen (single source of truth for
/// "loading", "offline" and "outdated" indicators).
final syncInfoProvider = StreamProvider<SyncInfo>(
  (ref) => ref.watch(syncLedgerProvider).watch(),
);

final isOnlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = ref.watch(connectivityProvider);
  yield await connectivity.isOnline();
  yield* connectivity.watchOnline();
});
