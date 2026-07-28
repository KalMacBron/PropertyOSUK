import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/compliance/data/compliance_repository.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';

final complianceRepositoryProvider = Provider<ComplianceRepository>(
  (ref) => ComplianceRepository(ref.watch(supabaseProvider)),
);

final complianceRequirementsProvider =
    FutureProvider<List<ComplianceRequirement>>((ref) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref
      .watch(complianceRepositoryProvider)
      .listRequirements(organisation.id);
});

final compliancePortfolioProvider =
    FutureProvider<List<PropertyCompliance>>((ref) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref
      .watch(complianceRepositoryProvider)
      .listPortfolio(organisation.id);
});

void refreshCompliance(WidgetRef ref) {
  ref.invalidate(compliancePortfolioProvider);
  ref.invalidate(propertiesProvider);
}
