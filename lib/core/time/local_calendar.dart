import 'package:extrato_financeiro/core/time/calendar_date.dart';

/// Converts UTC instants to the user's local calendar and back (RN-11/15).
///
/// Instants are stored in UTC; only this abstraction knows about time zones,
/// so day-rollover rules can be tested in any zone without changing the
/// machine's time zone.
abstract interface class LocalCalendar {
  /// Wall-clock fields (year to millisecond) of [utc] in the local zone.
  ///
  /// Only the fields are meaningful; do not rely on `isUtc` of the result.
  DateTime toLocal(DateTime utc);

  /// Local calendar day that contains [utc].
  CalendarDate dateOf(DateTime utc);

  /// UTC instant at which [date] starts in the local zone.
  DateTime startOfDayUtc(CalendarDate date);
}

/// Uses the device time zone, including its daylight-saving rules.
final class DeviceLocalCalendar implements LocalCalendar {
  const new();

  @override
  DateTime toLocal(DateTime utc) => utc.toLocal();

  @override
  CalendarDate dateOf(DateTime utc) {
    final local = utc.toLocal();
    return CalendarDate(local.year, local.month, local.day);
  }

  // Dart moves a non-existent local midnight (DST gap) to the first valid
  // instant of the day, which is exactly the start of that day.
  @override
  DateTime startOfDayUtc(CalendarDate date) =>
      DateTime(date.year, date.month, date.day).toUtc();
}

/// Calendar whose UTC offset is a function of the instant.
///
/// `OffsetLocalCalendar.fixed` covers zones without daylight saving; passing
/// a function allows
/// modelling offset transitions in tests.
final class OffsetLocalCalendar implements LocalCalendar {
  const new(this._offsetAt);

  factory fixed(Duration offset) => OffsetLocalCalendar((_) => offset);

  final Duration Function(DateTime utc) _offsetAt;

  @override
  DateTime toLocal(DateTime utc) {
    final instant = utc.toUtc();
    return instant.add(_offsetAt(instant));
  }

  @override
  CalendarDate dateOf(DateTime utc) {
    final local = toLocal(utc);
    return CalendarDate(local.year, local.month, local.day);
  }

  @override
  DateTime startOfDayUtc(CalendarDate date) {
    final midnightFields = DateTime.utc(date.year, date.month, date.day);
    // The offset at midnight may differ from the offset one guess away when a
    // transition happens around it, so both candidates are checked and the
    // earliest instant that already belongs to [date] wins.
    final first = midnightFields.subtract(_offsetAt(midnightFields));
    final second = midnightFields.subtract(_offsetAt(first));
    final candidates = [first, second]..sort();
    return candidates.firstWhere(
      (candidate) => dateOf(candidate) == date,
      orElse: () => first,
    );
  }
}
