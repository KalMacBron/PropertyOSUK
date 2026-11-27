/// Day arithmetic on calendar dates that is safe across UK clock changes.
///
/// `Duration(days: n)` is exactly n × 24 hours, but a local calendar day is
/// 23 or 25 hours long when the clocks change. Adding a `Duration` to a local
/// date therefore drifts by an hour and can land on the wrong date (for
/// example 11/03 minus 30 days becoming 10/03 23:00). Use these helpers for
/// any date-only logic instead.
library;

/// Returns midnight on the date [days] calendar days after [date] (negative
/// values go back). The time of day on [date] is ignored.
DateTime addCalendarDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

/// Returns the number of calendar days from [from] to [to]: positive when
/// [to] is later, negative when it is earlier. Times of day are ignored.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;
