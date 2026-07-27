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
}

