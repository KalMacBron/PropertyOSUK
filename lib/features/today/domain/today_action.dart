class TodayAction {
  const TodayAction({
    required this.title,
    required this.reason,
    required this.priority,
    this.propertyId,
    this.dueDate,
  });

  factory TodayAction.fromJson(Map<String, dynamic> json) {
    return TodayAction(
      title: json['title'] as String,
      reason: json['reason'] as String,
      priority: json['priority'] as String,
      propertyId: json['property_id'] as String?,
      dueDate: json['due_date'] == null
          ? null
          : DateTime.parse(json['due_date'] as String),
    );
  }

  final String title;
  final String reason;
  final String priority;
  final String? propertyId;
  final DateTime? dueDate;
}
