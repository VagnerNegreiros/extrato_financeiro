import 'package:extrato_financeiro/core/result/result.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/core/time/date_range.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/dashboard_summary.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/repositories/transaction_repository.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/ledger_calculator.dart';

/// Builds the dashboard from one read of the ledger: balance, period
/// totals, chart and recent transactions come from the same snapshot.
final class GetDashboardSummary {
  const new({
    required this._repository,
    required this._clock,
    required this._calendar,
  });

  static const recentCount = 5;

  final TransactionRepository _repository;
  final Clock _clock;
  final LocalCalendar _calendar;

  Future<Result<DashboardSummary>> call(PeriodSelection period) async {
    final result = await _repository.getAll();
    return result.map((transactions) {
      final span = period.localDays(clock: _clock, calendar: _calendar);
      final range = DateRange.localDays(span.first, span.last, _calendar);
      final sorted = transactions.toList()..sort(Transaction.newestFirst);

      return DashboardSummary(
        balance: LedgerCalculator.balance(sorted),
        totals: LedgerCalculator.totals(sorted, range: range),
        cashflow: LedgerCalculator.cashflow(
          sorted,
          first: span.first,
          last: span.last,
          calendar: _calendar,
        ),
        recent: List.unmodifiable(sorted.take(recentCount)),
        firstDay: span.first,
        lastDay: span.last,
      );
    });
  }
}
