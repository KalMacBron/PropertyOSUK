enum ComplianceStatus { compliant, dueSoon, overdue, notRecorded }

const trackedRequirementCodes = <String>{
  'gas_safety',
  'eicr',
  'epc',
  'smoke_alarms',
  'co_alarms',
};

class ComplianceRequirement {
  const ComplianceRequirement({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
  });

  factory ComplianceRequirement.fromJson(Map<String, dynamic> json) =>
      ComplianceRequirement(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
      );

  final String id;
  final String code;
  final String name;
  final String description;
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

  DateTime? get applicableDate => expiryDate ?? reviewDate;

  ComplianceStatus statusOn(DateTime today) {
    final dueDate = applicableDate;
    if (dueDate == null) return ComplianceStatus.notRecorded;
    final day = DateTime(today.year, today.month, today.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (due.isBefore(day)) return ComplianceStatus.overdue;
    if (!due.isAfter(day.add(const Duration(days: 30)))) {
      return ComplianceStatus.dueSoon;
    }
    return ComplianceStatus.compliant;
  }
}

class PropertyCompliance {
  const PropertyCompliance({
    required this.id,
    required this.name,
    required this.address,
    required this.postcode,
    required this.records,
  });

  final String id;
  final String name;
  final String address;
  final String postcode;
  final List<ComplianceRecord> records;

  ComplianceRecord? recordFor(String requirementId) {
    for (final record in records) {
      if (record.requirementTypeId == requirementId) return record;
    }
    return null;
  }
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);
