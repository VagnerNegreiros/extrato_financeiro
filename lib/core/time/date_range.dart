import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:meta/meta.dart';

/// Half-open interval of UTC instants `[startUtc, endUtc)` (RN-12).
///
/// Half-open ranges tile without gaps or overlaps: the end of one day is the
/// start of the next, so a transaction can never be counted twice.
@immutable
final class DateRange {
  factory(DateTime startUtc, DateTime endUtc) {
    if (!startUtc.isUtc || !endUtc.isUtc) {
      throw ArgumentError('DateRange bounds must be UTC instants.');
    }
    if (!startUtc.isBefore(endUtc)) {
      throw ArgumentError('DateRange start must be before its end.');
    }
    return DateRange._(startUtc, endUtc);
  }

  /// Every instant of the local days from [first] to [last], inclusive.
  factory localDays(
    CalendarDate first,
    CalendarDate last,
    LocalCalendar calendar,
  ) {
    if (last.isBefore(first)) {
      throw ArgumentError('Last day must not be before the first day.');
    }
    return DateRange(
      calendar.startOfDayUtc(first),
      calendar.startOfDayUtc(last.addDays(1)),
    );
  }

  /// The last [days] local days, including today (RN-14).
  factory lastDays(
    int days, {
    required Clock clock,
    required LocalCalendar calendar,
  }) {
    if (days < 1) throw ArgumentError.value(days, 'days', 'must be >= 1');
    final today = calendar.dateOf(clock.nowUtc());
    return DateRange.localDays(today.addDays(-(days - 1)), today, calendar);
  }

  const new _(this.startUtc, this.endUtc);

  final DateTime startUtc;

  /// Exclusive upper bound.
  final DateTime endUtc;

  bool contains(DateTime instant) {
    final utc = instant.toUtc();
    return !utc.isBefore(startUtc) && utc.isBefore(endUtc);
  }

  Duration get duration => endUtc.difference(startUtc);

  @override
  bool operator ==(Object other) =>
      other is DateRange &&
      other.startUtc == startUtc &&
      other.endUtc == endUtc;

  @override
  int get hashCode => Object.hash(startUtc, endUtc);

  @override
  String toString() =>
      'DateRange(${startUtc.toIso8601String()}, ${endUtc.toIso8601String()})';
}
