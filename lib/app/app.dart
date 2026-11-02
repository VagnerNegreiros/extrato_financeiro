import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Root widget. Router, themes and DI are wired in later phases.
class FluxoApp extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluxo',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0E7C66),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF0E7C66),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const Scaffold(body: Center(child: Text('Fluxo'))),
    );
  }
}
