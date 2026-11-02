import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    const Result<int> success = Success(2);
    const Result<int> failure = Err(NetworkFailure());

    test('exposes value or failure', () {
      expect(success.isSuccess, isTrue);
      expect(success.valueOrNull, 2);
      expect(success.failureOrNull, isNull);

      expect(failure.isSuccess, isFalse);
      expect(failure.valueOrNull, isNull);
      expect(failure.failureOrNull, const NetworkFailure());
    });

    test('value semantics', () {
      expect(const Success(2).hashCode, const Success(2).hashCode);
      expect(const Success(2).toString(), 'Success(2)');
      expect(
        const Err<int>(NetworkFailure()).hashCode,
        const Err<int>(NetworkFailure()).hashCode,
      );
      expect(const Err<int>(NetworkFailure()).toString(), startsWith('Err('));
    });

    test('fold runs the matching branch', () {
      expect(success.fold((v) => 'ok $v', (_) => 'err'), 'ok 2');
      expect(failure.fold((v) => 'ok $v', (_) => 'err'), 'err');
    });

    test('map transforms only successes', () {
      expect(success.map((v) => v * 10), const Success(20));
      expect(failure.map((v) => v * 10), const Err<int>(NetworkFailure()));
    });

    test('flatMapAsync chains successes and short-circuits failures', () async {
      expect(
        await success.flatMapAsync((v) async => Success('$v')),
        const Success('2'),
      );
      expect(
        await failure.flatMapAsync((v) async => Success('$v')),
        const Err<String>(NetworkFailure()),
      );
    });
  });

  group('Failure equality', () {
    test('same type and fields are equal', () {
      expect(
        const RateLimitFailure(retryAfter: Duration(seconds: 3)),
        const RateLimitFailure(retryAfter: Duration(seconds: 3)),
      );
      expect(
        const ServerFailure(statusCode: 500).hashCode,
        const ServerFailure(statusCode: 500).hashCode,
      );
    });

    test('different fields or types are not equal', () {
      expect(
        const ServerFailure(statusCode: 500),
        isNot(const ServerFailure(statusCode: 503)),
      );
      expect(const NetworkFailure(), isNot(const TimeoutFailure()));
    });

    test('debug message does not affect equality', () {
      expect(const CacheFailure('disk full'), const CacheFailure());
    });
  });
}
