import 'package:dio/dio.dart';
import 'package:extrato_financeiro/core/errors/app_exceptions.dart';
import 'package:extrato_financeiro/core/network/dio_factory.dart';
import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toFailure', () {
    test('maps every data exception to its typed failure', () {
      expect(toFailure(const NetworkException()), isA<NetworkFailure>());
      expect(toFailure(const TimeoutException()), isA<TimeoutFailure>());
      expect(
        toFailure(const RateLimitedException(retryAfter: Duration(seconds: 9))),
        const RateLimitFailure(retryAfter: Duration(seconds: 9)),
      );
      expect(
        toFailure(const HttpStatusException(503)),
        const ServerFailure(statusCode: 503),
      );
      expect(toFailure(const HttpStatusException(404)), isA<NotFoundFailure>());
      expect(toFailure(const ParsingException()), isA<ParsingFailure>());
      expect(toFailure(const CacheException()), isA<CacheFailure>());
      expect(
        toFailure(const RequestCancelledException()),
        isA<UnexpectedFailure>(),
      );
    });

    test('unknown errors never escape as raw exceptions', () {
      expect(toFailure(StateError('boom')), isA<UnexpectedFailure>());
      expect(toFailure('text'), isA<UnexpectedFailure>());
    });

    test('toString is stable under obfuscation', () {
      expect(const ParsingException('bad').toString(), 'ParsingException: bad');
      expect(const NetworkException().toString(), 'NetworkException: ');
      for (final exception in const <AppException>[
        TimeoutException(),
        RateLimitedException(),
        HttpStatusException(500),
        RequestCancelledException(),
        CacheException(),
      ]) {
        expect(exception.toString(), endsWith('Exception: '));
      }
    });
  });

  group('mapDioException', () {
    final clock = FixedClock(DateTime.utc(2026, 11, 2));
    final options = RequestOptions(path: '/coins/bitcoin/market_chart');

    ApiException map(DioExceptionType type, {Response<Object?>? response}) =>
        mapDioException(
          DioException(requestOptions: options, type: type, response: response),
          clock: clock,
        );

    Response<Object?> response(int status, {String? retryAfter}) => Response(
      requestOptions: options,
      statusCode: status,
      headers: Headers.fromMap({
        if (retryAfter != null) 'retry-after': [retryAfter],
      }),
    );

    test('classifies transport errors', () {
      expect(map(DioExceptionType.connectionTimeout), isA<TimeoutException>());
      expect(map(DioExceptionType.sendTimeout), isA<TimeoutException>());
      expect(map(DioExceptionType.receiveTimeout), isA<TimeoutException>());
      expect(map(DioExceptionType.transformTimeout), isA<TimeoutException>());
      expect(map(DioExceptionType.connectionError), isA<NetworkException>());
      expect(map(DioExceptionType.badCertificate), isA<NetworkException>());
      expect(map(DioExceptionType.unknown), isA<NetworkException>());
      expect(map(DioExceptionType.cancel), isA<RequestCancelledException>());
    });

    test('classifies HTTP statuses, reading Retry-After on 429', () {
      final limited = map(
        DioExceptionType.badResponse,
        response: response(429, retryAfter: '12'),
      );
      expect(limited, isA<RateLimitedException>());
      expect(
        (limited as RateLimitedException).retryAfter,
        const Duration(seconds: 12),
      );

      final server = map(DioExceptionType.badResponse, response: response(500));
      expect((server as HttpStatusException).statusCode, 500);
    });
  });
}
