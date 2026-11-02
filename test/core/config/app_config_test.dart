import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const httpsUrl = 'https://api.coingecko.com/api/v3';

  group('AppConfig.parse', () {
    test('parses a valid dev configuration without API key', () {
      final config = AppConfig.parse(
        flavor: 'dev',
        coinGeckoBaseUrl: httpsUrl,
        coinGeckoApiKey: '',
        fakeFailure: 'none',
      );

      expect(config.flavor, AppFlavor.dev);
      expect(config.usesFakeData, isTrue);
      expect(config.coinGeckoBaseUri.host, 'api.coingecko.com');
      expect(config.fakeFailure, FakeFailure.none);
    });

    test('parses snake_case fake failure values', () {
      final config = AppConfig.parse(
        flavor: 'dev',
        coinGeckoBaseUrl: httpsUrl,
        coinGeckoApiKey: '',
        fakeFailure: 'rate_limit',
      );

      expect(config.fakeFailure, FakeFailure.rateLimit);
    });

    test('rejects non-HTTPS base URLs', () {
      expect(
        () => AppConfig.parse(
          flavor: 'prod',
          coinGeckoBaseUrl: 'http://api.coingecko.com/api/v3',
          coinGeckoApiKey: 'key',
          fakeFailure: 'none',
        ),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('rejects malformed base URLs', () {
      expect(
        () => AppConfig.parse(
          flavor: 'dev',
          coinGeckoBaseUrl: 'not a url',
          coinGeckoApiKey: '',
          fakeFailure: 'none',
        ),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('requires an API key for prod', () {
      expect(
        () => AppConfig.parse(
          flavor: 'prod',
          coinGeckoBaseUrl: httpsUrl,
          coinGeckoApiKey: '   ',
          fakeFailure: 'none',
        ),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('rejects unknown flavors', () {
      expect(
        () => AppConfig.parse(
          flavor: 'staging',
          coinGeckoBaseUrl: httpsUrl,
          coinGeckoApiKey: '',
          fakeFailure: 'none',
        ),
        throwsA(isA<InvalidConfigException>()),
      );
    });

    test('never exposes the API key in toString', () {
      final config = AppConfig.parse(
        flavor: 'prod',
        coinGeckoBaseUrl: httpsUrl,
        coinGeckoApiKey: 'CG-secret-key',
        fakeFailure: 'none',
      );

      expect(config.toString(), isNot(contains('CG-secret-key')));
      expect(config.toString(), contains('<redacted>'));
      expect(config.toString(), contains('flavor: prod'));
      expect(config.toString(), contains('fakeFailure: none'));
    });
  });
}
