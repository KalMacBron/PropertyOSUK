import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/tasks/data/task_repository.dart';
import 'package:property_os/features/tasks/domain/task_models.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(supabaseProvider)),
);

final tasksProvider = FutureProvider<List<PortfolioTask>>((ref) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref.watch(taskRepositoryProvider).listTasks(organisation.id);
});
