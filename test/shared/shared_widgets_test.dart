import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/shared/failure_messages.dart';
import 'package:extrato_financeiro/shared/labels.dart';
import 'package:extrato_financeiro/shared/widgets/amount_text.dart';
import 'package:extrato_financeiro/shared/widgets/state_views.dart';
import 'package:extrato_financeiro/shared/widgets/status_chip.dart';
import 'package:extrato_financeiro/shared/widgets/sync_status_banner.dart';
import 'package:extrato_financeiro/shared/widgets/transaction_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';
import '../helpers/transaction_builder.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  home: Scaffold(body: child),
);

void main() {
  setUpAll(initTestLocale);

  group('AmountText', () {
    testWidgets('signs and colors by direction, never color alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              AmountText(Money(15000), direction: TransactionDirection.credit),
              AmountText(Money(8990), direction: TransactionDirection.debit),
              AmountText(Money(-50)),
            ],
          ),
        ),
      );

      expect(find.text(r'+R$ 150,00'), findsOneWidget);
      expect(find.text(r'−R$ 89,90'), findsOneWidget);
      expect(find.text(r'−R$ 0,50'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text(r'+R$ 150,00')).style?.color,
        FinancialColors.light.credit,
      );
      expect(find.bySemanticsLabel('Entrada de 150 reais'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Saída de 89 reais e 90 centavos'),
        findsOneWidget,
      );
    });

    testWidgets('obscured amounts hide digits and say so', (tester) async {
      await tester.pumpWidget(
        _wrap(const AmountText(Money(123456), obscured: true)),
      );

      expect(find.textContaining(RegExp(r'\d')), findsNothing);
      expect(find.bySemanticsLabel('Valor oculto'), findsOneWidget);
    });
  });

  group('StatusChip', () {
    testWidgets('shows icon and label for every status', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [for (final s in TransactionStatus.values) StatusChip(s)],
          ),
          theme: AppTheme.dark,
        ),
      );

      for (final status in TransactionStatus.values) {
        expect(find.text(status.label), findsOneWidget);
        expect(find.byIcon(status.icon), findsOneWidget);
        expect(
          find.bySemanticsLabel('Status: ${status.label}'),
          findsOneWidget,
        );
      }
    });
  });

  group('TransactionTile', () {
    testWidgets('reads as one sentence and is tappable', (tester) async {
      var taps = 0;
      final transaction = tx(
        cents: 4347,
        direction: TransactionDirection.debit,
        category: TransactionCategory.cryptoBuy,
        description: 'Compra de Bitcoin (BTC)',
        at: DateTime.utc(2026, 10, 30, 17, 32),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: await appTestOverrides(),
          child: _wrap(
            TransactionTile(transaction, onTap: () => taps++, showDate: true),
          ),
        ),
      );

      expect(find.text('Compra de Bitcoin (BTC)'), findsOneWidget);
      expect(find.text('30/10 · 14:32 · Compra de cripto'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Saída, Compra de Bitcoin (BTC), 43 reais e 47 centavos, '
          'Concluída, 30/10, 14:32',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byType(TransactionTile));
      expect(taps, 1);
    });

    testWidgets('failed amounts are struck through', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: await appTestOverrides(),
          child: _wrap(
            TransactionTile(debit(100, status: TransactionStatus.failed)),
          ),
        ),
      );
      final text = tester.widget<Text>(find.textContaining(r'R$'));
      expect(text.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('amounts and statuses line up on the right edge', (
      tester,
    ) async {
      // Wider than a phone: the test font is wider than the real one, and at
      // 360dp its status label alone would fill the column.
      tester.view
        ..physicalSize = const Size(600, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: await appTestOverrides(),
          child: _wrap(
            Column(
              children: [
                TransactionTile(debit(100)),
                TransactionTile(credit(1234567890)),
              ],
            ),
          ),
        ),
      );

      const rightEdge = 600 - AppSpacing.lg;
      for (final type in [AmountText, StatusChip]) {
        for (final element in find.byType(type).evaluate()) {
          expect(
            tester.getTopRight(find.byWidget(element.widget)).dx,
            moreOrLessEquals(rightEdge, epsilon: 1),
            reason: '$type',
          );
        }
      }
    });
  });

  group('state views', () {
    testWidgets('error view explains the failure and retries', (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        _wrap(
          ErrorView(failure: const NetworkFailure(), onRetry: () => retries++),
        ),
      );

      expect(find.text('Sem conexão'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      expect(retries, 1);
    });

    testWidgets('empty and loading views render', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Column(
            children: [
              EmptyView(title: 'Nada aqui', message: 'Sem transações.'),
              Expanded(
                child: SingleChildScrollView(child: LoadingView(itemCount: 2)),
              ),
            ],
          ),
        ),
      );
      expect(find.text('Nada aqui'), findsOneWidget);
      expect(find.bySemanticsLabel('Carregando'), findsOneWidget);
    });
  });

  group('describeFailure', () {
    test('every failure has a pt-BR title and message', () {
      const failures = <Failure>[
        NetworkFailure(),
        TimeoutFailure(),
        RateLimitFailure(),
        RateLimitFailure(retryAfter: Duration(seconds: 1)),
        RateLimitFailure(retryAfter: Duration(seconds: 30)),
        ServerFailure(statusCode: 401),
        ServerFailure(statusCode: 503),
        ParsingFailure(),
        CacheFailure(),
        NotFoundFailure(),
        UnexpectedFailure(),
      ];
      for (final failure in failures) {
        final message = describeFailure(failure);
        expect(message.title, isNotEmpty);
        expect(message.message, isNotEmpty);
      }
      expect(
        describeFailure(
          const RateLimitFailure(retryAfter: Duration(seconds: 30)),
        ).message,
        contains('30 segundos'),
      );
      expect(
        describeFailure(
          const RateLimitFailure(retryAfter: Duration(seconds: 1)),
        ).message,
        contains('1 segundo '),
      );
      expect(
        describeFailure(const ServerFailure(statusCode: 403)).title,
        'Configuração inválida',
      );
    });
  });

  group('syncBannerKind (RN-25)', () {
    final now = testNow;
    final fresh = SyncInfo(lastSuccessAt: now);

    test('no banner without data or when fresh', () {
      expect(
        syncBannerKind(isOnline: false, info: SyncInfo.never, nowUtc: now),
        SyncBannerKind.none,
      );
      expect(
        syncBannerKind(isOnline: true, info: fresh, nowUtc: now),
        SyncBannerKind.none,
      );
    });

    test('offline, failed and stale data are flagged', () {
      expect(
        syncBannerKind(isOnline: false, info: fresh, nowUtc: now),
        SyncBannerKind.offline,
      );
      expect(
        syncBannerKind(
          isOnline: true,
          info: fresh.copyWith(lastFailure: const NetworkFailure()),
          nowUtc: now,
        ),
        SyncBannerKind.offline,
      );
      expect(
        syncBannerKind(
          isOnline: true,
          info: fresh.copyWith(lastFailure: const RateLimitFailure()),
          nowUtc: now,
        ),
        SyncBannerKind.failed,
      );
      expect(
        syncBannerKind(
          isOnline: true,
          info: fresh,
          nowUtc: now.add(const Duration(minutes: 16)),
        ),
        SyncBannerKind.stale,
      );
    });
  });

  group('labels', () {
    test('every enum value has a label', () {
      for (final value in TransactionCategory.values) {
        expect(value.label, isNotEmpty);
      }
      expect(TransactionDirection.credit.label, 'Entrada');
      expect(TransactionDirection.debit.label, 'Saída');
    });

    test('decimal and percent formatting in pt-BR', () {
      expect(formatDecimal(Decimal.parse('0.00012345')), '0,00012345');
      expect(formatPercent(Decimal.parse('1.256')), '+1,26%');
      expect(formatPercent(Decimal.parse('-0.4')), '−0,40%');
      expect(formatPercent(Decimal.zero), '+0,00%');
    });
  });
}
