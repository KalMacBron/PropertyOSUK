import 'package:property_os/features/compliance/domain/compliance_models.dart';

/// The single source of the words used for compliance statuses.
///
/// "Current" means a record exists and its date is outside the warning
/// window. It deliberately avoids "Compliant", which would imply that
/// PropertyOS certifies compliance.
const overdueStatusLabel = 'Overdue';
const dueSoonStatusLabel = 'Due soon';
const notRecordedStatusLabel = 'Not recorded';
const currentStatusLabel = 'Current';

String complianceStatusLabel(ComplianceStatus status) => switch (status) {
      ComplianceStatus.compliant => currentStatusLabel,
      ComplianceStatus.dueSoon => dueSoonStatusLabel,
      ComplianceStatus.overdue => overdueStatusLabel,
      ComplianceStatus.notRecorded => notRecordedStatusLabel,
    };
