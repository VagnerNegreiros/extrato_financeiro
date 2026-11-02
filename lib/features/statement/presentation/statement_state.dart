import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/dashboard_summary.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/statement_filter.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'statement_state.freezed.dart';

/// Loading state of the first page.
enum StatementStatus { loading, ready, error }

/// Which version of the screen to render.
enum StatementContent { loading, ready, empty, emptyFiltered, offline, error }

@freezed
abstract class StatementState with _$StatementState {
  const factory({
    @Default(StatementFilter.initial) StatementFilter filter,
    @Default(<Transaction>[]) List<Transaction> items,

    /// [items] grouped by local day, recomputed only when items change.
    @Default(<StatementGroup>[]) List<StatementGroup> groups,
    PageCursor? nextCursor,
    @Default(StatementStatus.loading) StatementStatus status,

    /// Failure of the first page.
    Failure? failure,
    @Default(false) bool isLoadingMore,

    /// Failure of the latest "load more"; the loaded pages stay visible.
    Failure? loadMoreFailure,
    @Default(SyncInfo.never) SyncInfo syncInfo,

    /// Incremented whenever new filters produce a fresh first page, so the
    /// view scrolls back to the top (RN-22).
    @Default(0) int resetToken,
  }) = _StatementState;

  const new _();

  bool get hasMore => nextCursor != null;

  StatementContent get content {
    switch (status) {
      case StatementStatus.loading:
        return StatementContent.loading;
      case StatementStatus.error:
        return StatementContent.error;
      case StatementStatus.ready:
        if (items.isNotEmpty) return StatementContent.ready;
        if (filter.hasActiveCriteria) return StatementContent.emptyFiltered;
        if (syncInfo.hasData) return StatementContent.empty;
        final syncFailure = syncInfo.lastFailure;
        if (syncInfo.isSyncing || syncFailure == null) {
          return StatementContent.loading;
        }
        return syncFailure is NetworkFailure
            ? StatementContent.offline
            : StatementContent.error;
    }
  }

  Failure get displayedFailure =>
      failure ?? syncInfo.lastFailure ?? const UnexpectedFailure();
}
