import 'package:dio/dio.dart';
import 'package:extrato_financeiro/core/config/app_config.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:extrato_financeiro/core/network/interceptors.dart';
import 'package:extrato_financeiro/core/network/rate_limiter.dart';
import 'package:extrato_financeiro/core/network/retry_policy.dart';
import 'package:extrato_financeiro/core/time/clock.dart';

/// Builds the CoinGecko HTTP client.
///
/// Interceptor order matters: the rate limiter runs before every attempt
/// (retries included), then the retry policy, then logging.
abstract final class DioFactory {
  static const apiKeyHeader = 'x-cg-demo-api-key';

  static Dio create({
    required AppConfig config,
    required Clock clock,
    required AppLogger logger,
    RateLimiter? rateLimiter,
    RetryPolicy? retryPolicy,
    HttpClientAdapter? adapter,
    Sleep sleep = realSleep,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: config.coinGeckoBaseUri.toString(),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'accept': 'application/json',
          if (config.coinGeckoApiKey.isNotEmpty)
            apiKeyHeader: config.coinGeckoApiKey,
        },
      ),
    );
    if (adapter != null) dio.httpClientAdapter = adapter;

    dio.interceptors.addAll([
      RateLimitInterceptor(
        rateLimiter ?? RateLimiter(clock: clock, sleep: sleep),
      ),
      RetryInterceptor(
        dio: dio,
        policy: retryPolicy ?? RetryPolicy(),
        clock: clock,
        logger: logger,
        sleep: sleep,
      ),
      RedactingLogInterceptor(logger, clock),
    ]);
    return dio;
  }
}

/// Classifies a [DioException] into the app's [ApiException] hierarchy.
ApiException mapDioException(DioException error, {required Clock clock}) {
  final path = error.requestOptions.uri.path;
  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout => TimeoutException(path),
    DioExceptionType.connectionError ||
    DioExceptionType.badCertificate => NetworkException(path),
    DioExceptionType.cancel => RequestCancelledException(path),
    DioExceptionType.badResponse => _fromStatus(error, path, clock),
    DioExceptionType.unknown => NetworkException('$path: ${error.message}'),
  };
}

ApiException _fromStatus(DioException error, String path, Clock clock) {
  final status = error.response?.statusCode;
  if (status == 429) {
    return RateLimitedException(
      retryAfter: RetryPolicy.parseRetryAfter(
        error.response?.headers.value('retry-after'),
        now: clock.nowUtc(),
      ),
      debugMessage: path,
    );
  }
  return HttpStatusException(status, path);
}
