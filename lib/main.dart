import 'dart:ui';

import 'package:extrato_financeiro/app/app.dart';
import 'package:extrato_financeiro/app/providers.dart';
import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const logger = AppLogger();

  // Errors outside the widget tree are logged instead of crashing silently;
  // a crash-reporting SDK would be plugged in here.
  FlutterError.onError = (details) {
    logger.error(
      'Flutter error',
      error: details.exception,
      stackTrace: details.stack,
    );
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    logger.error('Uncaught error', error: error, stackTrace: stackTrace);
    return true;
  };

  final AppConfig config;
  try {
    config = AppConfig.fromEnvironment();
  } on InvalidConfigException catch (error) {
    logger.error('Invalid build configuration', error: error);
    runApp(const _InvalidConfigApp());
    return;
  }

  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(config),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const FluxoApp(),
    ),
  );
}

/// Shown instead of crashing when the build was misconfigured.
class _InvalidConfigApp extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Este build está com a configuração inválida.\n'
            'Gere o app novamente com um arquivo de ambiente válido.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
