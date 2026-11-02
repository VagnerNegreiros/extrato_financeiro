import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/core/time/date_range.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final saoPaulo = OffsetLocalCalendar.fixed(const Duration(hours: -3));
  final tokyo = OffsetLocalCalendar.fixed(const Duration(hours: 9));
  final utc = OffsetLocalCalendar.fixed(Duration.zero);

  group('CalendarDate', () {
    test('normalizes overflowing days and months', () {
      expect(CalendarDate(2026, 10, 32), CalendarDate(2026, 11, 1));
      expect(CalendarDate(2026, 13, 1), CalendarDate(2027, 1, 1));
      expect(CalendarDate(2024, 2, 30), CalendarDate(2024, 3, 1));
    });

    test('adds days across months, years and leap days', () {
      expect(CalendarDate(2026, 12, 31).addDays(1), CalendarDate(2027, 1, 1));
      expect(CalendarDate(2024, 3, 1).addDays(-1), CalendarDate(2024, 2, 29));
      expect(
        CalendarDate(2026, 1, 1).daysUntil(CalendarDate(2026, 12, 31)),
        364,
      );
    });

    test('ordering', () {
      expect(
        CalendarDate(2026, 1, 2).isAfter(CalendarDate(2026, 1, 1)),
        isTrue,
      );
      expect(
        CalendarDate(2025, 12, 31).isBefore(CalendarDate(2026, 1, 1)),
        isTrue,
      );
      expect(CalendarDate(2026, 3, 4).toString(), '2026-03-04');
      expect(
        CalendarDate(2026, 3, 4).hashCode,
        CalendarDate(2026, 2, 32).hashCode,
      );
      expect(CalendarDate(2026, 3, 4).compareTo(CalendarDate(2026, 3, 4)), 0);
      expect(
        CalendarDate(2026, 3, 4).compareTo(CalendarDate(2026, 2, 28)),
        greaterThan(0),
      );
    });
  });

  group('RN-12/13: local days and UTC boundaries', () {
    test('a day in UTC-3 starts at 03:00Z', () {
      final range = DateRange.localDays(
        CalendarDate(2026, 10, 31),
        CalendarDate(2026, 10, 31),
        saoPaulo,
      );
      expect(range.startUtc, DateTime.utc(2026, 10, 31, 3));
      expect(range.endUtc, DateTime.utc(2026, 11, 1, 3));
    });

    test('01:30Z on 01/11 belongs to 31/10 in UTC-3', () {
      final instant = DateTime.utc(2026, 11, 1, 1, 30);
      expect(saoPaulo.dateOf(instant), CalendarDate(2026, 10, 31));
      expect(utc.dateOf(instant), CalendarDate(2026, 11, 1));
      expect(tokyo.dateOf(instant), CalendarDate(2026, 11, 1));
    });

    test('22:00Z on 31/10 is already 01/11 in UTC+9', () {
      final instant = DateTime.utc(2026, 10, 31, 22);
      expect(tokyo.dateOf(instant), CalendarDate(2026, 11, 1));
      expect(tokyo.toLocal(instant).hour, 7);
    });

    test('range is half-open: end instant belongs to the next day', () {
      final range = DateRange.localDays(
        CalendarDate(2026, 10, 31),
        CalendarDate(2026, 10, 31),
        saoPaulo,
      );
      expect(range.contains(DateTime.utc(2026, 10, 31, 3)), isTrue);
      expect(range.contains(DateTime.utc(2026, 11, 1, 2, 59, 59, 999)), isTrue);
      expect(range.contains(DateTime.utc(2026, 11, 1, 3)), isFalse);
      expect(range.contains(DateTime.utc(2026, 10, 31, 2, 59)), isFalse);
    });

    test('consecutive days tile without gaps or overlap', () {
      final day1 = DateRange.localDays(
        CalendarDate(2026, 10, 30),
        CalendarDate(2026, 10, 30),
        saoPaulo,
      );
      final day2 = DateRange.localDays(
        CalendarDate(2026, 10, 31),
        CalendarDate(2026, 10, 31),
        saoPaulo,
      );
      expect(day1.endUtc, day2.startUtc);
    });

    test('daylight saving transition keeps days contiguous', () {
      // Offset changes from -3h to -2h at 03:00Z on 2018-11-04, so local
      // midnight does not exist that day (historical Brazilian DST).
      final transition = DateTime.utc(2018, 11, 4, 3);
      final dst = OffsetLocalCalendar(
        (instant) => instant.isBefore(transition)
            ? const Duration(hours: -3)
            : const Duration(hours: -2),
      );

      final start = dst.startOfDayUtc(CalendarDate(2018, 11, 4));
      expect(start, transition);
      expect(dst.toLocal(start).hour, 1);
      expect(
        dst.dateOf(start.subtract(const Duration(milliseconds: 1))),
        CalendarDate(2018, 11, 3),
      );

      // The next day has a normal midnight under the new offset.
      expect(
        dst.startOfDayUtc(CalendarDate(2018, 11, 5)),
        DateTime.utc(2018, 11, 5, 2),
      );
      // That shorter day lasts 23 hours.
      final range = DateRange.localDays(
        CalendarDate(2018, 11, 4),
        CalendarDate(2018, 11, 4),
        dst,
      );
      expect(range.duration, const Duration(hours: 23));
    });

    test('device calendar round-trips local days', () {
      const calendar = DeviceLocalCalendar();
      final date = CalendarDate(2026, 10, 31);
      final start = calendar.startOfDayUtc(date);
      expect(start.isUtc, isTrue);
      expect(calendar.dateOf(start), date);
      expect(
        calendar.dateOf(start.subtract(const Duration(milliseconds: 1))),
        CalendarDate(2026, 10, 30),
      );
      expect(calendar.toLocal(start).hour, 0);
    });
  });

  group('RN-10: ranges only accept UTC instants', () {
    test('rejects local DateTimes', () {
      expect(
        () => DateRange(DateTime(2026), DateTime.utc(2026, 2)),
        throwsArgumentError,
      );
    });

    test('rejects empty or inverted ranges', () {
      final instant = DateTime.utc(2026);
      expect(() => DateRange(instant, instant), throwsArgumentError);
      expect(
        () => DateRange.localDays(
          CalendarDate(2026, 1, 2),
          CalendarDate(2026, 1, 1),
          utc,
        ),
        throwsArgumentError,
      );
    });

    test('contains converts local instants to UTC', () {
      final range = DateRange(DateTime.utc(2026), DateTime.utc(2026, 1, 2));
      expect(range.contains(DateTime.utc(2026, 1, 1, 12).toLocal()), isTrue);
    });
  });

  group('RN-14: presets include today', () {
    test('last 30 days in UTC-3 at 01:30Z on 01/11', () {
      // Local time is 22:30 on 31/10, so "today" is 31/10.
      final clock = FixedClock(DateTime.utc(2026, 11, 1, 1, 30));
      final range = DateRange.lastDays(30, clock: clock, calendar: saoPaulo);

      expect(saoPaulo.dateOf(range.startUtc), CalendarDate(2026, 10, 2));
      expect(range.endUtc, DateTime.utc(2026, 11, 1, 3));
      expect(range.contains(clock.nowUtc()), isTrue);
    });

    test('last 1 day is just today', () {
      final clock = FixedClock(DateTime.utc(2026, 11, 2, 12));
      final range = DateRange.lastDays(1, clock: clock, calendar: utc);
      expect(range.duration, const Duration(days: 1));
      expect(range.startUtc, DateTime.utc(2026, 11, 2));
    });

    test('rejects non-positive sizes', () {
      expect(
        () => DateRange.lastDays(
          0,
          clock: FixedClock(DateTime.utc(2026)),
          calendar: utc,
        ),
        throwsArgumentError,
      );
    });
  });

  group('RN-15: injected clock', () {
    test('fixed clock is UTC and can advance', () {
      final clock = FixedClock(DateTime.utc(2026, 11, 2, 10))
        ..advance(const Duration(hours: 2));
      expect(clock.nowUtc(), DateTime.utc(2026, 11, 2, 12));
      expect(clock.nowUtc().isUtc, isTrue);
    });

    test('system clock returns UTC', () {
      expect(const SystemClock().nowUtc().isUtc, isTrue);
    });

    test('range equality', () {
      final a = DateRange(DateTime.utc(2026), DateTime.utc(2026, 2));
      final b = DateRange(DateTime.utc(2026), DateTime.utc(2026, 2));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains('2026-01-01'));
    });
  });
}
