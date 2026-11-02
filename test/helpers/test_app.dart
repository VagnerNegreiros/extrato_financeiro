import 'package:drift/native.dart';
import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:extrato_financeiro/core/connectivity/connectivity_service.dart';
import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:extrato_financeiro/features/ledger/data/datasources/market_data_source.dart';
import 'package:extrato_financeiro/features/ledger/data/local/app_database.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_market.dart';

/// UTC-3, like Brasília, independent of the machine running the tests.
final testCalendar = OffsetLocalCalendar.fixed(const Duration(hours: -3));

/// 12:00 local time on 2026-11-02.
DateTime get testNow => DateTime.utc(2026, 11, 2, 15);

Future<void> initTestLocale() async {
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
}

/// Overrides that run the real app stack offline and deterministically:
/// in-memory database, instant fake market, fixed clock and time zone.
Future<List<Override>> appTestOverrides({
  Clock? clock,
  MarketDataSource? market,
  ConnectivityService connectivity = const AlwaysOnlineConnectivity(),
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  final prefs = await SharedPreferences.getInstance();
  final effectiveClock = clock ?? FixedClock(testNow);
  return [
    appConfigProvider.overrideWithValue(
      AppConfig.parse(
        flavor: 'dev',
        coinGeckoBaseUrl: 'https://api.coingecko.com/api/v3',
        coinGeckoApiKey: '',
        fakeFailure: 'none',
      ),
    ),
    sharedPreferencesProvider.overrideWithValue(prefs),
    appDatabaseProvider.overrideWith((ref) {
      final database = AppDatabase(NativeDatabase.memory());
      ref.onDispose(database.close);
      return database;
    }),
    clockProvider.overrideWithValue(effectiveClock),
    localCalendarProvider.overrideWithValue(testCalendar),
    loggerProvider.overrideWithValue(const AppLogger(enabled: false)),
    connectivityProvider.overrideWithValue(connectivity),
    marketDataSourceProvider.overrideWithValue(
      market ?? instantFakeMarket(effectiveClock),
    ),
  ];
}

/// Lets drift and the fake market finish their asynchronous work.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
