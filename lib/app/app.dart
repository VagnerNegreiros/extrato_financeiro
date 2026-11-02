import 'dart:async';

import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/app/router.dart';
import 'package:extrato_financeiro/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter(
    dashboard: (_) => const _Placeholder('Fluxo'),
    statement: (_) => const _Placeholder('Extrato'),
    details: (_, id) => _Placeholder('Transação $id'),
  );
  ref.onDispose(router.dispose);
  return router;
});

/// Root widget: themes, pt-BR localization, router and app-level sync
/// triggers (start and return to foreground).
class FluxoApp extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<FluxoApp> createState() => _FluxoAppState();
}

class _FluxoAppState extends ConsumerState<FluxoApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final coordinator = ref.read(syncCoordinatorProvider)..start();
    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(coordinator.syncIfNeeded()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Fluxo',
      debugShowCheckedModeBanner: false,
      routerConfig: ref.watch(routerProvider),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

class _Placeholder extends StatelessWidget {
  const new(this.title);

  final String title;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: Text(title)));
}
