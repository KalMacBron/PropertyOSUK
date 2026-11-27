import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/core/dates/calendar_days.dart';

// UK clocks change on 28/03/2027 (forward) and 31/10/2027 (back). Run with
// TZ=Europe/London to exercise them; CI runs this file under both UTC and
// Europe/London.
void main() {
  group('addCalendarDays', () {
    test('lands on midnight of the right date across the spring change', () {
      expect(
          addCalendarDays(DateTime(2027, 4, 10), -30), DateTime(2027, 3, 11));
      expect(addCalendarDays(DateTime(2027, 3, 1), 35), DateTime(2027, 4, 5));
    });

    test('lands on midnight of the right date across the autumn change', () {
      expect(
          addCalendarDays(DateTime(2027, 11, 23), -31), DateTime(2027, 10, 23));
      expect(addCalendarDays(DateTime(2027, 10, 6), 30), DateTime(2027, 11, 5));
    });

    test('drops the time of day', () {
      expect(addCalendarDays(DateTime(2027, 1, 1, 15, 30), 1),
          DateTime(2027, 1, 2));
    });
  });

  group('calendarDaysBetween', () {
    test('counts whole days across both clock changes', () {
      expect(
          calendarDaysBetween(DateTime(2027, 3, 1), DateTime(2027, 4, 5)), 35);
      expect(calendarDaysBetween(DateTime(2027, 10, 1), DateTime(2027, 11, 5)),
          35);
    });

    test('ignores the time of day and goes negative when past', () {
      expect(
        calendarDaysBetween(
            DateTime(2027, 3, 29, 23, 59), DateTime(2027, 3, 28)),
        -1,
      );
    });
  });
}
