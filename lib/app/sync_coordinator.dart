import 'dart:async';

import 'package:extrato_financeiro/core/connectivity/connectivity_service.dart';
import 'package:extrato_financeiro/core/logging/app_logger.dart';
import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/usecases/sync_ledger.dart';

/// Decides *when* the ledger is synchronized (RN-26):
///
/// * on app start and when the app returns to the foreground;
/// * when connectivity comes back;
/// * on pull-to-refresh ([refresh], which ignores the TTL).
///
/// Automatic triggers respect the TTL and the repository deduplicates
/// concurrent calls, so overlapping triggers never multiply requests.
final class SyncCoordinator {
  new({
    required this._syncLedger,
    required this._connectivity,
    required this._logger,
  });

  final SyncLedger _syncLedger;
  final ConnectivityService _connectivity;
  final AppLogger _logger;
  StreamSubscription<bool>? _connectivitySubscription;

  void start() {
    if (_connectivitySubscription != null) return;
    _connectivitySubscription = _connectivity.watchOnline().listen((online) {
      if (online) {
        _logger.debug('Connectivity restored, syncing');
        unawaited(syncIfNeeded());
      }
    });
    unawaited(syncIfNeeded());
  }

  /// Automatic sync; a no-op while the cache is fresh.
  Future<Result<SyncInfo>> syncIfNeeded() => _syncLedger();

  /// User-requested sync (pull-to-refresh, "try again").
  Future<Result<SyncInfo>> refresh() => _syncLedger(force: true);

  Future<void> dispose() async => await _connectivitySubscription?.cancel();
}
