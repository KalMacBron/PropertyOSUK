import 'package:property_os/features/today/domain/today_action.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TodayRepository {
  const TodayRepository(this._client);

  final SupabaseClient _client;

  Future<List<TodayAction>> fetchActions(String organisationId) async {
    final rows = await _client
        .from('today_actions')
        .select()
        .eq('organisation_id', organisationId)
        .order('due_date');

    return rows.map(TodayAction.fromJson).toList();
  }

  Future<String> completeComplianceAction(TodayAction action) async {
    final dueDate = action.dueDate;
    if (!action.canComplete || dueDate == null) {
      throw StateError('Only dated compliance actions can be completed.');
    }
    return _client.rpc<String>(
      'complete_compliance_today_action',
      params: {
        'target_source_id': action.sourceId,
        'target_due_date': _dateValue(dueDate),
      },
    );
  }

  String _dateValue(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
