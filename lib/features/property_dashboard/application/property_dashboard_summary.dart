import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/expenses/domain/expense_models.dart';
import 'package:property_os/features/tasks/domain/task_models.dart';
import 'package:property_os/features/tenancies/domain/tenancy_models.dart';

Map<ComplianceStatus, int> propertyComplianceCounts({
  required PropertyCompliance property,
  required List<ComplianceRequirement> requirements,
  required DateTime today,
}) {
  final counts = {for (final status in ComplianceStatus.values) status: 0};
  for (final requirement in requirements) {
    final status = property.recordFor(requirement.id)?.statusOn(
              today,
              warningDays: requirement.defaultWarningDays,
            ) ??
        ComplianceStatus.notRecorded;
    counts[status] = counts[status]! + 1;
  }
  return counts;
}

class PropertyTaskSummary {
  const PropertyTaskSummary({
    required this.open,
    required this.overdue,
    required this.recentlyCompleted,
    required this.attention,
  });

  final int open;
  final int overdue;
  final int recentlyCompleted;
  final List<PortfolioTask> attention;
}

PropertyTaskSummary propertyTaskSummary(
  List<PortfolioTask> tasks,
  String propertyId, {
  DateTime? now,
}) {
  final scoped = tasks.where((task) => task.propertyId == propertyId).toList();
  final day = now ?? DateTime.now();
  final recentBoundary = day.subtract(const Duration(days: 30));
  final open = scoped.where((task) => task.isOpen).toList()
    ..sort((a, b) {
      final priority = b.priority.index.compareTo(a.priority.index);
      if (priority != 0) return priority;
      return (a.dueDate ?? DateTime(9999)).compareTo(
        b.dueDate ?? DateTime(9999),
      );
    });
  return PropertyTaskSummary(
    open: open.length,
    overdue: scoped.where((task) => task.isOverdue).length,
    recentlyCompleted: scoped
        .where(
          (task) =>
              task.state == TaskState.completed &&
              task.completedAt != null &&
              !task.completedAt!.isBefore(recentBoundary),
        )
        .length,
    attention: open.take(3).toList(),
  );
}

int propertyCurrentYearExpenseTotal(
  List<PropertyExpense> expenses,
  String propertyId,
  int year,
) =>
    expenses
        .where(
          (expense) =>
              expense.propertyId == propertyId &&
              expense.expenseDate.year == year,
        )
        .fold(0, (total, expense) => total + expense.amountPence);

List<PropertyExpense> recentPropertyExpenses(
  List<PropertyExpense> expenses,
  String propertyId, {
  int limit = 3,
}) =>
    expenses
        .where((expense) => expense.propertyId == propertyId)
        .take(limit)
        .toList();

PortfolioTenancy? highlightedPropertyTenancy(
  List<PortfolioTenancy> tenancies,
  String propertyId,
  DateTime today,
) {
  final scoped =
      tenancies.where((item) => item.propertyId == propertyId).toList();
  for (final tenancy in scoped) {
    if (tenancy.isCurrent(today)) return tenancy;
  }
  final upcoming = scoped.where((item) => item.isUpcoming(today)).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  if (upcoming.isNotEmpty) return upcoming.first;
  final historical = scoped.where((item) => item.isEnded).toList()
    ..sort(
      (a, b) => (b.actualEndDate ?? b.startDate).compareTo(
        a.actualEndDate ?? a.startDate,
      ),
    );
  return historical.isEmpty ? null : historical.first;
}
