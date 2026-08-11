import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/export/data/organisation_export_repository.dart';
import 'package:property_os/features/export/domain/organisation_export_models.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';

final organisationExportRepositoryProvider = Provider(
  (ref) => OrganisationExportRepository(ref.watch(supabaseProvider)),
);

final organisationExportDocumentsProvider =
    FutureProvider<List<ExportDocument>>((ref) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null ||
      !const ['owner', 'admin'].contains(organisation.role)) {
    return [];
  }
  return ref
      .watch(organisationExportRepositoryProvider)
      .listDocuments(organisation.id);
});
