import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

final portfolioRepositoryProvider = Provider<PortfolioRepository>(
  (ref) => PortfolioRepository(ref.watch(supabaseProvider)),
);

final organisationMembershipsProvider =
    FutureProvider<List<OrganisationSummary>>(
  (ref) => ref.watch(portfolioRepositoryProvider).listOrganisations(),
);

final activeOrganisationIdProvider = StateProvider<String?>((ref) => null);

final organisationProvider = FutureProvider<OrganisationSummary?>((ref) async {
  final organisations = await ref.watch(organisationMembershipsProvider.future);
  if (organisations.isEmpty) return null;

  final selectedId = ref.watch(activeOrganisationIdProvider);
  for (final organisation in organisations) {
    if (organisation.id == selectedId) return organisation;
  }
  for (final organisation in organisations) {
    if (organisation.isActive) return organisation;
  }
  return organisations.length == 1 ? organisations.single : null;
});

Future<void> selectOrganisation(
  WidgetRef ref,
  OrganisationSummary organisation,
) async {
  await ref
      .read(portfolioRepositoryProvider)
      .setActiveOrganisation(organisation.id);
  ref.read(activeOrganisationIdProvider.notifier).state = organisation.id;
  ref.invalidate(organisationMembershipsProvider);
}

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
