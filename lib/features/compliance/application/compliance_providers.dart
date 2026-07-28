import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/compliance/data/compliance_repository.dart';
import 'package:property_os/features/compliance/domain/compliance_record.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';

final complianceRepositoryProvider = Provider<ComplianceRepository>(
  (ref) => ComplianceRepository(ref.watch(supabaseProvider)),
);

final complianceTypesProvider = FutureProvider<List<ComplianceType>>(
  (ref) => ref.watch(complianceRepositoryProvider).listTypes(),
);

final complianceRecordsProvider = FutureProvider<List<ComplianceRecord>>((
  ref,
) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref
      .watch(complianceRepositoryProvider)
      .listRecords(organisation.id);
});

void refreshCompliance(WidgetRef ref) {
  ref.invalidate(complianceRecordsProvider);
  ref.invalidate(propertiesProvider);
}
