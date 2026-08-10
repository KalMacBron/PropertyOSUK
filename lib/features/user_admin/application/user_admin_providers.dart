import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/user_admin/data/user_admin_repository.dart';

final userAdminRepositoryProvider =
    Provider((ref) => UserAdminRepository(ref.watch(supabaseProvider)));
final organisationUsersProvider =
    FutureProvider<List<OrganisationUser>>((ref) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null ||
      (organisation.role != 'owner' && organisation.role != 'admin')) {
    return [];
  }
  return ref.watch(userAdminRepositoryProvider).list(organisation.id);
});

final invitationAcceptanceProvider = FutureProvider<int>((ref) async {
  final accepted = await ref.watch(userAdminRepositoryProvider).acceptMine();
  if (accepted > 0) {
    ref.invalidate(organisationMembershipsProvider);
  }
  return accepted;
});
