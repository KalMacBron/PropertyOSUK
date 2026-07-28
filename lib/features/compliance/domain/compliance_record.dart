enum ComplianceStatus { compliant, dueSoon, overdue, notRecorded }

extension ComplianceStatusLabel on ComplianceStatus {
  String get label => switch (this) {
        ComplianceStatus.compliant => 'Compliant',
        ComplianceStatus.dueSoon => 'Due soon',
        ComplianceStatus.overdue => 'Overdue',
        ComplianceStatus.notRecorded => 'Not recorded',
      };
}

class ComplianceType {
  const ComplianceType({
    required this.id,
    required this.code,
    required this.name,
    required this.usesReviewDate,
  });

  factory ComplianceType.fromJson(Map<String, dynamic> json) => ComplianceType(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        usesReviewDate:
            json['code'] == 'smoke_alarms' || json['code'] == 'co_alarms',
      );

  static const supportedCodes = [
    'gas_safety',
    'eicr',
    'epc',
    'smoke_alarms',
    'co_alarms',
  ];

  final String id;
  final String code;
  final String name;
  final bool usesReviewDate;
}

class ComplianceRecord {
  const ComplianceRecord({
    required this.id,
    required this.propertyId,
    required this.requirementTypeId,
    this.issueDate,
    this.expiryDate,
    this.reviewDate,
    this.referenceNumber,
    this.notes,
  });

  factory ComplianceRecord.fromJson(Map<String, dynamic> json) =>
      ComplianceRecord(
        id: json['id'] as String,
        propertyId: json['property_id'] as String,
        requirementTypeId: json['requirement_type_id'] as String,
        issueDate: _date(json['issue_date']),
        expiryDate: _date(json['expiry_date']),
        reviewDate: _date(json['review_date']),
        referenceNumber: json['reference_number'] as String?,
        notes: json['notes'] as String?,
      );

  final String id;
  final String propertyId;
  final String requirementTypeId;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final DateTime? reviewDate;
  final String? referenceNumber;
  final String? notes;

  DateTime? get actionDate => expiryDate ?? reviewDate;

  ComplianceStatus statusOn(DateTime today) =>
      complianceStatusFor(actionDate: actionDate, today: today);
}

ComplianceStatus complianceStatusFor({
  required DateTime? actionDate,
  required DateTime today,
}) {
  if (actionDate == null) return ComplianceStatus.notRecorded;
  final date = DateTime(actionDate.year, actionDate.month, actionDate.day);
  final current = DateTime(today.year, today.month, today.day);
  if (date.isBefore(current)) return ComplianceStatus.overdue;
  if (!date.isAfter(current.add(const Duration(days: 30)))) {
    return ComplianceStatus.dueSoon;
  }
  return ComplianceStatus.compliant;
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);
