import 'dart:async';
import 'dart:math';

import 'package:extrato_financeiro/app/app.dart';
import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/app/router.dart';
import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  setUpAll(initTestLocale);

  group('theme contrast (WCAG AA)', () {
    for (final (name, theme, colors) in [
      ('light', AppTheme.light, FinancialColors.light),
      ('dark', AppTheme.dark, FinancialColors.dark),
    ]) {
      test('$name: financial colors reach 4.5:1 on surfaces', () {
        final scheme = theme.colorScheme;
        for (final background in [
          scheme.surface,
          scheme.surfaceContainerLow,
          scheme.surfaceContainer,
        ]) {
          for (final color in [
            colors.credit,
            colors.debit,
            colors.completed,
            colors.pending,
            colors.failed,
            colors.reversed,
          ]) {
            expect(
              _contrast(color, background),
              greaterThanOrEqualTo(4.5),
              reason: '$color on $background',
            );
          }
        }
      });
    }
  });

  /// Opens each main screen and runs [check] on it.
  Future<void> forEachScreen(
    WidgetTester tester,
    Future<void> Function(String screen) check,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: await appTestOverrides(),
        child: const FluxoApp(),
      ),
    );
    await settle(tester);
    await check('dashboard');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final router = container.read(routerProvider);
    unawaited(router.pushNamed(AppRoute.statement));
    await settle(tester);
    await check('statement');

    final all = (await container.read(transactionRepositoryProvider).getAll())
        .valueOrNull!;
    final trade = all.firstWhere(
      (t) => t.category == TransactionCategory.cryptoBuy,
    );
    unawaited(
      router.pushNamed(
        AppRoute.transactionDetails,
        pathParameters: {'id': trade.id},
      ),
    );
    await settle(tester);
    await check('details');
  }

  testWidgets('tap targets, labels and text contrast follow the guidelines', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await forEachScreen(tester, (screen) async {
      await expectLater(
        tester,
        meetsGuideline(androidTapTargetGuideline),
        reason: screen,
      );
      await expectLater(
        tester,
        meetsGuideline(labeledTapTargetGuideline),
        reason: screen,
      );
      await expectLater(
        tester,
        meetsGuideline(textContrastGuideline),
        reason: screen,
      );
    });
    semantics.dispose();
  });

  testWidgets('dark theme meets text contrast', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final semantics = tester.ensureSemantics();
    await forEachScreen(tester, (screen) async {
      await expectLater(
        tester,
        meetsGuideline(textContrastGuideline),
        reason: screen,
      );
    });
    semantics.dispose();
  });

  testWidgets('200% font on a 360dp phone renders without overflow', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    // Layout overflows are reported as test failures by the framework.
    await forEachScreen(tester, (screen) async {
      expect(tester.takeException(), isNull, reason: screen);
    });
  });
}
