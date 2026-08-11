import 'package:property_os/features/documents/domain/compliance_evidence.dart';
import 'package:property_os/features/tasks/domain/task_models.dart';

enum MaintenanceState {
  reported,
  triaged,
  quoted,
  approved,
  scheduled,
  inProgress,
  resolved,
  cancelled;

  String get value => switch (this) {
        inProgress => 'in_progress',
        _ => name,
      };

  String get label => switch (this) {
        reported => 'Reported',
        triaged => 'Triaged',
        quoted => 'Quoted',
        approved => 'Approved',
        scheduled => 'Scheduled',
        inProgress => 'In progress',
        resolved => 'Resolved',
        cancelled => 'Cancelled',
      };

  bool get isTerminal => this == resolved || this == cancelled;

  static MaintenanceState fromValue(String value) => switch (value) {
        'triaged' => triaged,
        'quoted' => quoted,
        'approved' => approved,
        'scheduled' => scheduled,
        'in_progress' => inProgress,
        'resolved' => resolved,
        'cancelled' => cancelled,
        _ => reported,
      };
}

enum MaintenanceFilter {
  open,
  resolved,
  cancelled,
  all;

  String get label => switch (this) {
        open => 'Open',
        resolved => 'Resolved',
        cancelled => 'Cancelled',
        all => 'All',
      };
}

class MaintenanceContractor {
  const MaintenanceContractor({
    required this.id,
    required this.name,
    this.trade,
  });

  factory MaintenanceContractor.fromJson(Map<String, dynamic> json) =>
      MaintenanceContractor(
        id: json['id'] as String,
        name: json['name'] as String,
        trade: json['trade'] as String?,
      );

  final String id;
  final String name;
  final String? trade;
}

class MaintenanceIssue {
  const MaintenanceIssue({
    required this.id,
    required this.organisationId,
    required this.propertyId,
    required this.propertyName,
    required this.title,
    required this.priority,
    required this.state,
    required this.reportedAt,
    required this.createdAt,
    required this.updatedAt,
    this.contractorId,
    this.contractorName,
    this.description,
    this.targetDate,
    this.resolvedAt,
    this.estimatedCostPence,
    this.actualCostPence,
    this.notes,
    this.completionNotes,
    this.evidence = const [],
  });

  factory MaintenanceIssue.fromJson(Map<String, dynamic> json) {
    final property = json['properties'] as Map<String, dynamic>?;
    final contractor = json['contractors'] as Map<String, dynamic>?;
    final documents = json['documents'] as List<dynamic>? ?? const [];
    final displayName = (property?['display_name'] as String?)?.trim();
    return MaintenanceIssue(
      id: json['id'] as String,
      organisationId: json['organisation_id'] as String,
      propertyId: json['property_id'] as String,
      propertyName: displayName?.isNotEmpty == true
          ? displayName!
          : property?['address_line_1'] as String? ?? 'Property',
      contractorId: json['contractor_id'] as String?,
      contractorName: contractor?['name'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      priority: TaskPriority.values.firstWhere(
        (item) => item.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      state: MaintenanceState.fromValue(json['state'] as String),
      reportedAt: DateTime.parse(json['reported_at'] as String),
      targetDate: json['target_date'] == null
          ? null
          : DateTime.parse(json['target_date'] as String),
      resolvedAt: json['resolved_at'] == null
          ? null
          : DateTime.parse(json['resolved_at'] as String),
      estimatedCostPence: json['estimated_cost_pence'] as int?,
      actualCostPence: json['actual_cost_pence'] as int?,
      notes: json['notes'] as String?,
      completionNotes: json['completion_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      evidence: documents
          .map((item) =>
              ComplianceEvidence.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String organisationId;
  final String propertyId;
  final String propertyName;
  final String? contractorId;
  final String? contractorName;
  final String title;
  final String? description;
  final TaskPriority priority;
  final MaintenanceState state;
  final DateTime reportedAt;
  final DateTime? targetDate;
  final DateTime? resolvedAt;
  final int? estimatedCostPence;
  final int? actualCostPence;
  final String? notes;
  final String? completionNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ComplianceEvidence> evidence;

  bool get isOpen => !state.isTerminal;
  bool isOverdue(DateTime today) =>
      isOpen && targetDate != null && targetDate!.isBefore(_day(today));
}

class MaintenanceInput {
  const MaintenanceInput({
    required this.organisationId,
    required this.propertyId,
    required this.title,
    required this.priority,
    required this.reportedDate,
    this.issueId,
    this.contractorId,
    this.description,
    this.targetDate,
    this.estimatedCostPence,
    this.notes,
  });

  final String? issueId;
  final String organisationId;
  final String propertyId;
  final String? contractorId;
  final String title;
  final String? description;
  final TaskPriority priority;
  final DateTime reportedDate;
  final DateTime? targetDate;
  final int? estimatedCostPence;
  final String? notes;
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

List<MaintenanceIssue> filterMaintenanceIssues(
  List<MaintenanceIssue> issues,
  MaintenanceFilter filter, {
  String? propertyId,
  TaskPriority? priority,
  String query = '',
}) {
  final search = query.trim().toLowerCase();
  return issues.where((issue) {
    if (propertyId != null && issue.propertyId != propertyId) return false;
    if (priority != null && issue.priority != priority) return false;
    if (search.isNotEmpty &&
        !issue.title.toLowerCase().contains(search) &&
        !issue.propertyName.toLowerCase().contains(search)) {
      return false;
    }
    return switch (filter) {
      MaintenanceFilter.open => issue.isOpen,
      MaintenanceFilter.resolved => issue.state == MaintenanceState.resolved,
      MaintenanceFilter.cancelled => issue.state == MaintenanceState.cancelled,
      MaintenanceFilter.all => true,
    };
  }).toList();
}

({int open, int highUrgent, int overdue, List<MaintenanceIssue> recentResolved})
    propertyMaintenanceSummary(
  List<MaintenanceIssue> issues,
  String propertyId,
  DateTime today,
) {
  final scoped = issues.where((item) => item.propertyId == propertyId).toList();
  final resolved = scoped
      .where((item) => item.state == MaintenanceState.resolved)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return (
    open: scoped.where((item) => item.isOpen).length,
    highUrgent: scoped
        .where((item) =>
            item.isOpen &&
            (item.priority == TaskPriority.high ||
                item.priority == TaskPriority.urgent))
        .length,
    overdue: scoped.where((item) => item.isOverdue(today)).length,
    recentResolved: resolved.take(3).toList(),
  );
}
