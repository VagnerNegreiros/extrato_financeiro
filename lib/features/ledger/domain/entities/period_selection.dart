import 'package:extrato_financeiro/core/time/calendar_date.dart';
import 'package:extrato_financeiro/core/time/clock.dart';
import 'package:extrato_financeiro/core/time/date_range.dart';
import 'package:extrato_financeiro/core/time/local_calendar.dart';
import 'package:meta/meta.dart';

/// Inclusive span of local days, the user-facing view of a period.
typedef LocalDaySpan = ({CalendarDate first, CalendarDate last});

/// Period chosen in the dashboard or statement filters (RN-14/18).
///
/// Presets are relative to "today", so they are resolved against a [Clock]
/// at query time instead of being frozen when selected.
@immutable
sealed class PeriodSelection {
  const new();

  static const last7Days = PresetPeriod(7);
  static const last30Days = PresetPeriod(30);
  static const last90Days = PresetPeriod(90);
  static const List<PresetPeriod> presets = [last7Days, last30Days, last90Days];

  /// Default period (RN-14).
  static const PeriodSelection defaultPeriod = last30Days;

  LocalDaySpan localDays({
    required Clock clock,
    required LocalCalendar calendar,
  });

  DateRange toRange({required Clock clock, required LocalCalendar calendar}) {
    final span = localDays(clock: clock, calendar: calendar);
    return DateRange.localDays(span.first, span.last, calendar);
  }
}

/// The last [days] local days, including today.
final class PresetPeriod extends PeriodSelection {
  const new(this.days) : assert(days > 0, 'days must be positive');

  final int days;

  @override
  LocalDaySpan localDays({
    required Clock clock,
    required LocalCalendar calendar,
  }) {
    final today = calendar.dateOf(clock.nowUtc());
    return (first: today.addDays(-(days - 1)), last: today);
  }

  @override
  bool operator ==(Object other) => other is PresetPeriod && other.days == days;

  @override
  int get hashCode => days.hashCode;
}

/// A custom inclusive range of local days. Validate it first with
/// `DateRangeValidator` (RN-18).
final class CustomPeriod extends PeriodSelection {
  const new(this.first, this.last);

  final CalendarDate first;
  final CalendarDate last;

  @override
  LocalDaySpan localDays({
    required Clock clock,
    required LocalCalendar calendar,
  }) => (first: first, last: last);

  @override
  bool operator ==(Object other) =>
      other is CustomPeriod && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);
}
