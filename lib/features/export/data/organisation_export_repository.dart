import 'package:property_os/features/export/domain/organisation_export_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrganisationExportRepository {
  const OrganisationExportRepository(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>> exportData(String organisationId) =>
      _client.rpc<Map<String, dynamic>>(
        'export_organisation_data',
        params: {'target_organisation_id': organisationId},
      );

  Future<List<ExportDocument>> listDocuments(String organisationId) async {
    final rows = await _client.rpc<List<dynamic>>(
      'list_organisation_export_documents',
      params: {'target_organisation_id': organisationId},
    );
    return rows
        .cast<Map<String, dynamic>>()
        .map(ExportDocument.fromJson)
        .toList();
  }

  Future<String> authorisedDocumentUrl({
    required String organisationId,
    required String documentId,
  }) async {
    final payload = await _client.rpc<Map<String, dynamic>>(
      'prepare_organisation_document_export',
      params: {
        'target_organisation_id': organisationId,
        'target_document_id': documentId,
      },
    );
    final prepared = PreparedExportDocument.fromJson(payload);
    return _client.storage
        .from(prepared.storageBucket)
        .createSignedUrl(prepared.storagePath, 60);
  }
}
