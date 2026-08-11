import 'package:property_os/features/tasks/domain/task_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TaskRepository {
  const TaskRepository(this._client);

  final SupabaseClient _client;

  Future<List<PortfolioTask>> listTasks(String organisationId) async {
    final results = await Future.wait([
      _client
          .from('tasks')
          .select()
          .eq('organisation_id', organisationId)
          .order('due_date', nullsFirst: false)
          .order('created_at', ascending: false),
      _client
          .from('properties')
          .select('id, address_line_1, postcode')
          .eq('organisation_id', organisationId),
      _client
          .from('property_compliance_records')
          .select('id, requirement_type_id')
          .eq('organisation_id', organisationId),
    ]);
    final propertyNames = <String, String>{
      for (final property in results[1])
        property['id'] as String: _propertyName(property),
    };
    final requirementIds = <String, String>{
      for (final record in results[2])
        record['id'] as String: record['requirement_type_id'] as String,
    };
    return results[0]
        .map(
          (row) => PortfolioTask.fromJson(
            row,
            propertyName: propertyNames[row['property_id']],
            requirementTypeId: requirementIds[row['compliance_record_id']],
          ),
        )
        .toList();
  }

  Future<String> createTask(CreateTaskInput input) => _client.rpc<String>(
        input.maintenanceIssueId == null
            ? 'create_manual_task'
            : 'create_maintenance_task',
        params: {
          if (input.maintenanceIssueId == null) ...{
            'target_organisation_id': input.organisationId,
            'target_property_id': input.propertyId,
          } else
            'target_maintenance_issue_id': input.maintenanceIssueId,
          'task_title': input.title,
          'task_description': input.description,
          'task_priority': input.priority.name,
          'task_due_date': input.dueDate == null ? null : _date(input.dueDate!),
        },
      );

  Future<String> transitionTask(String taskId, TaskState state) =>
      _client.rpc<String>(
        'transition_task',
        params: {'target_task_id': taskId, 'target_state': state.value},
      );

  Future<String> updateTask(UpdateTaskInput input) => _client.rpc<String>(
        'update_task_details',
        params: {
          'target_task_id': input.taskId,
          'target_property_id': input.propertyId,
          'task_title': input.title,
          'task_description': input.description,
          'task_priority': input.priority.name,
          'task_due_date': input.dueDate == null ? null : _date(input.dueDate!),
        },
      );

  static String _propertyName(Map<String, dynamic> property) {
    final address = property['address_line_1'] as String;
    final postcode = property['postcode'] as String?;
    return postcode == null || postcode.isEmpty
        ? address
        : '$address, $postcode';
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
