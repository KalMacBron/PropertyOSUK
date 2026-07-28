import 'package:property_os/features/compliance/domain/compliance_models.dart';

enum DashboardStatus { overdue, expiringSoon, compliant, missingInformation }

class ComplianceDashboardItem {
  const ComplianceDashboardItem({
    required this.property,
    required this.requirement,
    required this.status,
    required this.daysUntilDue,
    this.record,
  });

  final PropertyCompliance property;
  final ComplianceRequirement requirement;
  final ComplianceRecord? record;
  final DashboardStatus status;
  final int? daysUntilDue;

  DateTime? get dueDate => record?.applicableDate;
  String? get referenceNumber => record?.referenceNumber;
}

class DashboardCounts {
  const DashboardCounts({
    required this.overdue,
    required this.expiringSoon,
    required this.compliant,
    required this.missingInformation,
  });

  final int overdue;
  final int expiringSoon;
  final int compliant;
  final int missingInformation;

  int countFor(DashboardStatus status) => switch (status) {
        DashboardStatus.overdue => overdue,
        DashboardStatus.expiringSoon => expiringSoon,
        DashboardStatus.compliant => compliant,
        DashboardStatus.missingInformation => missingInformation,
      };
}

List<ComplianceDashboardItem> buildDashboardItems({
  required List<PropertyCompliance> properties,
  required List<ComplianceRequirement> requirements,
  required DateTime today,
  required int warningDays,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final items = <ComplianceDashboardItem>[];

  for (final property in properties) {
    for (final requirement in requirements) {
      final record = property.recordFor(requirement.id);
      final dueDate = record?.applicableDate;
      final due = dueDate == null
          ? null
          : DateTime(dueDate.year, dueDate.month, dueDate.day);
      final days = due?.difference(day).inDays;
      final status = switch (days) {
        null => DashboardStatus.missingInformation,
        < 0 => DashboardStatus.overdue,
        <= warningDays => DashboardStatus.expiringSoon,
        _ => DashboardStatus.compliant,
      };
      items.add(
        ComplianceDashboardItem(
          property: property,
          requirement: requirement,
          record: record,
          status: status,
          daysUntilDue: days,
        ),
      );
    }
  }

  items.sort(compareDashboardItems);
  return items;
}

int compareDashboardItems(
  ComplianceDashboardItem left,
  ComplianceDashboardItem right,
) {
  int rank(ComplianceDashboardItem item) {
    if (item.status == DashboardStatus.overdue) return 0;
    if (item.status == DashboardStatus.expiringSoon &&
        item.daysUntilDue == 0) {
      return 1;
    }
    if (item.status == DashboardStatus.expiringSoon) return 2;
    if (item.status == DashboardStatus.missingInformation) return 3;
    return 4;
  }

  final rankComparison = rank(left).compareTo(rank(right));
  if (rankComparison != 0) return rankComparison;

  final leftDue = left.dueDate;
  final rightDue = right.dueDate;
  if (leftDue != null && rightDue != null) {
    final dueComparison = leftDue.compareTo(rightDue);
    if (dueComparison != 0) return dueComparison;
  }

  final propertyComparison = left.property.name.compareTo(right.property.name);
  if (propertyComparison != 0) return propertyComparison;
  return left.requirement.name.compareTo(right.requirement.name);
}

DashboardCounts dashboardCounts(Iterable<ComplianceDashboardItem> items) {
  var overdue = 0;
  var expiringSoon = 0;
  var compliant = 0;
  var missingInformation = 0;
  for (final item in items) {
    switch (item.status) {
      case DashboardStatus.overdue:
        overdue++;
        break;
      case DashboardStatus.expiringSoon:
        expiringSoon++;
        break;
      case DashboardStatus.compliant:
        compliant++;
        break;
      case DashboardStatus.missingInformation:
        missingInformation++;
        break;
    }
  }
  return DashboardCounts(
    overdue: overdue,
    expiringSoon: expiringSoon,
    compliant: compliant,
    missingInformation: missingInformation,
  );
}

String attentionSummary(DashboardCounts counts, int warningDays) {
  final overdueLabel =
      '${counts.overdue} certificate${counts.overdue == 1 ? '' : 's'}';
  final expiringLabel =
      '${counts.expiringSoon} expire${counts.expiringSoon == 1 ? 's' : ''}';
  return '$overdueLabel overdue and $expiringLabel within the next '
      '$warningDays days.';
}

DateTime europeLondonToday([DateTime? instant]) {
  final utc = (instant ?? DateTime.now()).toUtc();
  final year = utc.year;
  final bstStarts = _lastSundayUtc(year, DateTime.march, 1);
  final bstEnds = _lastSundayUtc(year, DateTime.october, 1);
  final london = !utc.isBefore(bstStarts) && utc.isBefore(bstEnds)
      ? utc.add(const Duration(hours: 1))
      : utc;
  return DateTime(london.year, london.month, london.day);
}

DateTime _lastSundayUtc(int year, int month, int hour) {
  final lastDay = DateTime.utc(year, month + 1, 0);
  final sunday = lastDay.day - (lastDay.weekday % DateTime.daysPerWeek);
  return DateTime.utc(year, month, sunday, hour);
}
