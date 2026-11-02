import 'dart:async';

import 'package:extrato_financeiro/app/app.dart';
import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/app/sync_coordinator.dart';
import 'package:extrato_financeiro/core/connectivity/connectivity_service.dart';
import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/sync_ledger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fake_market.dart';
import '../helpers/mocks.dart';
import '../helpers/test_app.dart';

/// Connectivity whose state the test controls.
final class ControllableConnectivity implements ConnectivityService {
  new({this.online = true});

  bool online;
  final _changes = StreamController<bool>.broadcast();

  void set({required bool online}) {
    this.online = online;
    _changes.add(online);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> watchOnline() => _changes.stream;
}

void main() {
  setUpAll(() async {
    await initTestLocale();
    registerDomainFallbacks();
  });

  group('SyncCoordinator', () {
    late MockTransactionRepository repository;
    late ControllableConnectivity connectivity;
    late SyncCoordinator coordinator;

    setUp(() {
      repository = MockTransactionRepository();
      when(() => repository.sync(force: any(named: 'force')))
          .thenAnswer((_) async => Success(SyncInfo(lastSuccessAt: testNow)));
      connectivity = ControllableConnectivity();
      coordinator = SyncCoordinator(
        syncLedger: SyncLedger(repository),
        connectivity: connectivity,
        logger: const AppLogger(enabled: false),
      );
    });

    tearDown(() => coordinator.dispose());

    test('RN-26: start syncs once, respecting the TTL', () async {
      coordinator
        ..start()
        ..start();
      await pumpEventQueue();
      verify(() => repository.sync()).called(1);
    });

    test('connectivity coming back triggers a sync', () async {
      coordinator.start();
      await pumpEventQueue();
      clearInteractions(repository);

      connectivity.set(online: false);
      await pumpEventQueue();
      verifyNever(() => repository.sync(force: any(named: 'force')));

      connectivity.set(online: true);
      await pumpEventQueue();
      verify(() => repository.sync()).called(1);
    });

    test('refresh forces the sync', () async {
      await coordinator.refresh();
      verify(() => repository.sync(force: true)).called(1);
    });
  });

  group('end to end', () {
    testWidgets('going offline shows the banner over cached data', (
      tester,
    ) async {
      final connectivity = ControllableConnectivity();
      await tester.pumpWidget(
        ProviderScope(
          overrides: await appTestOverrides(connectivity: connectivity),
          child: const FluxoApp(),
        ),
      );
      await settle(tester);
      expect(find.textContaining('offline'), findsNothing);

      connectivity.set(online: false);
      await settle(tester);

      expect(find.textContaining('Você está offline'), findsOneWidget);
      expect(find.text('Saldo disponível'), findsOneWidget);
    });

    testWidgets('RN-25: old cache is flagged as possibly outdated', (
      tester,
    ) async {
      final clock = FixedClock(testNow);
      final market = CountingMarket(instantFakeMarket(clock));
      await tester.pumpWidget(
        ProviderScope(
          overrides: await appTestOverrides(clock: clock, market: market),
          child: const FluxoApp(),
        ),
      );
      await settle(tester);

      // 20 minutes later the API is rate limiting us.
      clock.advance(const Duration(minutes: 20));
      market.errorToThrow = Exception('429');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      unawaited(container.read(syncCoordinatorProvider).syncIfNeeded());
      await settle(tester);

      expect(
        find.textContaining('Exibindo dados de 02/11/2026 às 12:00'),
        findsOneWidget,
      );
    });

    testWidgets('returning to the foreground syncs when the TTL expired', (
      tester,
    ) async {
      final clock = FixedClock(testNow);
      final market = CountingMarket(instantFakeMarket(clock));
      await tester.pumpWidget(
        ProviderScope(
          overrides: await appTestOverrides(clock: clock, market: market),
          child: const FluxoApp(),
        ),
      );
      await settle(tester);
      expect(market.chartCalls, 3);

      // Lifecycle states must follow the platform's valid transitions.
      void backgroundAndReturn() {
        for (final state in const [
          AppLifecycleState.inactive,
          AppLifecycleState.hidden,
          AppLifecycleState.paused,
          AppLifecycleState.hidden,
          AppLifecycleState.inactive,
          AppLifecycleState.resumed,
        ]) {
          tester.binding.handleAppLifecycleStateChanged(state);
        }
      }

      backgroundAndReturn();
      await settle(tester);
      expect(market.chartCalls, 3, reason: 'cache still fresh');

      clock.advance(SyncInfo.ttl);
      backgroundAndReturn();
      await settle(tester);
      expect(market.chartCalls, 6);
    });
  });
}
