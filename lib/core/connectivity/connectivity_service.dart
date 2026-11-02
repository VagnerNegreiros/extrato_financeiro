import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Whether the device has a network interface.
///
/// Only a hint: being "online" does not guarantee the API is reachable, so
/// the app still relies on request failures to decide what to show.
abstract interface class ConnectivityService {
  Future<bool> isOnline();

  /// Emits whenever the online state changes.
  Stream<bool> watchOnline();
}

final class PluginConnectivityService implements ConnectivityService {
  new([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async =>
      _hasNetwork(await _connectivity.checkConnectivity());

  @override
  Stream<bool> watchOnline() =>
      _connectivity.onConnectivityChanged.map(_hasNetwork).distinct();

  static bool _hasNetwork(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}

/// Always online; used by the dev flavor and tests.
final class AlwaysOnlineConnectivity implements ConnectivityService {
  const new();

  @override
  Future<bool> isOnline() async => true;

  @override
  Stream<bool> watchOnline() => const Stream.empty();
}
