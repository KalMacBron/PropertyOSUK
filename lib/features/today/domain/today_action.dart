class TodayAction {
  const TodayAction({
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.reason,
    required this.priority,
    this.propertyId,
    this.requirementTypeId,
    this.evidenceDocumentId,
    this.dueDate,
  });

  factory TodayAction.fromJson(Map<String, dynamic> json) {
    return TodayAction(
      sourceType: json['source_type'] as String,
      sourceId: json['source_id'] as String,
      title: json['title'] as String,
      reason: json['reason'] as String,
      priority: json['priority'] as String,
      propertyId: json['property_id'] as String?,
      requirementTypeId: json['requirement_type_id'] as String?,
      evidenceDocumentId: json['evidence_document_id'] as String?,
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
    );
  }

  final String sourceType;
  final String sourceId;
  final String title;
  final String reason;
  final String priority;
  final String? propertyId;
  final String? requirementTypeId;
  final String? evidenceDocumentId;
  final DateTime? dueDate;

  bool get canComplete => sourceType == 'compliance' && dueDate != null;
}
