enum ComplianceStatus { compliant, dueSoon, overdue, notRecorded }

const trackedRequirementCodes = <String>{
  'gas_safety',
  'eicr',
  'epc',
  'smoke_alarms',
  'co_alarms',
  'landlord_registration',
};

const epcRequirementCode = 'epc';

class ComplianceRequirement {
  const ComplianceRequirement({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.defaultWarningDays,
    this.defaultValidityMonths,
  });

  factory ComplianceRequirement.fromJson(Map<String, dynamic> json) =>
      ComplianceRequirement(
        id: json['id'] as String,
        code: json['code'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        defaultWarningDays: json['default_warning_days'] as int,
        defaultValidityMonths: json['default_validity_months'] as int?,
      );

  final String id;
  final String code;
  final String name;
  final String description;
  final int defaultWarningDays;

  /// How long a certificate of this type normally lasts, used to suggest an
  /// expiry date. Null when the type has no standard validity period.
  final int? defaultValidityMonths;

  /// The suggested expiry date for a certificate issued on [issueDate], or
  /// null when this type has no standard validity period.
  DateTime? suggestedExpiryFor(DateTime issueDate) {
    final months = defaultValidityMonths;
    return months == null ? null : addCalendarMonths(issueDate, months);
  }
}

/// Words for a validity period, such as "1 year" or "5 years".
String validityLabel(int months) {
  if (months % 12 == 0) {
    final years = months ~/ 12;
    return years == 1 ? '1 year' : '$years years';
  }
  return months == 1 ? '1 month' : '$months months';
}

/// Adds whole calendar months, keeping the day of the month where it exists
/// and otherwise using the last day of the target month (29/02 + 12 months
/// becomes 28/02).
DateTime addCalendarMonths(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
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
    this.reminderDays,
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
        reminderDays: json['reminder_days'] as int?,
      );

  final String id;
  final String propertyId;
  final String requirementTypeId;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final DateTime? reviewDate;
  final String? referenceNumber;
  final String? notes;

  /// Days before the due date that the reminder starts. Null uses the
  /// requirement type default.
  final int? reminderDays;

  DateTime? get applicableDate => expiryDate ?? reviewDate;

  int warningDaysFor(ComplianceRequirement requirement) =>
      reminderDays ?? requirement.defaultWarningDays;

  /// The day the renewal reminder starts, or null without a due date.
  DateTime? reminderDateFor(ComplianceRequirement requirement) {
    final due = applicableDate;
    if (due == null) return null;
    return DateTime(due.year, due.month, due.day)
        .subtract(Duration(days: warningDaysFor(requirement)));
  }

  bool isExpiredOn(DateTime day) {
    final due = applicableDate;
    if (due == null) return false;
    return DateTime(due.year, due.month, due.day)
        .isBefore(DateTime(day.year, day.month, day.day));
  }

  ComplianceStatus statusOn(DateTime today, {int warningDays = 30}) {
    final dueDate = applicableDate;
    if (dueDate == null) return ComplianceStatus.notRecorded;
    final day = DateTime(today.year, today.month, today.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (due.isBefore(day)) return ComplianceStatus.overdue;
    if (!due.isAfter(day.add(Duration(days: warningDays)))) {
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

  /// The status of [requirement] on [today], using the record's own reminder
  /// lead time when it has one.
  ComplianceStatus statusFor(
    ComplianceRequirement requirement,
    DateTime today,
  ) {
    final record = recordFor(requirement.id);
    return record?.statusOn(
          today,
          warningDays: record.warningDaysFor(requirement),
        ) ??
        ComplianceStatus.notRecorded;
  }
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

/// A prompt for a tenancy starting on [tenancyStart], based on the property's
/// EPC record. An EPC lasts 10 years and an expired one only needs renewing
/// when a new tenancy starts, so this is the point to flag it.
///
/// Returns null when the EPC is valid on the start date.
String? epcPromptForNewTenancy({
  required ComplianceRecord? epcRecord,
  required DateTime tenancyStart,
}) {
  final expiry = epcRecord?.expiryDate;
  if (epcRecord == null || expiry == null) {
    return 'No EPC is recorded for this property. A valid EPC is needed '
        'before a new tenancy starts.';
  }
  final start =
      DateTime(tenancyStart.year, tenancyStart.month, tenancyStart.day);
  if (!epcRecord.isExpiredOn(start)) return null;
  return 'The EPC for this property expired on '
      '${_displayDate(expiry)}. A new EPC is needed before this tenancy '
      'starts.';
}

/// The property's EPC record, or null when none is recorded.
ComplianceRecord? epcRecordFor(
  PropertyCompliance? property,
  List<ComplianceRequirement> requirements,
) {
  if (property == null) return null;
  for (final requirement in requirements) {
    if (requirement.code == epcRequirementCode) {
      return property.recordFor(requirement.id);
    }
  }
  return null;
}

String _displayDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/'
    '${value.month.toString().padLeft(2, '0')}/'
    '${value.year.toString().padLeft(4, '0')}';
