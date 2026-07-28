import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/today/domain/compliance_dashboard.dart';

void main() {
  const gas = ComplianceRequirement(
    id: 'gas',
    code: 'gas_safety',
    name: 'Gas Safety Certificate',
    description: '',
  );
  const eicr = ComplianceRequirement(
    id: 'eicr',
    code: 'eicr',
    name: 'Electrical inspection',
    description: '',
  );

  PropertyCompliance property(List<ComplianceRecord> records) =>
      PropertyCompliance(
        id: 'property-1',
        name: 'Alpha House',
        address: '1 Alpha Road, Walsall',
        postcode: 'WS1 1AA',
        records: records,
      );

  ComplianceRecord record(
    String id,
    String requirementId,
    DateTime? dueDate,
  ) =>
      ComplianceRecord(
        id: id,
        propertyId: 'property-1',
        requirementTypeId: requirementId,
        expiryDate: dueDate,
      );

  test('classifies confirmed dates for the selected warning window', () {
    final items = buildDashboardItems(
      properties: [
        property([
          record('gas-record', 'gas', DateTime(2026, 7, 27)),
          record('eicr-record', 'eicr', DateTime(2026, 8, 20)),
        ]),
      ],
      requirements: [gas, eicr],
      today: DateTime(2026, 7, 28),
      warningDays: 30,
    );

    expect(items[0].status, DashboardStatus.overdue);
    expect(items[0].daysUntilDue, -1);
    expect(items[1].status, DashboardStatus.expiringSoon);
    expect(items[1].daysUntilDue, 23);
  });

  test('recalculates expiring soon between 30 and 60 days', () {
    final portfolio = [
      property([record('gas-record', 'gas', DateTime(2026, 9, 10))]),
    ];
    final thirty = buildDashboardItems(
      properties: portfolio,
      requirements: [gas],
      today: DateTime(2026, 7, 28),
      warningDays: 30,
    );
    final sixty = buildDashboardItems(
      properties: portfolio,
      requirements: [gas],
      today: DateTime(2026, 7, 28),
      warningDays: 60,
    );

    expect(thirty.single.status, DashboardStatus.compliant);
    expect(sixty.single.status, DashboardStatus.expiringSoon);
  });

  test('creates one missing-information item per absent requirement', () {
    final items = buildDashboardItems(
      properties: [property(const [])],
      requirements: [gas, eicr],
      today: DateTime(2026, 7, 28),
      warningDays: 30,
    );

    expect(items, hasLength(2));
    expect(
      items.every(
        (item) => item.status == DashboardStatus.missingInformation,
      ),
      isTrue,
    );
  });

  test('orders overdue, due today, upcoming and missing information', () {
    const epc = ComplianceRequirement(
      id: 'epc',
      code: 'epc',
      name: 'EPC',
      description: '',
    );
    const smoke = ComplianceRequirement(
      id: 'smoke',
      code: 'smoke_alarms',
      name: 'Smoke alarms',
      description: '',
    );
    final items = buildDashboardItems(
      properties: [
        property([
          record('gas-record', 'gas', DateTime(2026, 7, 20)),
          record('eicr-record', 'eicr', DateTime(2026, 7, 28)),
          record('epc-record', 'epc', DateTime(2026, 8, 2)),
        ]),
      ],
      requirements: [gas, eicr, epc, smoke],
      today: DateTime(2026, 7, 28),
      warningDays: 30,
    );

    expect(
      items.map((item) => item.requirement.id),
      ['gas', 'eicr', 'epc', 'smoke'],
    );
  });

  test('uses the Europe London calendar date across BST midnight', () {
    expect(
      europeLondonToday(DateTime.utc(2026, 7, 28, 23, 30)),
      DateTime(2026, 7, 29),
    );
    expect(
      europeLondonToday(DateTime.utc(2026, 12, 28, 23, 30)),
      DateTime(2026, 12, 28),
    );
  });

  test('generates deterministic attention summary', () {
    const counts = DashboardCounts(
      overdue: 2,
      expiringSoon: 3,
      compliant: 4,
      missingInformation: 1,
    );
    expect(
      attentionSummary(counts, 30),
      '2 certificates overdue and 3 expire within the next 30 days.',
    );
  });
}
