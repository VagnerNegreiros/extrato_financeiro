import 'dart:async';

import 'package:extrato_financeiro/app/app.dart';
import 'package:extrato_financeiro/app/router.dart';
import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/statement/presentation/statement_view.dart';
import 'package:extrato_financeiro/features/statement/presentation/statement_view_model.dart';
import 'package:extrato_financeiro/shared/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_market.dart';
import '../../helpers/test_app.dart';

/// The dashboard stays mounted below the statement, so finders are scoped.
Finder inStatement(Type type) => find.descendant(
  of: find.byType(StatementView),
  matching: find.byType(type),
);

void main() {
  setUpAll(initTestLocale);

  /// Opens the app directly on the statement.
  Future<ProviderContainer> pumpStatement(
    WidgetTester tester, {
    List<Override>? overrides,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides ?? await appTestOverrides(),
        child: const FluxoApp(),
      ),
    );
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    unawaited(container.read(routerProvider).pushNamed(AppRoute.statement));
    await settle(tester);
    return container;
  }

  Finder tilesWithSemantics(Pattern pattern) => find.byWidgetPredicate(
    (widget) =>
        widget is Semantics &&
        (widget.properties.label?.contains(pattern) ?? false),
  );

  testWidgets('lists transactions grouped by local day', (tester) async {
    await pumpStatement(tester);

    expect(find.text('Extrato'), findsOneWidget);
    expect(inStatement(TransactionTile), findsWidgets);
    expect(
      find.text('Hoje').evaluate().isNotEmpty ||
          find.text('Ontem').evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('RN-21: scrolling loads the next pages until the end', (
    tester,
  ) async {
    final container = await pumpStatement(tester);
    final firstCount = container.read(statementViewModelProvider).items.length;
    expect(firstCount, 20);

    await tester.fling(
      inStatement(CustomScrollView),
      const Offset(0, -3000),
      3000,
    );
    await settle(tester);

    expect(
      container.read(statementViewModelProvider).items.length,
      greaterThan(firstCount),
    );
  });

  testWidgets('RN-17: search filters by description after the debounce', (
    tester,
  ) async {
    final container = await pumpStatement(tester);

    await tester.enterText(find.byType(TextField), 'salario');
    await tester.pump(const Duration(milliseconds: 450));
    await settle(tester);

    final items = container.read(statementViewModelProvider).items;
    expect(items, isNotEmpty);
    expect(items.every((t) => t.description.contains('Salário')), isTrue);
  });

  testWidgets('empty result offers to clear the filters', (tester) async {
    await pumpStatement(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 450));
    await settle(tester);

    expect(find.text('Nenhuma transação encontrada'), findsOneWidget);
    await tester.tap(find.text('Limpar filtros'));
    await settle(tester);

    expect(inStatement(TransactionTile), findsWidgets);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('filter sheet applies combined filters at once', (tester) async {
    final container = await pumpStatement(tester);

    await tester.tap(find.byTooltip('Filtros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saídas'));
    await tester.tap(find.widgetWithText(FilterChip, 'Concluída'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await settle(tester);

    final state = container.read(statementViewModelProvider);
    expect(state.filter.activeCount, 2);
    expect(state.items, isNotEmpty);
    expect(state.items.every((t) => !t.isCredit), isTrue);
    expect(find.byTooltip('Filtros, 2 ativos'), findsOneWidget);
    expect(find.byType(InputChip), findsNWidgets(2));
    expect(tilesWithSemantics('Entrada,'), findsNothing);

    // Removing a chip reloads without that criterion.
    await tester.tap(find.byTooltip('Remover filtro de tipo'));
    await settle(tester);
    expect(container.read(statementViewModelProvider).filter.activeCount, 1);
  });

  testWidgets('RN-23: filters and scroll survive opening a transaction', (
    tester,
  ) async {
    final container = await pumpStatement(tester);
    await tester.enterText(find.byType(TextField), 'pix');
    await tester.pump(const Duration(milliseconds: 450));
    await settle(tester);
    await tester.drag(inStatement(CustomScrollView), const Offset(0, -300));
    await settle(tester);
    final offset = container
        .read(statementViewModelProvider.notifier)
        .savedScrollOffset;
    expect(offset, greaterThan(0));

    await tester.tap(inStatement(TransactionTile).hitTestable().first);
    await settle(tester);
    container.read(routerProvider).pop();
    await settle(tester);

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'pix',
    );
    final controller = tester
        .widget<CustomScrollView>(inStatement(CustomScrollView))
        .controller!;
    expect(controller.offset, offset);
  });

  testWidgets('RN-27: offline without cache shows the no-connection state', (
    tester,
  ) async {
    final clock = FixedClock(testNow);
    await pumpStatement(
      tester,
      overrides: await appTestOverrides(
        clock: clock,
        market: instantFakeMarket(clock, failure: FakeFailure.network),
      ),
    );

    expect(find.text('Sem conexão'), findsWidgets);
  });
}
