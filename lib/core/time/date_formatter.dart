import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:intl/intl.dart';

/// pt-BR date formatting, always shown in the local zone (RN-11).
///
/// Requires `initializeDateFormatting('pt_BR')` to have run (done in `main`).
final class AppDateFormatter {
  new({required this._calendar, required this._clock});

  static const _locale = 'pt_BR';

  final LocalCalendar _calendar;
  final Clock _clock;

  // Patterns are compiled once; DateFormat construction is not free.
  late final _time = DateFormat('HH:mm', _locale);
  late final _shortDate = DateFormat('dd/MM', _locale);
  late final _numericDate = DateFormat('dd/MM/yyyy', _locale);
  late final _longDate = DateFormat("d 'de' MMMM 'de' y", _locale);
  late final _weekday = DateFormat('EEEE', _locale);

  /// `14:32`
  String time(DateTime utc) => _time.format(_calendar.toLocal(utc));

  /// `30/10`
  String shortDate(DateTime utc) => _shortDate.format(_calendar.toLocal(utc));

  /// `30/10/2026 às 14:32`
  String dateTime(DateTime utc) {
    final local = _calendar.toLocal(utc);
    return '${_numericDate.format(local)} às ${_time.format(local)}';
  }

  /// `30 de outubro de 2026`
  String longDate(CalendarDate date) => _longDate.format(_fields(date));

  /// `sexta-feira`
  String weekday(CalendarDate date) => _weekday.format(_fields(date));

  /// Statement group header (RN-20): "Hoje", "Ontem" or the long date.
  String dayHeader(CalendarDate date) {
    final today = _calendar.dateOf(_clock.nowUtc());
    if (date == today) return 'Hoje';
    if (date == today.addDays(-1)) return 'Ontem';
    return longDate(date);
  }

  /// ISO-8601 in UTC, for technical metadata (`2026-10-30T17:32:00.000Z`).
  String isoUtc(DateTime instant) => instant.toUtc().toIso8601String();

  static DateTime _fields(CalendarDate date) =>
      DateTime.utc(date.year, date.month, date.day);
}
