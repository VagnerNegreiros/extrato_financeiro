import 'dart:async';

import 'package:dio/dio.dart';
import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:extrato_financeiro/core/network/rate_limiter.dart';
import 'package:extrato_financeiro/core/network/retry_policy.dart';
import 'package:extrato_financeiro/core/time/clock.dart';

/// Waits for a token from the [RateLimiter] before each request, keeping
/// the app below the API quota instead of reacting to 429s only.
final class RateLimitInterceptor extends Interceptor {
  new(this._limiter);

  final RateLimiter _limiter;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await _limiter.acquire();
    handler.next(options);
  }
}

/// Retries idempotent requests on 429/502/503/504 and transient network
/// errors, following [RetryPolicy].
final class RetryInterceptor extends Interceptor {
  new({
    required this._dio,
    required this._policy,
    required this._clock,
    required this._logger,
    this._sleep = realSleep,
  });

  static const _attemptKey = 'retry_attempt';

  final Dio _dio;
  final RetryPolicy _policy;
  final Clock _clock;
  final AppLogger _logger;
  final Sleep _sleep;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    if (!_isRetryable(err)) return handler.next(err);

    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    final retryAfter = RetryPolicy.parseRetryAfter(
      err.response?.headers.value('retry-after'),
      now: _clock.nowUtc(),
    );
    final delay = _policy.delayFor(attempt, retryAfter: retryAfter);
    if (delay == null) return handler.next(err);

    final reason = err.response?.statusCode ?? err.type.name;
    _logger.warning(
      'Retrying ${options.method} ${options.uri.path} '
      '(${attempt + 1}/${_policy.maxRetries}) in '
      '${delay.inMilliseconds}ms after $reason',
    );
    await _sleep(delay);
    if (options.cancelToken?.isCancelled ?? false) return handler.next(err);

    // The retried request runs through every interceptor again, so the rate
    // limiter applies and further failures are retried by a nested call
    // until the attempt counter is exhausted.
    options.extra[_attemptKey] = attempt + 1;
    try {
      handler.resolve(await _dio.fetch<Object?>(options));
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isRetryable(DioException error) {
    // Only idempotent requests are retried automatically.
    if (error.requestOptions.method.toUpperCase() != 'GET') return false;
    return switch (error.type) {
      DioExceptionType.badResponse => _policy.shouldRetryStatus(
        error.response?.statusCode,
      ),
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      _ => false,
    };
  }
}

/// Logs requests in debug builds with the API key and query redacted.
final class RedactingLogInterceptor extends Interceptor {
  new(this._logger, this._clock);

  static const _startKey = 'log_started_at';

  final AppLogger _logger;
  final Clock _clock;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = _clock.nowUtc();
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.debug(
      '${_describe(response.requestOptions)} -> ${response.statusCode} '
      '(${_elapsed(response.requestOptions)}ms)',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.debug(
      '${_describe(err.requestOptions)} -> '
      '${err.response?.statusCode ?? err.type.name} '
      '(${_elapsed(err.requestOptions)}ms)',
    );
    handler.next(err);
  }

  // Query parameters are never logged: they may carry keys or user input.
  String _describe(RequestOptions options) =>
      '${options.method} ${options.uri.path}';

  int _elapsed(RequestOptions options) {
    final start = options.extra[_startKey];
    return start is DateTime
        ? _clock.nowUtc().difference(start).inMilliseconds
        : -1;
  }
}
