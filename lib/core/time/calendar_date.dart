import 'package:meta/meta.dart';

/// A day on the user's local calendar, without time or time zone.
///
/// Used to group transactions and to build periods: "31/10" means the same
/// thing regardless of the instant, while its UTC boundaries depend on the
/// time zone (see `LocalCalendar`).
@immutable
final class CalendarDate implements Comparable<CalendarDate> {
  /// Normalizes out-of-range values (e.g. day 32 becomes the next month).
  factory(int year, int month, int day) {
    final normalized = DateTime.utc(year, month, day);
    return CalendarDate._(normalized.year, normalized.month, normalized.day);
  }

  const new _(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  CalendarDate addDays(int days) => CalendarDate(year, month, day + days);

  /// Whole days from this date to [other] (positive when [other] is later).
  int daysUntil(CalendarDate other) =>
      _asUtcMidnight(other).difference(_asUtcMidnight(this)).inDays;

  bool isBefore(CalendarDate other) => compareTo(other) < 0;
  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  /// Midnight UTC of this date. Only for date arithmetic, not an instant.
  static DateTime _asUtcMidnight(CalendarDate date) =>
      DateTime.utc(date.year, date.month, date.day);

  @override
  int compareTo(CalendarDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '$year-${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';
}
