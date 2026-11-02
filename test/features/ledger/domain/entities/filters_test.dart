import 'package:extrato_financeiro/core/result/failure.dart';
import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/core/time/date_range.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/period_selection.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/statement_filter.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/sync_info.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction.dart';
import 'package:extrato_financeiro/features/ledger/domain/entities/transaction_query.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/date_range_validator.dart';
import 'package:extrato_financeiro/features/ledger/domain/services/search_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/transaction_builder.dart';

void main() {
  final saoPaulo = OffsetLocalCalendar.fixed(const Duration(hours: -3));
  // 22:30 on 31/10 local.
  final clock = FixedClock(DateTime.utc(2026, 11, 1, 1, 30));

  group('RN-14: period presets', () {
    test('presets end today in the local zone', () {
      final span = PeriodSelection.last7Days.localDays(
        clock: clock,
        calendar: saoPaulo,
      );
      expect(span.first, CalendarDate(2026, 10, 25));
      expect(span.last, CalendarDate(2026, 10, 31));
    });

    test('default period is 30 days', () {
      final range = PeriodSelection.defaultPeriod.toRange(
        clock: clock,
        calendar: saoPaulo,
      );
      expect(range.duration, const Duration(days: 30));
      expect(PeriodSelection.presets.map((p) => p.days), [7, 30, 90]);
    });

    test('custom period keeps its days', () {
      final period = CustomPeriod(
        CalendarDate(2026, 9, 1),
        CalendarDate(2026, 9, 30),
      );
      expect(
        period.toRange(clock: clock, calendar: saoPaulo),
        DateRange.localDays(
          CalendarDate(2026, 9, 1),
          CalendarDate(2026, 9, 30),
          saoPaulo,
        ),
      );
      expect(
        period,
        CustomPeriod(CalendarDate(2026, 9, 1), CalendarDate(2026, 9, 30)),
      );
      expect(
        period.hashCode,
        CustomPeriod(
          CalendarDate(2026, 9, 1),
          CalendarDate(2026, 9, 30),
        ).hashCode,
      );
      expect(const PresetPeriod(7), PeriodSelection.last7Days);
      expect(
        const PresetPeriod(7).hashCode,
        PeriodSelection.last7Days.hashCode,
      );
      expect(period, isNot(PeriodSelection.last7Days));
    });
  });

  group('RN-16: combined filters with AND', () {
    final range = DateRange.localDays(
      CalendarDate(2026, 10, 1),
      CalendarDate(2026, 10, 31),
      saoPaulo,
    );
    final buyBtc = tx(
      cents: 100,
      direction: TransactionDirection.debit,
      description: 'Compra de BTC',
      at: DateTime.utc(2026, 10, 10),
    );
    final depositPending = tx(
      cents: 100,
      status: TransactionStatus.pending,
      at: DateTime.utc(2026, 10, 10),
    );
    final oldDeposit = tx(cents: 100, at: DateTime.utc(2026, 9));

    test('empty query matches everything', () {
      expect(
        [
          buyBtc,
          depositPending,
          oldDeposit,
        ].every(TransactionQuery.all.matches),
        isTrue,
      );
    });

    test('each criterion narrows the result', () {
      const debits = TransactionQuery(direction: TransactionDirection.debit);
      expect(debits.matches(buyBtc), isTrue);
      expect(debits.matches(depositPending), isFalse);

      const pending = TransactionQuery(
        statuses: {TransactionStatus.pending, TransactionStatus.failed},
      );
      expect(pending.matches(depositPending), isTrue);
      expect(pending.matches(buyBtc), isFalse);

      final october = TransactionQuery(range: range);
      expect(october.matches(buyBtc), isTrue);
      expect(october.matches(oldDeposit), isFalse);

      const search = TransactionQuery(searchTerm: 'deposito');
      expect(search.matches(depositPending), isTrue);
      expect(search.matches(buyBtc), isFalse);
    });

    test('criteria are combined', () {
      final query = TransactionQuery(
        direction: TransactionDirection.credit,
        statuses: const {TransactionStatus.pending},
        range: range,
        searchTerm: 'pix',
      );
      expect(query.matches(depositPending), isTrue);
      expect(query.matches(oldDeposit), isFalse);
      expect(query.matches(buyBtc), isFalse);
    });
  });

  group('RN-17: search text', () {
    test('normalizes case, accents and spaces', () {
      expect(
        SearchText.normalize('  Depósito   PIX  Ção '),
        'deposito pix cao',
      );
      expect(
        SearchText.normalize('ÁÉÍÓÚ àèìòù âêîôû ãõ ç ñ ü'),
        'aeiou aeiou aeiou ao c n u',
      );
    });

    test('ignores terms shorter than 2 characters', () {
      expect(SearchText.toTerm(''), isNull);
      expect(SearchText.toTerm(' a '), isNull);
      expect(SearchText.toTerm('pi'), 'pi');
    });

    test('truncates to 50 characters', () {
      final term = SearchText.toTerm('x' * 80);
      expect(term, hasLength(SearchText.maxLength));
    });
  });

  group('RN-18: custom range validation', () {
    final today = CalendarDate(2026, 10, 31);

    DateRangeError? validate(
      CalendarDate first,
      CalendarDate last, {
      CalendarDate? oldest,
    }) => DateRangeValidator.validate(
      first: first,
      last: last,
      today: today,
      oldestAvailable: oldest,
    );

    test('accepts a valid range, including a single day and today', () {
      expect(validate(CalendarDate(2026, 10, 1), today), isNull);
      expect(validate(today, today), isNull);
    });

    test('rejects inverted, future, too long and unavailable ranges', () {
      expect(
        validate(CalendarDate(2026, 10, 2), CalendarDate(2026, 10, 1)),
        DateRangeError.startAfterEnd,
      );
      expect(
        validate(today, CalendarDate(2026, 11, 1)),
        DateRangeError.endInFuture,
      );
      expect(validate(today.addDays(-366), today), DateRangeError.tooLong);
      expect(validate(today.addDays(-365), today), isNull);
      expect(
        validate(
          CalendarDate(2026, 8, 1),
          today,
          oldest: CalendarDate(2026, 8, 2),
        ),
        DateRangeError.beforeAvailableData,
      );
    });
  });

  group('statement filter', () {
    test('initial filter has no active criteria', () {
      expect(StatementFilter.initial.activeCount, 0);
      expect(StatementFilter.initial.hasActiveCriteria, isFalse);
      expect(StatementFilter.initial.period, PeriodSelection.last30Days);
    });

    test('counts each criterion once and ignores the search', () {
      const filter = StatementFilter(
        direction: TransactionDirection.debit,
        statuses: {TransactionStatus.failed, TransactionStatus.pending},
        period: PeriodSelection.last7Days,
        search: 'btc',
      );
      expect(filter.activeCount, 3);
      expect(filter.hasActiveCriteria, isTrue);
      expect(const StatementFilter(search: ' x ').hasActiveCriteria, isTrue);
    });

    test('clearCriteria keeps only the search', () {
      const filter = StatementFilter(
        direction: TransactionDirection.debit,
        search: 'btc',
      );
      expect(filter.clearCriteria(), const StatementFilter(search: 'btc'));
    });

    test('filters with the same values are equal (no needless reloads)', () {
      expect(
        const StatementFilter(statuses: {TransactionStatus.failed}),
        const StatementFilter(statuses: {TransactionStatus.failed}),
      );
    });
  });

  group('RN-25/26: sync freshness', () {
    final now = DateTime.utc(2026, 11, 1, 12);

    test('never synced is stale and needs refresh', () {
      expect(SyncInfo.never.isStale(now), isTrue);
      expect(SyncInfo.never.needsRefresh(now), isTrue);
      expect(SyncInfo.never.hasData, isFalse);
    });

    test('fresh data within the TTL', () {
      final info = SyncInfo(
        lastSuccessAt: now.subtract(const Duration(minutes: 4)),
      );
      expect(info.isStale(now), isFalse);
      expect(info.needsRefresh(now), isFalse);
      expect(info.hasData, isTrue);
    });

    test('after the TTL it refreshes but is not stale yet', () {
      final info = SyncInfo(
        lastSuccessAt: now.subtract(const Duration(minutes: 5)),
      );
      expect(info.needsRefresh(now), isTrue);
      expect(info.isStale(now), isFalse);
    });

    test('stale after 15 minutes or when the last attempt failed', () {
      expect(
        SyncInfo(lastSuccessAt: now.subtract(const Duration(minutes: 16)))
            .isStale(now),
        isTrue,
      );
      expect(
        SyncInfo(
          lastSuccessAt: now,
          lastFailure: const NetworkFailure(),
        ).isStale(now),
        isTrue,
      );
    });
  });

  group('pages', () {
    test('hasMore depends on the next cursor', () {
      expect(const TransactionPage(items: []).hasMore, isFalse);
      expect(
        const TransactionPage(items: [], nextCursor: PageCursor('abc')).hasMore,
        isTrue,
      );
      expect(const PageCursor('a'), const PageCursor('a'));
      expect(const PageCursor('a').hashCode, const PageCursor('a').hashCode);
    });
  });
}
