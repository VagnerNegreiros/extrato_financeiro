import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/date_range.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/dashboard_summary.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_totals.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';

/// Financial rules of the ledger, as pure functions over transactions.
///
/// Every screen derives its numbers from here, so the dashboard, statement
/// and details can never disagree about the same data.
abstract final class LedgerCalculator {
  /// Periods up to this many days are charted per day; longer ones per week.
  static const maxDailyBuckets = 31;

  /// Balance breakdown (RN-06): completed credits minus completed debits
  /// minus pending debits. Failed and reversed entries have no effect.
  static BalanceBreakdown balance(Iterable<Transaction> transactions) {
    var completedCredits = Money.zero;
    var completedDebits = Money.zero;
    var pendingCredits = Money.zero;
    var pendingDebits = Money.zero;

    for (final transaction in transactions) {
      switch ((transaction.status, transaction.direction)) {
        case (TransactionStatus.completed, TransactionDirection.credit):
          completedCredits += transaction.amount;
        case (TransactionStatus.completed, TransactionDirection.debit):
          completedDebits += transaction.amount;
        case (TransactionStatus.pending, TransactionDirection.credit):
          pendingCredits += transaction.amount;
        case (TransactionStatus.pending, TransactionDirection.debit):
          pendingDebits += transaction.amount;
        case (TransactionStatus.failed || TransactionStatus.reversed, _):
          break;
      }
    }

    return BalanceBreakdown(
      completedCredits: completedCredits,
      completedDebits: completedDebits,
      pendingDebits: pendingDebits,
      pendingCredits: pendingCredits,
    );
  }

  /// Income and expenses of completed transactions inside [range] (RN-07).
  /// Without a range, every transaction is considered.
  static PeriodTotals totals(
    Iterable<Transaction> transactions, {
    DateRange? range,
  }) {
    var income = Money.zero;
    var expenses = Money.zero;
    for (final transaction in transactions) {
      if (!transaction.status.countsInTotals) continue;
      if (range != null && !range.contains(transaction.occurredAt)) continue;
      if (transaction.isCredit) {
        income += transaction.amount;
      } else {
        expenses += transaction.amount;
      }
    }
    return PeriodTotals(income: income, expenses: expenses);
  }

  /// Chart buckets covering every day from [first] to [last], inclusive.
  ///
  /// Daily up to [maxDailyBuckets] days, weekly beyond that (the last week
  /// may be shorter), so a 90-day period stays at 13 readable bars. Days are
  /// local, so a late-night transaction falls on the day the user saw it.
  static List<CashflowBucket> cashflow(
    Iterable<Transaction> transactions, {
    required CalendarDate first,
    required CalendarDate last,
    required LocalCalendar calendar,
  }) {
    if (last.isBefore(first)) {
      throw ArgumentError('Last day must not be before the first day.');
    }
    final dayCount = first.daysUntil(last) + 1;
    final bucketDays = dayCount <= maxDailyBuckets ? 1 : 7;
    final bucketCount = (dayCount + bucketDays - 1) ~/ bucketDays;

    final income = List.filled(bucketCount, Money.zero);
    final expenses = List.filled(bucketCount, Money.zero);

    for (final transaction in transactions) {
      if (!transaction.status.countsInTotals) continue;
      final offset = first.daysUntil(calendar.dateOf(transaction.occurredAt));
      if (offset < 0 || offset >= dayCount) continue;
      final index = offset ~/ bucketDays;
      if (transaction.isCredit) {
        income[index] += transaction.amount;
      } else {
        expenses[index] += transaction.amount;
      }
    }

    return [
      for (var i = 0; i < bucketCount; i++)
        CashflowBucket(
          first: first.addDays(i * bucketDays),
          last: _min(first.addDays((i + 1) * bucketDays - 1), last),
          totals: PeriodTotals(income: income[i], expenses: expenses[i]),
        ),
    ];
  }

  /// Groups transactions by local day, newest day first (RN-19/20).
  ///
  /// Input order does not matter; each group keeps the statement order.
  static List<StatementGroup> groupByDay(
    Iterable<Transaction> transactions, {
    required LocalCalendar calendar,
  }) {
    final sorted = transactions.toList()..sort(Transaction.newestFirst);
    final groups = <StatementGroup>[];
    var start = 0;
    while (start < sorted.length) {
      final date = calendar.dateOf(sorted[start].occurredAt);
      var end = start + 1;
      while (end < sorted.length &&
          calendar.dateOf(sorted[end].occurredAt) == date) {
        end++;
      }
      final dayTransactions = List<Transaction>.unmodifiable(
        sorted.sublist(start, end),
      );
      groups.add(
        StatementGroup(
          date: date,
          transactions: dayTransactions,
          totals: totals(dayTransactions),
        ),
      );
      start = end;
    }
    return groups;
  }

  static CalendarDate _min(CalendarDate a, CalendarDate b) =>
      a.isAfter(b) ? b : a;
}
