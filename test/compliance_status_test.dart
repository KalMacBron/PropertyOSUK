import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/compliance/domain/compliance_record.dart';

void main() {
  final today = DateTime(2026, 7, 28);

  test('missing action date is not recorded', () {
    expect(
      complianceStatusFor(actionDate: null, today: today),
      ComplianceStatus.notRecorded,
    );
  });

  test('yesterday is overdue', () {
    expect(
      complianceStatusFor(
        actionDate: DateTime(2026, 7, 27),
        today: today,
      ),
      ComplianceStatus.overdue,
    );
  });

  test('today and day 30 are due soon', () {
    expect(
      complianceStatusFor(actionDate: today, today: today),
      ComplianceStatus.dueSoon,
    );
    expect(
      complianceStatusFor(
        actionDate: DateTime(2026, 8, 27),
        today: today,
      ),
      ComplianceStatus.dueSoon,
    );
  });

  test('day 31 is compliant', () {
    expect(
      complianceStatusFor(
        actionDate: DateTime(2026, 8, 28),
        today: today,
      ),
      ComplianceStatus.compliant,
    );
  });

  test('time of day does not change calendar-date status', () {
    expect(
      complianceStatusFor(
        actionDate: DateTime(2026, 7, 28, 0, 1),
        today: DateTime(2026, 7, 28, 23, 59),
      ),
      ComplianceStatus.dueSoon,
    );
  });
}
