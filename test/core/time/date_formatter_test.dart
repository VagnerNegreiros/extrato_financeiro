import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/core/time/date_formatter.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  // 22:30 on 31/10 in UTC-3.
  final clock = FixedClock(DateTime.utc(2026, 11, 1, 1, 30));
  final formatter = AppDateFormatter(
    calendar: OffsetLocalCalendar.fixed(const Duration(hours: -3)),
    clock: clock,
  );

  group('RN-11: shown in local time', () {
    test('time and dates use the local offset', () {
      final instant = DateTime.utc(2026, 10, 30, 17, 32);
      expect(formatter.time(instant), '14:32');
      expect(formatter.shortDate(instant), '30/10');
      expect(formatter.dateTime(instant), '30/10/2026 às 14:32');
    });

    test('date changes when crossing local midnight', () {
      expect(formatter.shortDate(DateTime.utc(2026, 11, 1, 2, 59)), '31/10');
      expect(formatter.shortDate(DateTime.utc(2026, 11, 1, 3)), '01/11');
    });

    test('ISO metadata stays in UTC', () {
      expect(
        formatter.isoUtc(DateTime.utc(2026, 10, 30, 17, 32)),
        '2026-10-30T17:32:00.000Z',
      );
    });
  });

  group('RN-20: day headers', () {
    test('today and yesterday are relative to the local date', () {
      expect(formatter.dayHeader(CalendarDate(2026, 10, 31)), 'Hoje');
      expect(formatter.dayHeader(CalendarDate(2026, 10, 30)), 'Ontem');
    });

    test('older days use the long pt-BR date', () {
      expect(
        formatter.dayHeader(CalendarDate(2026, 10, 28)),
        '28 de outubro de 2026',
      );
      expect(
        formatter.longDate(CalendarDate(2026, 3, 1)),
        '1 de março de 2026',
      );
      expect(formatter.weekday(CalendarDate(2026, 10, 30)), 'sexta-feira');
    });
  });
}
