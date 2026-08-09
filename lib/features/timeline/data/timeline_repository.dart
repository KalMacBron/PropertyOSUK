import 'package:property_os/features/timeline/domain/timeline_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TimelineRepository {
  const TimelineRepository(this._client);

  final SupabaseClient _client;

  Future<List<TimelineEvent>> listForProperty(String propertyId) async {
    final rows = await _client
        .from('timeline_events')
        .select('id, title, event_type, description, occurred_at')
        .eq('property_id', propertyId)
        .order('occurred_at', ascending: false);
    return rows.map(TimelineEvent.fromJson).toList();
  }
}
