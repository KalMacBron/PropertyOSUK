import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';

void main() {
  final today = DateTime(2026, 7, 28);

  ComplianceRecord record(DateTime? dueDate) => ComplianceRecord(
        id: 'record-id',
        propertyId: 'property-id',
        requirementTypeId: 'requirement-id',
        expiryDate: dueDate,
      );

  test('missing applicable date is not recorded', () {
    expect(record(null).statusOn(today), ComplianceStatus.notRecorded);
  });

  test('date before today is overdue', () {
    expect(
      record(DateTime(2026, 7, 27)).statusOn(today),
      ComplianceStatus.overdue,
    );
  });

  test('today and day 30 are due soon boundaries', () {
    expect(
      record(DateTime(2026, 7, 28)).statusOn(today),
      ComplianceStatus.dueSoon,
    );
    expect(
      record(DateTime(2026, 8, 27)).statusOn(today),
      ComplianceStatus.dueSoon,
    );
  });

  test('day 31 is compliant', () {
    expect(
      record(DateTime(2026, 8, 28)).statusOn(today),
      ComplianceStatus.compliant,
    );
  });

  test('review date is used when expiry is absent', () {
    final reviewRecord = ComplianceRecord(
      id: 'record-id',
      propertyId: 'property-id',
      requirementTypeId: 'requirement-id',
      reviewDate: DateTime(2026, 8, 28),
    );
    expect(reviewRecord.statusOn(today), ComplianceStatus.compliant);
  });
}
