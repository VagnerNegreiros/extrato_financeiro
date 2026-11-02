import 'package:extrato_financeiro/core/money/money.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/date_range.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_totals.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/ledger_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/transaction_builder.dart';

void main() {
  final saoPaulo = OffsetLocalCalendar.fixed(const Duration(hours: -3));

  group('RN-06: available balance', () {
    test('status table: only completed and pending debits matter', () {
      final balance = LedgerCalculator.balance([
        credit(10000), // completed credit: +100,00
        debit(2500), // completed debit: -25,00
        debit(1000, status: TransactionStatus.pending), // reserved: -10,00
        credit(5000, status: TransactionStatus.pending), // not available yet
        debit(9999, status: TransactionStatus.failed), // no effect
        credit(7777, status: TransactionStatus.failed), // no effect
        debit(3000, status: TransactionStatus.reversed), // no effect
        credit(4000, status: TransactionStatus.reversed), // no effect
      ]);

      expect(balance.completedCredits, const Money(10000));
      expect(balance.completedDebits, const Money(2500));
      expect(balance.pendingDebits, const Money(1000));
      expect(balance.pendingCredits, const Money(5000));
      expect(balance.available, const Money(6500));
    });

    test('reversed transaction does not affect the balance', () {
      final withReversal = LedgerCalculator.balance([
        credit(10000),
        debit(4000, status: TransactionStatus.reversed),
      ]);
      expect(withReversal.available, const Money(10000));
    });

    test('RN-08: pending debits explain the gap to completed totals', () {
      final balance = LedgerCalculator.balance([
        credit(10000),
        debit(1500, status: TransactionStatus.pending),
      ]);
      final completedNet = balance.completedCredits - balance.completedDebits;
      expect(completedNet - balance.available, balance.pendingDebits);
    });

    test('RN-09: no transactions means zero, not an error', () {
      final balance = LedgerCalculator.balance(const []);
      expect(balance, BalanceBreakdown.empty);
      expect(balance.available, Money.zero);
    });

    test('balance can go negative when debits exceed credits', () {
      expect(
        LedgerCalculator.balance([credit(100), debit(250)]).available,
        const Money(-150),
      );
    });

    test('RN-05: 100k transactions sum exactly', () {
      final transactions = [
        for (var i = 0; i < 50000; i++) credit(999999999),
        for (var i = 0; i < 50000; i++) debit(123456789),
      ];
      final balance = LedgerCalculator.balance(transactions);
      expect(balance.completedCredits, const Money(49999999950000));
      expect(balance.completedDebits, const Money(6172839450000));
      expect(balance.available, const Money(43827160500000));
    });
  });

  group('RN-07: period totals', () {
    final october31 = DateRange.localDays(
      CalendarDate(2026, 10, 31),
      CalendarDate(2026, 10, 31),
      saoPaulo,
    );

    test('only completed transactions inside the range count', () {
      final totals = LedgerCalculator.totals([
        credit(1000, at: DateTime.utc(2026, 10, 31, 12)),
        debit(300, at: DateTime.utc(2026, 10, 31, 15)),
        credit(
          500,
          at: DateTime.utc(2026, 10, 31, 16),
          status: TransactionStatus.pending,
        ),
        debit(
          200,
          at: DateTime.utc(2026, 10, 31, 17),
          status: TransactionStatus.failed,
        ),
        credit(9999, at: DateTime.utc(2026, 10, 29)), // outside
      ], range: october31);

      expect(totals.income, const Money(1000));
      expect(totals.expenses, const Money(300));
      expect(totals.net, const Money(700));
    });

    test('RN-13: day rollover follows the local zone', () {
      // 01:30Z on 01/11 is 22:30 on 31/10 in UTC-3.
      final lateNight = credit(100, at: DateTime.utc(2026, 11, 1, 1, 30));
      // 02:00Z on 31/10 is 23:00 on 30/10 in UTC-3.
      final previousDay = credit(200, at: DateTime.utc(2026, 10, 31, 2));

      final totals = LedgerCalculator.totals([
        lateNight,
        previousDay,
      ], range: october31);
      expect(totals.income, const Money(100));
    });

    test('range bounds are half-open', () {
      final atStart = credit(1, at: october31.startUtc);
      final atEnd = credit(10, at: october31.endUtc);
      expect(
        LedgerCalculator.totals([atStart, atEnd], range: october31).income,
        const Money(1),
      );
    });

    test('without a range every completed transaction counts', () {
      expect(
        LedgerCalculator.totals([credit(100), debit(40)]).net,
        const Money(60),
      );
    });

    test('RN-09: empty input yields zero totals', () {
      expect(LedgerCalculator.totals(const []), PeriodTotals.empty);
    });
  });

  group('cash-flow buckets', () {
    test('daily buckets up to 31 days, one per local day', () {
      final buckets = LedgerCalculator.cashflow(
        [
          credit(100, at: DateTime.utc(2026, 11, 1, 1, 30)), // 31/10 local
          debit(40, at: DateTime.utc(2026, 10, 25, 12)),
          credit(
            1,
            at: DateTime.utc(2026, 10, 25, 13),
            status: TransactionStatus.pending,
          ),
          credit(999, at: DateTime.utc(2026, 9)), // before the period
        ],
        first: CalendarDate(2026, 10, 2),
        last: CalendarDate(2026, 10, 31),
        calendar: saoPaulo,
      );

      expect(buckets, hasLength(30));
      expect(buckets.first.first, CalendarDate(2026, 10, 2));
      expect(buckets.last.last, CalendarDate(2026, 10, 31));
      expect(buckets.last.totals.income, const Money(100));
      expect(buckets[23].first, CalendarDate(2026, 10, 25));
      expect(buckets[23].totals.expenses, const Money(40));
      expect(buckets[23].totals.income, Money.zero);
      final total = buckets.fold(
        Money.zero,
        (sum, bucket) => sum + bucket.totals.net,
      );
      expect(total, const Money(60));
    });

    test('90 days become 13 weekly buckets, the last one shorter', () {
      final first = CalendarDate(2026, 8, 3);
      final last = first.addDays(89);
      final buckets = LedgerCalculator.cashflow(
        [credit(500, at: saoPaulo.startOfDayUtc(last))],
        first: first,
        last: last,
        calendar: saoPaulo,
      );

      expect(buckets, hasLength(13));
      expect(buckets[0].last, first.addDays(6));
      expect(buckets[12].first, first.addDays(84));
      expect(buckets[12].last, last);
      expect(buckets[12].totals.income, const Money(500));
    });

    test('a single day yields a single bucket', () {
      final day = CalendarDate(2026, 10, 31);
      final buckets = LedgerCalculator.cashflow(
        const [],
        first: day,
        last: day,
        calendar: saoPaulo,
      );
      expect(buckets, hasLength(1));
      expect(buckets.single.totals, PeriodTotals.empty);
    });

    test('rejects inverted periods', () {
      expect(
        () => LedgerCalculator.cashflow(
          const [],
          first: CalendarDate(2026, 10, 2),
          last: CalendarDate(2026, 10, 1),
          calendar: saoPaulo,
        ),
        throwsArgumentError,
      );
    });
  });

  group('RN-20: grouping by local day', () {
    test('groups newest day first and keeps statement order', () {
      final a = credit(100, at: DateTime.utc(2026, 10, 31, 12));
      final b = debit(30, at: DateTime.utc(2026, 11, 1, 1, 30)); // 31/10 local
      final c = credit(50, at: DateTime.utc(2026, 10, 30, 12));
      final d = debit(
        10,
        at: DateTime.utc(2026, 10, 31, 15),
        status: TransactionStatus.pending,
      );

      final groups = LedgerCalculator.groupByDay([
        c,
        a,
        d,
        b,
      ], calendar: saoPaulo);

      expect(groups.map((g) => g.date), [
        CalendarDate(2026, 10, 31),
        CalendarDate(2026, 10, 30),
      ]);
      expect(groups.first.transactions, [b, d, a]);
      expect(groups.first.totals.income, const Money(100));
      expect(groups.first.totals.expenses, const Money(30));
      expect(groups.last.transactions, [c]);
    });

    test('empty input yields no groups', () {
      expect(
        LedgerCalculator.groupByDay(const [], calendar: saoPaulo),
        isEmpty,
      );
    });

    test('groups are unmodifiable', () {
      final groups = LedgerCalculator.groupByDay([
        credit(1),
      ], calendar: saoPaulo);
      expect(
        () => groups.first.transactions.add(credit(2)),
        throwsUnsupportedError,
      );
    });
  });
}
