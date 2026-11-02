import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/dashboard_summary.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_state.freezed.dart';

/// Which version of the screen to render.
enum DashboardContent { loading, ready, empty, offline, error }

@freezed
abstract class DashboardState with _$DashboardState {
  const factory({
    @Default(PeriodSelection.defaultPeriod) PeriodSelection period,
    @Default(true) bool isBalanceVisible,

    /// Last summary read from the cache; kept while reloading or when a
    /// later read fails, so the screen never flashes back to a spinner.
    DashboardSummary? summary,

    /// Failure reading the cache.
    Failure? failure,
    @Default(SyncInfo.never) SyncInfo syncInfo,
  }) = _DashboardState;

  const new _();

  DashboardContent get content {
    final summary = this.summary;
    if (summary == null) {
      return failure == null
          ? DashboardContent.loading
          : DashboardContent.error;
    }
    if (!summary.isEmpty) return DashboardContent.ready;
    // An empty cache only means "no transactions" after a successful sync;
    // before that it means "nothing downloaded yet" (RN-27).
    if (syncInfo.hasData) return DashboardContent.empty;
    final syncFailure = syncInfo.lastFailure;
    if (syncInfo.isSyncing || syncFailure == null) {
      return DashboardContent.loading;
    }
    return syncFailure is NetworkFailure
        ? DashboardContent.offline
        : DashboardContent.error;
  }

  /// The failure the error state explains.
  Failure get displayedFailure =>
      failure ?? syncInfo.lastFailure ?? const UnexpectedFailure();
}
