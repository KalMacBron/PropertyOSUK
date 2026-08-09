import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/timeline/data/timeline_repository.dart';
import 'package:property_os/features/timeline/domain/timeline_event.dart';

final timelineRepositoryProvider = Provider<TimelineRepository>(
  (ref) => TimelineRepository(ref.watch(supabaseProvider)),
);

final propertyTimelineProvider =
    FutureProvider.family<List<TimelineEvent>, String>((ref, propertyId) {
  return ref.watch(timelineRepositoryProvider).listForProperty(propertyId);
});
