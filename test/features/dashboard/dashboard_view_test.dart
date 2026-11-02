import 'dart:async';

import 'package:extrato_financeiro/app/app.dart';
import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:extrato_financeiro/core/money/money_formatter.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/core/security/biometric_authenticator.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/data/datasources/fake_market_data_source.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/preferences/data/preferences_repository_impl.dart';
import 'package:extrato_financeiro/shared/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_market.dart';
import '../../helpers/mocks.dart';
import '../../helpers/test_app.dart';

void main() {
  setUpAll(() async {
    await initTestLocale();
    registerDomainFallbacks();
  });

  Future<void> pumpApp(WidgetTester tester, List<Override> overrides) async {
    await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: const FluxoApp()),
    );
    await settle(tester);
  }

  testWidgets('shows balance, period summary and recent transactions', (
    tester,
  ) async {
    await pumpApp(tester, await appTestOverrides());

    expect(find.text('Saldo disponível'), findsOneWidget);
    expect(find.text('Movimentação do período'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Gráfico de entradas')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(find.text('Últimas transações'), 200);
    expect(find.byType(TransactionTile), findsWidgets);
  });

  testWidgets('RN-29: hiding the balance masks values and is persisted', (
    tester,
  ) async {
    await pumpApp(tester, await appTestOverrides());

    await tester.tap(find.byTooltip('Ocultar saldo'));
    await tester.pumpAndSettle();

    expect(find.text(MoneyFormatter.obscured), findsWidgets);
    expect(find.byTooltip('Exibir saldo'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PreferencesRepositoryImpl.balanceVisibleKey), isFalse);
  });

  testWidgets('RN-30: failed authentication keeps the balance hidden', (
    tester,
  ) async {
    await pumpApp(
      tester,
      await appTestOverrides(
        biometrics: const FakeBiometrics(BiometricResult.denied),
        preferences: {PreferencesRepositoryImpl.balanceVisibleKey: false},
      ),
    );

    await tester.tap(find.byTooltip('Exibir saldo'));
    await tester.pump();

    expect(find.byTooltip('Exibir saldo'), findsOneWidget);
    expect(find.textContaining('identidade não confirmada'), findsOneWidget);
  });

  testWidgets('starts hidden when the preference says so', (tester) async {
    await pumpApp(
      tester,
      await appTestOverrides(
        preferences: {PreferencesRepositoryImpl.balanceVisibleKey: false},
      ),
    );
    expect(find.byTooltip('Exibir saldo'), findsOneWidget);
  });

  testWidgets('RN-27: first launch offline shows the no-connection state', (
    tester,
  ) async {
    final clock = FixedClock(testNow);
    await pumpApp(
      tester,
      await appTestOverrides(
        clock: clock,
        market: instantFakeMarket(clock, failure: FakeFailure.network),
      ),
    );

    expect(find.text('Sem conexão'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('a rate-limited first sync explains the wait', (tester) async {
    final clock = FixedClock(testNow);
    await pumpApp(
      tester,
      await appTestOverrides(
        clock: clock,
        market: instantFakeMarket(clock, failure: FakeFailure.rateLimit),
      ),
    );

    expect(find.text('Muitas requisições'), findsOneWidget);
    expect(find.textContaining('30 segundos'), findsOneWidget);
  });

  testWidgets('shows a skeleton while the first sync runs', (tester) async {
    final clock = FixedClock(testNow);
    final gate = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: await appTestOverrides(
          clock: clock,
          market: FakeMarketDataSource(clock: clock, sleep: (_) => gate.future),
        ),
        child: const FluxoApp(),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Carregando'), findsOneWidget);
    gate.complete();
    await settle(tester);
    expect(find.text('Saldo disponível'), findsOneWidget);
  });

  testWidgets('RN-09: synced but no transactions shows the empty state', (
    tester,
  ) async {
    final ledger = MockedLedger();
    when(ledger.transactions.getAll).thenAnswer((_) async => const Success([]));
    when(ledger.transactions.watchSyncInfo)
        .thenAnswer((_) => Stream.value(SyncInfo(lastSuccessAt: testNow)));
    await pumpApp(tester, [
      ...await appTestOverrides(),
      ...ledger.repositoryOverrides,
    ]);

    await tester.scrollUntilVisible(find.text('Nenhuma transação ainda'), 200);
    expect(find.text('Nenhuma transação ainda'), findsOneWidget);
    expect(find.text(r'R$ 0,00'), findsWidgets);
    await ledger.dispose();
  });

  testWidgets('"Ver extrato completo" opens the statement', (tester) async {
    await pumpApp(tester, await appTestOverrides());

    await tester.scrollUntilVisible(find.text('Ver extrato completo'), 200);
    await tester.tap(find.text('Ver extrato completo'));
    await settle(tester);

    expect(find.text('Extrato'), findsWidgets);
  });

  testWidgets('pull-to-refresh failure keeps data and explains why', (
    tester,
  ) async {
    final clock = FixedClock(testNow);
    final market = CountingMarket(instantFakeMarket(clock));
    await pumpApp(tester, await appTestOverrides(clock: clock, market: market));
    expect(find.text('Saldo disponível'), findsOneWidget);

    market.errorToThrow = Exception('offline');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    unawaited(container.read(syncCoordinatorProvider).refresh());
    await settle(tester);

    expect(find.text('Saldo disponível'), findsOneWidget);
    expect(find.textContaining('Exibindo dados de'), findsOneWidget);
  });

  testWidgets('dev config default is valid', (tester) async {
    expect(
      AppConfig.parse(
        flavor: 'dev',
        coinGeckoBaseUrl: 'https://x.test',
        coinGeckoApiKey: '',
        fakeFailure: 'none',
      ).usesFakeData,
      isTrue,
    );
  });
}
