import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/today/data/today_repository.dart';
import 'package:property_os/features/today/domain/today_action.dart';

final todayRepositoryProvider = Provider<TodayRepository>(
  (ref) => TodayRepository(ref.watch(supabaseProvider)),
);

final todayActionsProvider = FutureProvider<List<TodayAction>>((ref) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref.watch(todayRepositoryProvider).fetchActions(organisation.id);
});
