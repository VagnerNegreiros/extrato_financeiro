import 'package:extrato_financeiro/core/result/failure.dart';

/// Typed exceptions thrown inside the data layer.
///
/// They never reach the presentation layer: repositories catch them and
/// return the matching [Failure] through [toFailure].
sealed class AppException implements Exception {
  const new([this.debugMessage]);

  final String? debugMessage;

  Failure toFailure();

  @override
  String toString() => '$_name: ${debugMessage ?? ''}';

  // Avoids runtimeType.toString(), which is mangled by obfuscation.
  String get _name;
}

/// HTTP layer errors, already classified.
sealed class ApiException extends AppException {
  const new([super.debugMessage]);
}

/// No connectivity, DNS failure, refused connection or bad certificate.
final class NetworkException extends ApiException {
  const new([super.debugMessage]);

  @override
  Failure toFailure() => NetworkFailure(debugMessage);

  @override
  String get _name => 'NetworkException';
}

final class TimeoutException extends ApiException {
  const new([super.debugMessage]);

  @override
  Failure toFailure() => TimeoutFailure(debugMessage);

  @override
  String get _name => 'TimeoutException';
}

/// HTTP 429 that survived every retry.
final class RateLimitedException extends ApiException {
  const new({this.retryAfter, String? debugMessage}) : super(debugMessage);

  final Duration? retryAfter;

  @override
  Failure toFailure() =>
      RateLimitFailure(retryAfter: retryAfter, debugMessage: debugMessage);

  @override
  String get _name => 'RateLimitedException';
}

/// Any other non-success status (401/403/404/5xx...).
final class HttpStatusException extends ApiException {
  const new(this.statusCode, [super.debugMessage]);

  final int? statusCode;

  @override
  Failure toFailure() => statusCode == 404
      ? NotFoundFailure(debugMessage)
      : ServerFailure(statusCode: statusCode, debugMessage: debugMessage);

  @override
  String get _name => 'HttpStatusException';
}

/// The caller cancelled the request; usually ignored by the caller.
final class RequestCancelledException extends ApiException {
  const new([super.debugMessage]);

  @override
  Failure toFailure() => UnexpectedFailure(debugMessage ?? 'cancelled');

  @override
  String get _name => 'RequestCancelledException';
}

/// The payload does not have the expected shape.
final class ParsingException extends AppException {
  const new([super.debugMessage]);

  @override
  Failure toFailure() => ParsingFailure(debugMessage);

  @override
  String get _name => 'ParsingException';
}

/// The local database failed.
final class CacheException extends AppException {
  const new([super.debugMessage]);

  @override
  Failure toFailure() => CacheFailure(debugMessage);

  @override
  String get _name => 'CacheException';
}

/// Converts anything thrown in the data layer into a [Failure]. Unknown
/// errors become [UnexpectedFailure] instead of escaping to the UI.
Failure toFailure(Object error) => switch (error) {
  AppException() => error.toFailure(),
  _ => UnexpectedFailure(error.toString()),
};
