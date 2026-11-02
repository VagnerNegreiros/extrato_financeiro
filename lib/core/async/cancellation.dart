import 'dart:async';

/// Signals that the caller no longer needs the result of an operation.
///
/// Framework-agnostic on purpose: the domain can request cancellation
/// without knowing about Dio, and the data layer bridges it to the HTTP
/// client's own token.
final class Cancellation {
  final _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Completes once [cancel] is called.
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}
