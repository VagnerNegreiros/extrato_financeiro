import 'dart:async';

import 'package:extrato_financeiro/app/app.dart';
import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/app/router.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/statement/presentation/statement_view.dart';
import 'package:extrato_financeiro/features/transaction_details/presentation/transaction_details_view.dart';
import 'package:extrato_financeiro/shared/widgets/amount_text.dart';
import 'package:extrato_financeiro/shared/widgets/state_views.dart';
import 'package:extrato_financeiro/shared/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/mocks.dart';
import '../../helpers/test_app.dart';
import '../../helpers/transaction_builder.dart';

void main() {
  setUpAll(() async {
    await initTestLocale();
    registerDomainFallbacks();
  });

  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    List<Override>? overrides,
  }) async {
    // Tall viewport so the whole details list is built at once.
    tester.view.physicalSize = const Size(1080, 4000);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides ?? await appTestOverrides(),
        child: const FluxoApp(),
      ),
    );
    await settle(tester);
    return ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
  }

  Future<Transaction> firstTrade(ProviderContainer container) async {
    final all = (await container.read(transactionRepositoryProvider).getAll())
        .valueOrNull!;
    return all.firstWhere((t) => t.category == TransactionCategory.cryptoBuy);
  }

  Finder inDetails(Finder finder) => find.descendant(
    of: find.byType(TransactionDetailsView),
    matching: finder,
  );

  testWidgets('shows every field and the current quote of the asset', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    final trade = await firstTrade(container);

    unawaited(
      container
          .read(routerProvider)
          .pushNamed(
            AppRoute.transactionDetails,
            pathParameters: {'id': trade.id},
          ),
    );
    await settle(tester);

    expect(find.text('Detalhes da transação'), findsOneWidget);
    expect(inDetails(find.text(trade.id)), findsOneWidget);
    for (final label in [
      'Data e hora',
      'Tipo',
      'Categoria',
      'Status',
      'Valor',
      'Ativo',
      'Quantidade',
      'Contraparte',
    ]) {
      expect(inDetails(find.text(label)), findsOneWidget, reason: label);
    }
    expect(inDetails(find.textContaining('Cotação atual do')), findsOneWidget);
    expect(find.textContaining('Últimas 24h'), findsOneWidget);
    expect(find.textContaining('Desde a operação'), findsOneWidget);
  });

  testWidgets('RN-31: copies the id and confirms it', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      },
    );
    final container = await pumpApp(tester);
    final trade = await firstTrade(container);
    unawaited(
      container
          .read(routerProvider)
          .pushNamed(
            AppRoute.transactionDetails,
            pathParameters: {'id': trade.id},
          ),
    );
    await settle(tester);

    await tester.tap(find.byTooltip('Copiar identificador'));
    await tester.pump();

    expect(copied, [trade.id]);
    expect(find.text('Identificador copiado'), findsOneWidget);
  });

  testWidgets('amount and status are identical in the statement and details', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    unawaited(container.read(routerProvider).pushNamed(AppRoute.statement));
    await settle(tester);

    final tile = tester.widget<TransactionTile>(
      find
          .descendant(
            of: find.byType(StatementView),
            matching: find.byType(TransactionTile),
          )
          .first,
    );
    final tileAmount = tester
        .widget<Text>(
          find.descendant(
            of: find.byWidget(tile),
            matching: find.descendant(
              of: find.byType(AmountText),
              matching: find.byType(Text),
            ),
          ),
        )
        .data;

    await tester.tap(find.byWidget(tile));
    await settle(tester);

    expect(inDetails(find.text(tileAmount!)), findsWidgets);
    expect(inDetails(find.text(tile.transaction.description)), findsOneWidget);
    expect(inDetails(find.text(tile.transaction.id)), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await settle(tester);
    expect(find.byType(StatementView), findsOneWidget);
  });

  testWidgets('deep link to an unknown id shows "not found" and goes home', (
    tester,
  ) async {
    final container = await pumpApp(tester);
    container.read(routerProvider).go('/transacao/TX-00000000-00');
    await settle(tester);

    expect(find.text('Transação não encontrada'), findsOneWidget);
    await tester.tap(find.text('Voltar'));
    await settle(tester);
    expect(find.text('Saldo disponível'), findsOneWidget);
  });

  /// Opens the details of [id] over a synced cache answered by [load].
  Future<MockedLedger> openWithMockedCache(
    WidgetTester tester,
    String id,
    Future<Result<Transaction>> Function() load,
  ) async {
    final ledger = MockedLedger()..stubSyncedCache();
    when(() => ledger.transactions.getById(id)).thenAnswer((_) => load());
    final container = await pumpApp(
      tester,
      overrides: [...await appTestOverrides(), ...ledger.repositoryOverrides],
    );
    unawaited(
      container
          .read(routerProvider)
          .pushNamed(AppRoute.transactionDetails, pathParameters: {'id': id}),
    );
    await settle(tester);
    return ledger;
  }

  testWidgets('shows a skeleton while the transaction loads', (tester) async {
    final transaction = credit(1000);
    final gate = Completer<Result<Transaction>>();
    final ledger = await openWithMockedCache(
      tester,
      transaction.id,
      () => gate.future,
    );

    expect(inDetails(find.byType(LoadingView)), findsOneWidget);
    expect(inDetails(find.text(transaction.id)), findsNothing);

    gate.complete(Success(transaction));
    await settle(tester);

    expect(inDetails(find.byType(LoadingView)), findsNothing);
    expect(inDetails(find.text(transaction.id)), findsOneWidget);
    await ledger.dispose();
  });

  testWidgets('a failed read explains the error and can be retried', (
    tester,
  ) async {
    final transaction = credit(1000);
    var failing = true;
    final ledger = await openWithMockedCache(
      tester,
      transaction.id,
      () async => failing ? const Err(CacheFailure()) : Success(transaction),
    );

    expect(inDetails(find.text('Erro ao ler os dados')), findsOneWidget);

    failing = false;
    await tester.tap(inDetails(find.text('Tentar novamente')));
    await settle(tester);

    expect(inDetails(find.text('Erro ao ler os dados')), findsNothing);
    expect(inDetails(find.text(transaction.id)), findsOneWidget);
    await ledger.dispose();
  });
}
