import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_totals.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_summary.freezed.dart';

/// Everything the dashboard shows, computed from a single snapshot of the
/// ledger so balance, totals and recent items can never disagree.
@freezed
abstract class DashboardSummary with _$DashboardSummary {
  const factory({
    required BalanceBreakdown balance,
    required PeriodTotals totals,
    required List<CashflowBucket> cashflow,
    required List<Transaction> recent,
    required CalendarDate firstDay,
    required CalendarDate lastDay,
  }) = _DashboardSummary;

  const new _();

  /// No transactions at all (RN-09): values are zero, never an error.
  bool get isEmpty => recent.isEmpty;
}

/// Transactions of one local day in the statement (RN-20).
@freezed
abstract class StatementGroup with _$StatementGroup {
  const factory({
    required CalendarDate date,
    required List<Transaction> transactions,

    /// Day result, with the same rule as the period totals (RN-07).
    required PeriodTotals totals,
  }) = _StatementGroup;
}
