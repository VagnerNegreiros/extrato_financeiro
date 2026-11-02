import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

const _nbsp = ' ';

void main() {
  group('AppLogger.redact', () {
    test('masks the CoinGecko API key header', () {
      expect(
        AppLogger.redact(
          'headers: {x-cg-demo-api-key: CG-abc123, accept: json}',
        ),
        'headers: {x-cg-demo-api-key: <redacted>, accept: json}',
      );
      expect(
        AppLogger.redact('"x_cg_demo_api_key":"CG-abc123"'),
        '"x_cg_demo_api_key":"<redacted>"',
      );
      expect(
        AppLogger.redact('/simple/price?x_cg_demo_api_key=CG-abc&ids=btc'),
        '/simple/price?x_cg_demo_api_key=<redacted>&ids=btc',
      );
    });

    test('masks bare keys and monetary amounts', () {
      expect(AppLogger.redact('key CG-xyz789 loaded'), 'key <redacted> loaded');
      expect(
        AppLogger.redact('balance R\$${_nbsp}1.234,56 synced'),
        r'balance R$ <redacted> synced',
      );
      expect(AppLogger.redact(r'total R$ 10,00'), r'total R$ <redacted>');
    });

    test('keeps harmless messages unchanged', () {
      expect(
        AppLogger.redact('sync finished in 120ms'),
        'sync finished in 120ms',
      );
    });
  });

  group('AppLogger', () {
    test('redacts messages and errors before writing', () {
      final entries = <(LogLevel, String, Object?)>[];
      // Enabled by default in tests, which run in debug mode.
      AppLogger(
          sink: (level, message, {error, stackTrace}) =>
              entries.add((level, message, error)),
        )
        ..debug('debug CG-secret')
        ..info('info')
        ..warning('warn', error: Exception('x-cg-demo-api-key: CG-1'))
        ..error('boom', error: r'R$ 99,90', stackTrace: StackTrace.current);

      expect(entries.map((e) => e.$1), LogLevel.values);
      expect(entries[0].$2, 'debug <redacted>');
      expect(entries[2].$3, contains('<redacted>'));
      expect(entries[2].$3, isNot(contains('CG-1')));
      expect(entries[3].$3, r'R$ <redacted>');
    });

    test('writes nothing when disabled', () {
      var calls = 0;
      AppLogger(
        enabled: false,
        sink: (level, message, {error, stackTrace}) => calls++,
      ).error('boom');

      expect(calls, 0);
    });
  });
}
