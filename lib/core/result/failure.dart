import 'package:meta/meta.dart';

/// Typed failures that may reach the presentation layer.
///
/// Raw exceptions never cross the repository boundary: data sources throw
/// typed exceptions and repositories translate them into one of these.
/// [debugMessage] is for logs only and must never be shown to the user.
@immutable
sealed class Failure {
  const new([this.debugMessage]);

  final String? debugMessage;

  /// Fields that define equality, besides the concrete type.
  List<Object?> get props => const [];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Failure &&
          other.runtimeType == runtimeType &&
          _listEquals(other.props, props));

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(props));

  static bool _listEquals(List<Object?> a, List<Object?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// No connectivity, DNS failure or connection refused.
final class NetworkFailure extends Failure {
  const new([super.debugMessage]);
}

/// The server took too long to answer.
final class TimeoutFailure extends Failure {
  const new([super.debugMessage]);
}

/// HTTP 429 that persisted after every retry.
final class RateLimitFailure extends Failure {
  const new({this.retryAfter, String? debugMessage}) : super(debugMessage);

  /// How long the server asked us to wait, when known.
  final Duration? retryAfter;

  @override
  List<Object?> get props => [retryAfter];
}

/// Unexpected HTTP status (4xx/5xx) after retries.
final class ServerFailure extends Failure {
  const new({this.statusCode, String? debugMessage}) : super(debugMessage);

  final int? statusCode;

  @override
  List<Object?> get props => [statusCode];
}

/// The response could not be turned into domain data.
final class ParsingFailure extends Failure {
  const new([super.debugMessage]);
}

/// Reading or writing the local cache failed.
final class CacheFailure extends Failure {
  const new([super.debugMessage]);
}

/// The requested resource does not exist (e.g. unknown transaction id).
final class NotFoundFailure extends Failure {
  const new([super.debugMessage]);
}

/// Anything not covered above. Should be rare and always logged.
final class UnexpectedFailure extends Failure {
  const new([super.debugMessage]);
}
