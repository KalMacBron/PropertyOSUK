import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/expenses/domain/expense_models.dart';
import 'package:property_os/features/property_dashboard/application/property_dashboard_summary.dart';
import 'package:property_os/features/tasks/domain/task_models.dart';
import 'package:property_os/features/tenancies/domain/tenancy_models.dart';

void main() {
  test('summarises property compliance without including another property', () {
    final counts = propertyComplianceCounts(
      property: PropertyCompliance(
        id: 'property',
        name: 'Oak House',
        address: '1 Oak Road',
        postcode: 'AA1 1AA',
        records: [
          ComplianceRecord(
            id: 'gas-record',
            propertyId: 'property',
            requirementTypeId: 'gas',
            expiryDate: DateTime(2030),
          ),
        ],
      ),
      requirements: const [
        ComplianceRequirement(
          id: 'gas',
          code: 'gas_safety',
          name: 'Gas safety',
          description: '',
          defaultWarningDays: 45,
        ),
        ComplianceRequirement(
          id: 'epc',
          code: 'epc',
          name: 'EPC',
          description: '',
          defaultWarningDays: 30,
        ),
      ],
      today: DateTime(2026, 8, 10),
    );

    expect(counts[ComplianceStatus.compliant], 1);
    expect(counts[ComplianceStatus.notRecorded], 1);
  });

  test('summarises property tasks and recent completion', () {
    final now = DateTime(2026, 8, 10);
    final summary = propertyTaskSummary([
      _task('open', propertyId: 'property', dueDate: DateTime(2026, 8, 9)),
      _task(
        'completed',
        propertyId: 'property',
        state: TaskState.completed,
        completedAt: DateTime(2026, 8, 5),
      ),
      _task('other', propertyId: 'other'),
    ], 'property', now: now);

    expect(summary.open, 1);
    expect(summary.overdue, 1);
    expect(summary.recentlyCompleted, 1);
    expect(summary.attention.single.id, 'open');
  });

  test('totals only current-year expenses for the property', () {
    final expenses = [
      _expense('one', 'property', DateTime(2026, 1, 1), 10000),
      _expense('two', 'property', DateTime(2025, 1, 1), 20000),
      _expense('three', 'other', DateTime(2026, 1, 1), 30000),
    ];

    expect(propertyCurrentYearExpenseTotal(expenses, 'property', 2026), 10000);
  });

  test('highlights current tenancy before upcoming and historical', () {
    final today = DateTime(2026, 8, 10);
    final result = highlightedPropertyTenancy([
      _tenancy('history', DateTime(2025), actualEnd: DateTime(2025, 12, 31)),
      _tenancy('upcoming', DateTime(2027)),
      _tenancy('current', DateTime(2026, 1, 1)),
    ], 'property', today);

    expect(result?.id, 'current');
  });
}

PortfolioTask _task(
  String id, {
  required String propertyId,
  TaskState state = TaskState.open,
  DateTime? dueDate,
  DateTime? completedAt,
}) =>
    PortfolioTask(
      id: id,
      organisationId: 'organisation',
      propertyId: propertyId,
      title: id,
      priority: TaskPriority.medium,
      state: state,
      dueDate: dueDate,
      completedAt: completedAt,
      sourceType: 'manual',
      createdAt: DateTime(2026),
    );

PropertyExpense _expense(
        String id, String propertyId, DateTime date, int pence) =>
    PropertyExpense(
      id: id,
      organisationId: 'organisation',
      propertyId: propertyId,
      propertyName: 'Oak House',
      ownershipEntityId: 'owner',
      ownershipEntityName: 'Owner',
      expenseDate: date,
      description: id,
      category: 'repairs_maintenance',
      amountPence: pence,
      vatTreatment: 'no_vat',
      paymentStatus: 'paid',
      createdAt: date,
    );

PortfolioTenancy _tenancy(String id, DateTime start, {DateTime? actualEnd}) =>
    PortfolioTenancy(
      id: id,
      organisationId: 'organisation',
      propertyId: 'property',
      propertyName: 'Oak House',
      tenantDisplayName: id,
      startDate: start,
      actualEndDate: actualEnd,
      status: actualEnd == null ? 'active' : 'archived',
    );
