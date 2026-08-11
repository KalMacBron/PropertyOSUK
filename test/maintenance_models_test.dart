import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/maintenance/domain/maintenance_models.dart';
import 'package:property_os/features/tasks/domain/task_models.dart';

void main() {
  test('filters open issues without leaking another property', () {
    final issues = [
      _issue('open', propertyId: 'property'),
      _issue(
        'resolved',
        propertyId: 'property',
        state: MaintenanceState.resolved,
      ),
      _issue('other', propertyId: 'other'),
    ];

    final result = filterMaintenanceIssues(
      issues,
      MaintenanceFilter.open,
      propertyId: 'property',
    );

    expect(result.map((item) => item.id), ['open']);
  });

  test('summarises open, high priority, overdue and recent resolved issues',
      () {
    final today = DateTime(2026, 8, 11);
    final result = propertyMaintenanceSummary([
      _issue(
        'urgent',
        propertyId: 'property',
        priority: TaskPriority.urgent,
        targetDate: DateTime(2026, 8, 10),
      ),
      _issue(
        'resolved',
        propertyId: 'property',
        state: MaintenanceState.resolved,
      ),
      _issue('other', propertyId: 'other', priority: TaskPriority.high),
    ], 'property', today);

    expect(result.open, 1);
    expect(result.highUrgent, 1);
    expect(result.overdue, 1);
    expect(result.recentResolved.single.id, 'resolved');
  });

  test('terminal maintenance states are explicit', () {
    expect(MaintenanceState.resolved.isTerminal, isTrue);
    expect(MaintenanceState.cancelled.isTerminal, isTrue);
    expect(MaintenanceState.inProgress.isTerminal, isFalse);
    expect(MaintenanceState.inProgress.value, 'in_progress');
  });
}

MaintenanceIssue _issue(
  String id, {
  required String propertyId,
  MaintenanceState state = MaintenanceState.reported,
  TaskPriority priority = TaskPriority.medium,
  DateTime? targetDate,
}) =>
    MaintenanceIssue(
      id: id,
      organisationId: 'organisation',
      propertyId: propertyId,
      propertyName: propertyId,
      title: id,
      priority: priority,
      state: state,
      reportedAt: DateTime(2026, 8, 1),
      targetDate: targetDate,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 10),
    );
