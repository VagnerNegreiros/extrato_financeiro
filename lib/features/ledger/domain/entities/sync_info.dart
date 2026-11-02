import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_info.freezed.dart';

/// State of the synchronization between the API and the local cache.
@freezed
abstract class SyncInfo with _$SyncInfo {
  const factory({
    /// Last time the cache was refreshed successfully, in UTC.
    DateTime? lastSuccessAt,

    /// Failure of the latest attempt; `null` when it succeeded.
    Failure? lastFailure,
    @Default(false) bool isSyncing,
  }) = _SyncInfo;

  const new _();

  static const never = SyncInfo();

  /// Cached data older than this is flagged as possibly outdated (RN-25).
  static const staleAfter = Duration(minutes: 15);

  /// Minimum interval between automatic syncs (RN-26).
  static const ttl = Duration(minutes: 5);

  bool get hasData => lastSuccessAt != null;

  /// True when the cache may not reflect the server (RN-25).
  bool isStale(DateTime nowUtc) {
    final last = lastSuccessAt;
    if (last == null || lastFailure != null) return true;
    return nowUtc.difference(last) > staleAfter;
  }

  /// Whether an automatic (non-forced) sync should hit the network (RN-26).
  bool needsRefresh(DateTime nowUtc) {
    final last = lastSuccessAt;
    return last == null || nowUtc.difference(last) >= ttl;
  }
}
