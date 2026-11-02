/// Shares one in-flight [Future] between concurrent calls with the same key.
///
/// Prevents duplicate requests when, for example, the dashboard and the
/// statement trigger a sync at the same time. Once the future completes the
/// key is released, so later calls start a fresh request.
final class RequestDeduplicator<K, T> {
  final _inFlight = <K, Future<T>>{};

  bool isRunning(K key) => _inFlight.containsKey(key);

  Future<T> run(K key, Future<T> Function() task) {
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = Future.sync(task);
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }
}
