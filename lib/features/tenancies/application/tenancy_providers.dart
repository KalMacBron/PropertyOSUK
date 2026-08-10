import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/tenancies/data/tenancy_repository.dart';
import 'package:property_os/features/tenancies/domain/tenancy_models.dart';

final tenancyRepositoryProvider = Provider<TenancyRepository>(
  (ref) => TenancyRepository(ref.watch(supabaseProvider)),
);

final tenanciesProvider = FutureProvider<List<PortfolioTenancy>>((ref) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref.watch(tenancyRepositoryProvider).listTenancies(organisation.id);
});
