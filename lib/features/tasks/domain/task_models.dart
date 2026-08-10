enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  String get label => switch (this) {
        low => 'Low',
        medium => 'Medium',
        high => 'High',
        urgent => 'Urgent',
      };
}

enum TaskState {
  open,
  inProgress,
  completed,
  cancelled;

  String get value => switch (this) {
        open => 'open',
        inProgress => 'in_progress',
        completed => 'completed',
        cancelled => 'cancelled',
      };

  String get label => switch (this) {
        open => 'Open',
        inProgress => 'In progress',
        completed => 'Completed',
        cancelled => 'Cancelled',
      };

  static TaskState fromValue(String value) => switch (value) {
        'in_progress' => inProgress,
        'completed' => completed,
        'cancelled' => cancelled,
        _ => open,
      };
}

enum TaskFilter {
  all,
  overdue,
  upcoming,
  completed,
  cancelled;

  String get label => switch (this) {
        all => 'All',
        overdue => 'Overdue',
        upcoming => 'Upcoming',
        completed => 'Completed',
        cancelled => 'Cancelled',
      };
}

class PortfolioTask {
  const PortfolioTask({
    required this.id,
    required this.organisationId,
    required this.title,
    required this.priority,
    required this.state,
    required this.sourceType,
    required this.createdAt,
    this.propertyId,
    this.propertyName,
    this.complianceRecordId,
    this.requirementTypeId,
    this.description,
    this.dueDate,
    this.completedAt,
  });

  factory PortfolioTask.fromJson(
    Map<String, dynamic> json, {
    String? propertyName,
    String? requirementTypeId,
  }) =>
      PortfolioTask(
        id: json['id'] as String,
        organisationId: json['organisation_id'] as String,
        propertyId: json['property_id'] as String?,
        propertyName: propertyName,
        complianceRecordId: json['compliance_record_id'] as String?,
        requirementTypeId: requirementTypeId,
        title: json['title'] as String,
        description: json['description'] as String?,
        priority: TaskPriority.values.firstWhere(
          (priority) => priority.name == json['priority'],
          orElse: () => TaskPriority.medium,
        ),
        state: TaskState.fromValue(json['state'] as String),
        dueDate: json['due_date'] == null
            ? null
            : DateTime.parse(json['due_date'] as String),
        sourceType: json['source_type'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        completedAt: json['completed_at'] == null
            ? null
            : DateTime.parse(json['completed_at'] as String),
      );

  final String id;
  final String organisationId;
  final String? propertyId;
  final String? propertyName;
  final String? complianceRecordId;
  final String? requirementTypeId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final TaskState state;
  final DateTime? dueDate;
  final String sourceType;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isOpen => state == TaskState.open || state == TaskState.inProgress;
  bool get isOverdue {
    final due = dueDate;
    if (!isOpen || due == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return due.isBefore(today);
  }
}

class CreateTaskInput {
  const CreateTaskInput({
    required this.organisationId,
    required this.propertyId,
    required this.title,
    required this.priority,
    this.description,
    this.dueDate,
  });

  final String organisationId;
  final String propertyId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime? dueDate;
}

class UpdateTaskInput {
  const UpdateTaskInput({
    required this.taskId,
    required this.propertyId,
    required this.title,
    required this.priority,
    this.description,
    this.dueDate,
  });

  final String taskId;
  final String propertyId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime? dueDate;
}
