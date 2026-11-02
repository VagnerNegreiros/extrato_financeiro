import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:extrato_financeiro/core/async/cancellation.dart';
import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:extrato_financeiro/core/network/dio_factory.dart';
import 'package:extrato_financeiro/core/network/rate_limiter.dart';
import 'package:extrato_financeiro/core/network/retry_policy.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/features/ledger/data/datasources/market_data_source.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/scripted_adapter.dart';

void main() {
  const apiKey = 'CG-test-key';
  final fixture = jsonDecode(
    File('test/fixtures/market_chart_bitcoin.json').readAsStringSync(),
  );

  late FixedClock clock;
  late ScriptedAdapter adapter;
  late List<Duration> sleeps;
  late List<String> logs;
  late CoinGeckoMarketDataSource dataSource;

  setUp(() {
    // The fixture was captured at 03:54Z on 2026-11-02.
    clock = FixedClock(DateTime.utc(2026, 11, 2, 4));
    adapter = ScriptedAdapter();
    sleeps = [];
    logs = [];
    Future<void> sleep(Duration duration) async => sleeps.add(duration);

    final dio = DioFactory.create(
      config: AppConfig.parse(
        flavor: 'prod',
        coinGeckoBaseUrl: 'https://api.coingecko.com/api/v3',
        coinGeckoApiKey: apiKey,
        fakeFailure: 'none',
      ),
      clock: clock,
      logger: AppLogger(
        sink: (level, message, {error, stackTrace}) => logs.add(message),
      ),
      adapter: adapter,
      retryPolicy: RetryPolicy(random: Random(7)),
      rateLimiter: RateLimiter(clock: clock, sleep: sleep),
      sleep: sleep,
    );
    dataSource = CoinGeckoMarketDataSource(dio: dio, clock: clock);
  });

  group('market chart', () {
    test('requests daily BRL prices with the API key over HTTPS', () async {
      adapter.enqueueJson(fixture);

      final chart = await dataSource.fetchDailyChart('bitcoin', days: 7);

      final request = adapter.requests.single;
      expect(request.uri.scheme, 'https');
      expect(request.uri.path, '/api/v3/coins/bitcoin/market_chart');
      expect(request.uri.queryParameters, {
        'vs_currency': 'brl',
        'days': '7',
        'interval': 'daily',
      });
      expect(request.headers[DioFactory.apiKeyHeader], apiKey);

      expect(chart.prices, hasLength(8));
      expect(chart.discardedPoints, 0);
      expect(chart.prices.first.timestamp, DateTime.utc(2026, 10, 27));
      // Last point is the partial current price, not a daily close.
      expect(chart.prices.last.timestamp, DateTime.utc(2026, 11, 2, 3, 53, 20));
      expect(chart.prices.first.price, Decimal.parse('430086.1803941016'));
    });

    test('rejects ids that could change the request path', () async {
      await expectLater(
        dataSource.fetchDailyChart('../simple/price', days: 1),
        throwsA(isA<ParsingException>()),
      );
      expect(adapter.requests, isEmpty);
    });

    test('never logs the API key or query parameters', () async {
      adapter.enqueueJson(fixture);
      await dataSource.fetchDailyChart('bitcoin', days: 7);

      expect(logs, isNotEmpty);
      expect(logs.join('\n'), isNot(contains(apiKey)));
      expect(logs.join('\n'), isNot(contains('vs_currency')));
    });
  });

  group('429 and transient failures', () {
    test('honours Retry-After and succeeds on a later attempt', () async {
      adapter
        ..enqueueStatus(
          429,
          headers: {
            'retry-after': ['2'],
          },
        )
        ..enqueueStatus(
          429,
          headers: {
            'retry-after': ['3'],
          },
        )
        ..enqueueJson(fixture);

      final chart = await dataSource.fetchDailyChart('bitcoin', days: 7);

      expect(chart.prices, isNotEmpty);
      expect(adapter.requests, hasLength(3));
      expect(sleeps, [const Duration(seconds: 2), const Duration(seconds: 3)]);
    });

    test('gives up after 3 retries with the suggested wait', () async {
      for (var i = 0; i < 4; i++) {
        adapter.enqueueStatus(
          429,
          headers: {
            'retry-after': ['5'],
          },
        );
      }

      await expectLater(
        dataSource.fetchDailyChart('bitcoin', days: 7),
        throwsA(
          isA<RateLimitedException>().having(
            (e) => e.retryAfter,
            'retryAfter',
            const Duration(seconds: 5),
          ),
        ),
      );
      expect(adapter.requests, hasLength(4));
    });

    test('backs off exponentially on 503 without Retry-After', () async {
      adapter
        ..enqueueStatus(503)
        ..enqueueStatus(503)
        ..enqueueJson(fixture);

      await dataSource.fetchDailyChart('bitcoin', days: 7);

      expect(sleeps, hasLength(2));
      // Attempt n waits between 50% and 100% of 2^n seconds.
      expect(sleeps[0].inMilliseconds, inInclusiveRange(500, 1000));
      expect(sleeps[1].inMilliseconds, inInclusiveRange(1000, 2000));
    });

    test(
      'retries connection errors, then reports the network failure',
      () async {
        for (var i = 0; i < 4; i++) {
          adapter.enqueueConnectionError();
        }

        await expectLater(
          dataSource.fetchDailyChart('bitcoin', days: 7),
          throwsA(isA<NetworkException>()),
        );
        expect(adapter.requests, hasLength(4));
      },
    );

    test('does not retry permanent errors', () async {
      adapter.enqueueStatus(500);

      await expectLater(
        dataSource.fetchDailyChart('bitcoin', days: 7),
        throwsA(
          isA<HttpStatusException>().having((e) => e.statusCode, 'status', 500),
        ),
      );
      expect(adapter.requests, hasLength(1));
      expect(sleeps, isEmpty);
    });
  });

  group('current price', () {
    test('parses the BRL price and 24h change', () async {
      adapter.enqueueJson({
        'bitcoin': {'brl': 428262.1, 'brl_24h_change': -1.25},
      });

      final price = await dataSource.fetchCurrentPrice('bitcoin');

      expect(price.price, Decimal.parse('428262.1'));
      expect(price.change24hPercent, Decimal.parse('-1.25'));
      expect(adapter.requests.single.uri.queryParameters['ids'], 'bitcoin');
    });

    test('cancellation aborts the in-flight request', () async {
      adapter.enqueueHang();
      final cancellation = Cancellation();

      final future = dataSource.fetchCurrentPrice(
        'bitcoin',
        cancellation: cancellation,
      );
      cancellation.cancel();

      await expectLater(future, throwsA(isA<RequestCancelledException>()));
    });

    test('an already cancelled request is not sent', () async {
      final cancellation = Cancellation()..cancel();

      await expectLater(
        dataSource.fetchCurrentPrice('bitcoin', cancellation: cancellation),
        throwsA(isA<RequestCancelledException>()),
      );
      expect(adapter.requests, isEmpty);
    });
  });
}
