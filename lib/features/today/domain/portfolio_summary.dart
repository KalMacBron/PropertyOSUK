import 'package:property_os/features/compliance/domain/compliance_models.dart';

class PortfolioSummary {
  const PortfolioSummary({
    required this.propertyCount,
    required this.compliant,
    required this.dueSoon,
    required this.overdue,
    required this.notRecorded,
  });

  final int propertyCount;
  final int compliant;
  final int dueSoon;
  final int overdue;
  final int notRecorded;

  int get complianceChecks => compliant + dueSoon + overdue + notRecorded;
  int get needingAttention => dueSoon + overdue + notRecorded;
}

PortfolioSummary buildPortfolioSummary({
  required List<PropertyCompliance> properties,
  required List<ComplianceRequirement> requirements,
  required DateTime today,
}) {
  var compliant = 0;
  var dueSoon = 0;
  var overdue = 0;
  var notRecorded = 0;

  for (final property in properties) {
    for (final requirement in requirements) {
      final status = property.recordFor(requirement.id)?.statusOn(
                today,
                warningDays: requirement.defaultWarningDays,
              ) ??
          ComplianceStatus.notRecorded;
      switch (status) {
        case ComplianceStatus.compliant:
          compliant++;
          break;
        case ComplianceStatus.dueSoon:
          dueSoon++;
          break;
        case ComplianceStatus.overdue:
          overdue++;
          break;
        case ComplianceStatus.notRecorded:
          notRecorded++;
          break;
      }
    }
  }

  return PortfolioSummary(
    propertyCount: properties.length,
    compliant: compliant,
    dueSoon: dueSoon,
    overdue: overdue,
    notRecorded: notRecorded,
  );
}
