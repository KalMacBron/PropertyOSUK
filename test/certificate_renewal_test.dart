import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/today/domain/compliance_dashboard.dart';

void main() {
  ComplianceRequirement requirement(
    String code, {
    int warningDays = 31,
    int? validityMonths,
  }) =>
      ComplianceRequirement(
        id: code,
        code: code,
        name: code,
        description: '',
        defaultWarningDays: warningDays,
        defaultValidityMonths: validityMonths,
      );

  ComplianceRecord record({
    String requirementId = 'gas_safety',
    DateTime? expiry,
    int? reminderDays,
  }) =>
      ComplianceRecord(
        id: 'record',
        propertyId: 'property',
        requirementTypeId: requirementId,
        expiryDate: expiry,
        reminderDays: reminderDays,
      );

  group('suggested expiry dates', () {
    test('gas safety defaults to one year after the issue date', () {
      final gas = requirement('gas_safety', validityMonths: 12);
      expect(gas.suggestedExpiryFor(DateTime(2026, 11, 23)),
          DateTime(2027, 11, 23));
    });

    test('EICR defaults to five years and EPC to ten years', () {
      expect(
        requirement('eicr', validityMonths: 60)
            .suggestedExpiryFor(DateTime(2026, 3, 15)),
        DateTime(2031, 3, 15),
      );
      expect(
        requirement('epc', validityMonths: 120)
            .suggestedExpiryFor(DateTime(2026, 3, 15)),
        DateTime(2036, 3, 15),
      );
    });

    test('landlord registration renews annually', () {
      expect(
        requirement('landlord_registration', validityMonths: 12)
            .suggestedExpiryFor(DateTime(2026, 12, 15)),
        DateTime(2027, 12, 15),
      );
    });

    test('a leap day moves to the last day of February', () {
      expect(
          addCalendarMonths(DateTime(2028, 2, 29), 12), DateTime(2029, 2, 28));
      expect(
          addCalendarMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    });

    test('types without a validity period suggest nothing', () {
      expect(
        requirement('smoke_alarms').suggestedExpiryFor(DateTime(2026, 1, 1)),
        isNull,
      );
    });

    test('validity periods read naturally', () {
      expect(validityLabel(12), '1 year');
      expect(validityLabel(60), '5 years');
      expect(validityLabel(6), '6 months');
    });
  });

  group('reminders', () {
    final gas = requirement('gas_safety');

    test('the default reminder starts one month before expiry', () {
      final value = record(expiry: DateTime(2027, 11, 23));
      expect(value.reminderDateFor(gas), DateTime(2027, 10, 23));
    });

    test('a reminder across the spring clock change keeps its date', () {
      final value = record(expiry: DateTime(2027, 4, 10), reminderDays: 30);
      expect(value.reminderDateFor(gas), DateTime(2027, 3, 11));
    });

    test('a due date exactly the warning period away is due soon in October',
        () {
      expect(
        record(expiry: DateTime(2027, 11, 5))
            .statusOn(DateTime(2027, 10, 6), warningDays: 30),
        ComplianceStatus.dueSoon,
      );
    });

    test('a record-level reminder overrides the default', () {
      final value = record(expiry: DateTime(2027, 11, 23), reminderDays: 60);
      expect(value.warningDaysFor(gas), 60);
      expect(
        value.statusOn(DateTime(2027, 9, 30),
            warningDays: value.warningDaysFor(gas)),
        ComplianceStatus.dueSoon,
      );
      expect(
        record(expiry: DateTime(2027, 11, 23)).statusOn(
          DateTime(2027, 9, 30),
          warningDays: gas.defaultWarningDays,
        ),
        ComplianceStatus.compliant,
      );
    });

    test('the dashboard honours a record-level reminder', () {
      final property = PropertyCompliance(
        id: 'property',
        name: 'Flat 1',
        address: '1 High Street',
        postcode: 'AB1 2CD',
        records: [record(expiry: DateTime(2027, 11, 23), reminderDays: 60)],
      );
      final item = buildDashboardItems(
        properties: [property],
        requirements: [gas],
        today: DateTime(2027, 9, 30),
        warningDays: 31,
      ).single;
      expect(item.status, DashboardStatus.expiringSoon);
    });
  });

  group('EPC on a new tenancy', () {
    final start = DateTime(2027, 1, 10);

    test('a valid EPC needs no prompt', () {
      expect(
        epcPromptForNewTenancy(
          epcRecord:
              record(requirementId: 'epc', expiry: DateTime(2027, 1, 10)),
          tenancyStart: start,
        ),
        isNull,
      );
    });

    test('an EPC expired before the tenancy starts is flagged', () {
      expect(
        epcPromptForNewTenancy(
          epcRecord: record(requirementId: 'epc', expiry: DateTime(2027, 1, 9)),
          tenancyStart: start,
        ),
        contains('expired on 09/01/2027'),
      );
    });

    test('a missing EPC is flagged', () {
      expect(
        epcPromptForNewTenancy(epcRecord: null, tenancyStart: start),
        contains('No EPC is recorded'),
      );
    });

    test('the EPC record is found by requirement code', () {
      final epc = requirement('epc');
      final property = PropertyCompliance(
        id: 'property',
        name: 'Flat 1',
        address: '1 High Street',
        postcode: 'AB1 2CD',
        records: [record(requirementId: 'epc', expiry: DateTime(2030, 1, 1))],
      );
      expect(
          epcRecordFor(property, [requirement('gas_safety'), epc])?.expiryDate,
          DateTime(2030, 1, 1));
    });
  });
}
