import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'period_totals.freezed.dart';

/// Breakdown of the available balance (RN-06/08).
@freezed
abstract class BalanceBreakdown with _$BalanceBreakdown {
  const factory({
    required Money completedCredits,
    required Money completedDebits,
    required Money pendingDebits,
    required Money pendingCredits,
  }) = _BalanceBreakdown;

  const new _();

  static const empty = BalanceBreakdown(
    completedCredits: Money.zero,
    completedDebits: Money.zero,
    pendingDebits: Money.zero,
    pendingCredits: Money.zero,
  );

  /// Completed credits minus completed and pending debits (RN-06).
  ///
  /// Pending debits are already reserved; pending credits are not available
  /// until they settle.
  Money get available => completedCredits - completedDebits - pendingDebits;
}

/// Income and expenses of a period, completed transactions only (RN-07).
@freezed
abstract class PeriodTotals with _$PeriodTotals {
  const factory({required Money income, required Money expenses}) =
      _PeriodTotals;

  const new _();

  static const empty = PeriodTotals(income: Money.zero, expenses: Money.zero);

  Money get net => income - expenses;
}

/// One bar of the cash-flow chart: a day or a week, inclusive bounds.
@freezed
abstract class CashflowBucket with _$CashflowBucket {
  const factory({
    required CalendarDate first,
    required CalendarDate last,
    required PeriodTotals totals,
  }) = _CashflowBucket;
}
