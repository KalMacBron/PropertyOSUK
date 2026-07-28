import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

final portfolioRepositoryProvider = Provider<PortfolioRepository>(
  (ref) => PortfolioRepository(ref.watch(supabaseProvider)),
);

final organisationProvider = FutureProvider<OrganisationSummary?>(
  (ref) => ref.watch(portfolioRepositoryProvider).currentOrganisation(),
);

final ownershipEntitiesProvider = FutureProvider<List<OwnershipEntity>>((
  ref,
) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref
      .watch(portfolioRepositoryProvider)
      .listOwnershipEntities(organisation.id);
});

final propertiesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref.watch(portfolioRepositoryProvider).listProperties(organisation.id);
});
