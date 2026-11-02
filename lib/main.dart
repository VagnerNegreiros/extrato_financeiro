import 'package:extrato_financeiro/app/app.dart';
import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fails fast on an invalid build configuration (e.g. non-HTTPS base URL).
  AppConfig.fromEnvironment();

  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');

  runApp(const ProviderScope(child: FluxoApp()));
}
