import 'package:extrato_financeiro/core/time/calendar_date.dart';

/// Why a custom period was rejected (RN-18).
enum DateRangeError {
  /// The first day is after the last day.
  startAfterEnd,

  /// The last day is after today.
  endInFuture,

  /// More than [DateRangeValidator.maxDays] days.
  tooLong,

  /// Starts before the oldest transaction available in the cache.
  beforeAvailableData,
}

abstract final class DateRangeValidator {
  static const maxDays = 366;

  /// `null` when [first]..[last] is a valid custom period.
  static DateRangeError? validate({
    required CalendarDate first,
    required CalendarDate last,
    required CalendarDate today,
    CalendarDate? oldestAvailable,
  }) {
    if (first.isAfter(last)) return DateRangeError.startAfterEnd;
    if (last.isAfter(today)) return DateRangeError.endInFuture;
    if (first.daysUntil(last) + 1 > maxDays) return DateRangeError.tooLong;
    if (oldestAvailable != null && first.isBefore(oldestAvailable)) {
      return DateRangeError.beforeAvailableData;
    }
    return null;
  }
}
