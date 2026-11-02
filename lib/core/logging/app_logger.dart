import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

typedef LogSink = void Function(
  LogLevel level,
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

/// The only logging entry point of the app.
///
/// Logs are emitted only in debug builds by default, and every message and
/// error description is passed through [redact] first, so API keys and
/// monetary amounts never end up in device logs.
final class AppLogger {
  const new({this.enabled = kDebugMode, this._sink = _developerSink});

  final bool enabled;
  final LogSink _sink;

  void debug(String message) => _log(LogLevel.debug, message);

  void info(String message) => _log(LogLevel.info, message);

  void warning(String message, {Object? error}) =>
      _log(LogLevel.warning, message, error: error);

  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _log(LogLevel.error, message, error: error, stackTrace: stackTrace);

  void _log(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!enabled) return;
    _sink(
      level,
      redact(message),
      error: error == null ? null : redact(error.toString()),
      stackTrace: stackTrace,
    );
  }

  static final _patterns = <(RegExp, String)>[
    // Header form: "x-cg-demo-api-key: CG-abc" (also as a map entry).
    (
      RegExp(
        r'(x[-_]cg[-_](?:demo|pro)[-_]api[-_]key)(["\x27]?\s*[:=]\s*["\x27]?)'
        r'[^\s,"\x27}&]+',
        caseSensitive: false,
      ),
      r'$1$2<redacted>',
    ),
    // CoinGecko keys anywhere else in a message.
    (RegExp(r'\bCG-[A-Za-z0-9]+'), '<redacted>'),
    // Monetary amounts: "R$ 1.234,56" (with regular or non-breaking space).
    (RegExp(r'R\$[\s ]?[\d.,]+'), r'R$ <redacted>'),
  ];

  /// Masks sensitive values in [input]. Exposed for tests and interceptors.
  static String redact(String input) {
    var output = input;
    for (final (pattern, replacement) in _patterns) {
      output = output.replaceAllMapped(
        pattern,
        (match) => replacement.replaceAllMapped(
          RegExp(r'\$(\d)'),
          (group) => match.group(int.parse(group.group(1)!)) ?? '',
        ),
      );
    }
    return output;
  }

  static void _developerSink(
    LogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: 'fluxo',
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stackTrace,
    );
  }
}
