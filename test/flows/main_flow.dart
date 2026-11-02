import 'package:extrato_financeiro/app/app.dart';
import 'package:extrato_financeiro/core/money/money_formatter.dart';
import 'package:extrato_financeiro/features/statement/presentation/statement_view.dart';
import 'package:extrato_financeiro/features/transaction_details/presentation/transaction_details_view.dart';
import 'package:extrato_financeiro/shared/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

/// Main user journey, shared by the widget test (runs on every `flutter
/// test`) and the integration test (runs on a device in CI):
///
/// dashboard → hide balance → statement → filter "Saídas" + search "btc" →
/// scroll → details → copy id → back (filters and scroll kept) → home →
/// restart the app (balance still hidden).
Future<void> runMainFlow(WidgetTester tester) async {
  await initTestLocale();
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

  await tester.pumpWidget(
    ProviderScope(overrides: await appTestOverrides(), child: const FluxoApp()),
  );
  await settle(tester);

  // Dashboard: hide the balance.
  expect(find.text('Saldo disponível'), findsOneWidget);
  await tester.tap(find.byTooltip('Ocultar saldo'));
  await tester.pumpAndSettle();
  expect(find.text(MoneyFormatter.obscured), findsWidgets);

  // Statement with combined filters.
  await tester.scrollUntilVisible(find.text('Ver extrato completo'), 200);
  await tester.tap(find.text('Ver extrato completo'));
  await settle(tester);
  expect(find.byType(StatementView), findsOneWidget);

  await tester.tap(find.byTooltip('Filtros'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Saídas'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Aplicar'));
  await settle(tester);

  await tester.enterText(find.byType(TextField), 'btc');
  await tester.pump(const Duration(milliseconds: 450));
  await settle(tester);

  final tiles = find.descendant(
    of: find.byType(StatementView),
    matching: find.byType(TransactionTile),
  );
  expect(tiles, findsWidgets);
  for (final tile in tester.widgetList<TransactionTile>(tiles)) {
    expect(tile.transaction.isCredit, isFalse);
    expect(tile.transaction.description, contains('BTC'));
  }

  // Scroll a bit, open a transaction and copy its id.
  final scrollView = find.descendant(
    of: find.byType(StatementView),
    matching: find.byType(CustomScrollView),
  );
  await tester.drag(scrollView, const Offset(0, -200));
  await settle(tester);
  final offset = tester.widget<CustomScrollView>(scrollView).controller!.offset;

  final tile = tester.widget<TransactionTile>(tiles.hitTestable().first);
  await tester.tap(tiles.hitTestable().first);
  await settle(tester);
  expect(find.byType(TransactionDetailsView), findsOneWidget);
  await tester.tap(find.byTooltip('Copiar identificador'));
  await tester.pump();
  expect(copied, [tile.transaction.id]);

  // Back: filters, search and scroll position are preserved.
  await tester.tap(find.byType(BackButton));
  await settle(tester);
  expect(find.byTooltip('Filtros, 1 ativo'), findsOneWidget);
  expect(
    tester.widget<TextField>(find.byType(TextField)).controller!.text,
    'btc',
  );
  expect(
    tester.widget<CustomScrollView>(scrollView).controller!.offset,
    offset,
  );

  // Home, then a cold restart keeps the balance hidden (RN-29).
  await tester.tap(find.byType(BackButton));
  await settle(tester);
  expect(find.byType(StatementView), findsNothing);
  expect(find.widgetWithText(AppBar, 'Fluxo'), findsOneWidget);

  final preferences = await SharedPreferences.getInstance();
  final saved = {
    for (final key in preferences.getKeys()) key: preferences.get(key)!,
  };
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: await appTestOverrides(preferences: saved),
      child: const FluxoApp(),
    ),
  );
  await settle(tester);
  expect(find.byTooltip('Exibir saldo'), findsOneWidget);
}
