import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/maintenance/data/maintenance_repository.dart';
import 'package:property_os/features/maintenance/domain/maintenance_models.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>(
  (ref) => MaintenanceRepository(ref.watch(supabaseProvider)),
);

final maintenanceIssuesProvider = FutureProvider<List<MaintenanceIssue>>((
  ref,
) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref.watch(maintenanceRepositoryProvider).listIssues(organisation.id);
});

final maintenanceContractorsProvider =
    FutureProvider<List<MaintenanceContractor>>((ref) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref
      .watch(maintenanceRepositoryProvider)
      .listContractors(organisation.id);
});

final contractorDirectoryProvider =
    FutureProvider<List<MaintenanceContractor>>((ref) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref
      .watch(maintenanceRepositoryProvider)
      .listContractors(organisation.id, activeOnly: false);
});

void refreshMaintenance(WidgetRef ref) {
  ref.invalidate(maintenanceIssuesProvider);
  ref.invalidate(maintenanceContractorsProvider);
  ref.invalidate(contractorDirectoryProvider);
}
