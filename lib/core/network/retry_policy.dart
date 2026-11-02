import 'dart:io';
import 'dart:math';

/// Exponential backoff with jitter for transient HTTP failures.
///
/// `delay(n) = min(cap, base * 2^n) * jitter`, with jitter in [0.5, 1.0) so
/// clients that failed together do not retry in lockstep. A server-provided
/// `Retry-After` always wins, still bounded by [maxRetryAfter].
final class RetryPolicy {
  new({
    this.maxRetries = 3,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 16),
    this.maxRetryAfter = const Duration(seconds: 60),
    Random? random,
  }) : _random = random ?? Random();

  final int maxRetries;
  final Duration baseDelay;
  final Duration maxDelay;

  /// A longer `Retry-After` is not worth waiting for in the foreground: the
  /// request fails and the user is told how long to wait instead.
  final Duration maxRetryAfter;
  final Random _random;

  static const retryableStatusCodes = {429, 502, 503, 504};

  bool shouldRetryStatus(int? statusCode) =>
      retryableStatusCodes.contains(statusCode);

  /// Delay before retry number [attempt] (0-based), or `null` to give up.
  Duration? delayFor(int attempt, {Duration? retryAfter}) {
    if (attempt >= maxRetries) return null;
    if (retryAfter != null) {
      return retryAfter > maxRetryAfter ? null : retryAfter;
    }
    final exponential = baseDelay * pow(2, attempt).toInt();
    final capped = exponential > maxDelay ? maxDelay : exponential;
    final jitter = 0.5 + _random.nextDouble() * 0.5;
    return capped * jitter;
  }

  /// Parses `Retry-After` as delta-seconds or an HTTP date.
  static Duration? parseRetryAfter(String? header, {required DateTime now}) {
    if (header == null || header.trim().isEmpty) return null;
    final value = header.trim();
    final seconds = int.tryParse(value);
    if (seconds != null) return seconds < 0 ? null : Duration(seconds: seconds);
    try {
      final date = HttpDate.parse(value);
      final delay = date.difference(now);
      return delay.isNegative ? Duration.zero : delay;
    } on FormatException {
      return null;
    } on HttpException {
      return null;
    }
  }
}
