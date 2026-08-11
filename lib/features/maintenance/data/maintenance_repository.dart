import 'dart:math';
import 'dart:typed_data';

import 'package:property_os/features/documents/data/document_repository.dart';
import 'package:property_os/features/documents/domain/compliance_evidence.dart';
import 'package:property_os/features/maintenance/domain/maintenance_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceRepository {
  const MaintenanceRepository(this._client);

  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  Future<List<MaintenanceIssue>> listIssues(String organisationId) async {
    final rows = await _client
        .from('maintenance_issues')
        .select(
          '*, properties(display_name,address_line_1,postcode), '
          'contractors(name,trade), '
          'documents(id,original_filename,storage_bucket,storage_path,'
          'mime_type,size_bytes,created_at)',
        )
        .eq('organisation_id', organisationId)
        .order('updated_at', ascending: false);
    return rows.map(MaintenanceIssue.fromJson).toList();
  }

  Future<List<MaintenanceContractor>> listContractors(
    String organisationId, {
    bool activeOnly = true,
  }) async {
    var query = _client
        .from('contractors')
        .select('id,organisation_id,name,trade,email,phone,notes,status')
        .eq('organisation_id', organisationId);
    if (activeOnly) query = query.eq('status', 'active');
    final rows = await query.order('name');
    return rows.map(MaintenanceContractor.fromJson).toList();
  }

  Future<String> saveContractor(ContractorInput input) {
    final params = {
      'contractor_name': input.name.trim(),
      'contractor_trade': _optional(input.trade),
      'contractor_email': _optional(input.email),
      'contractor_phone': _optional(input.phone),
      'contractor_notes': _optional(input.notes),
    };
    if (input.contractorId == null) {
      return _client.rpc<String>(
        'create_contractor',
        params: {
          ...params,
          'target_organisation_id': input.organisationId,
        },
      );
    }
    return _client.rpc<String>(
      'update_contractor',
      params: {
        ...params,
        'target_contractor_id': input.contractorId,
        'contractor_status': input.status,
      },
    );
  }

  Future<String> save(MaintenanceInput input) {
    final params = {
      'target_property_id': input.propertyId,
      'target_contractor_id': input.contractorId,
      'issue_title': input.title.trim(),
      'issue_description': _optional(input.description),
      'issue_priority': input.priority.name,
      'issue_reported_date': _date(input.reportedDate),
      'issue_target_date':
          input.targetDate == null ? null : _date(input.targetDate!),
      'issue_estimated_cost_pence': input.estimatedCostPence,
      'issue_notes': _optional(input.notes),
    };
    if (input.issueId == null) {
      return _client.rpc<String>(
        'create_maintenance_issue',
        params: {
          ...params,
          'target_organisation_id': input.organisationId,
        },
      );
    }
    return _client.rpc<String>(
      'update_maintenance_issue',
      params: {...params, 'target_issue_id': input.issueId},
    );
  }

  Future<String> transition({
    required String issueId,
    required MaintenanceState state,
    int? actualCostPence,
    String? completionNotes,
  }) =>
      _client.rpc<String>(
        'transition_maintenance_issue',
        params: {
          'target_issue_id': issueId,
          'target_state': state.value,
          'issue_actual_cost_pence': actualCostPence,
          'issue_completion_notes': _optional(completionNotes),
        },
      );

  Future<void> uploadEvidence({
    required MaintenanceIssue issue,
    required EvidenceFile file,
  }) async {
    final validation = validateEvidenceFile(file);
    if (validation != null) throw EvidenceValidationException(validation);
    final documentId = _newUuid();
    final filename = sanitiseEvidenceFilename(file.name);
    final path = '${issue.organisationId}/${issue.propertyId}/${issue.id}/'
        '$documentId/$filename';
    await _client.storage.from(DocumentRepository.bucket).uploadBinary(
          path,
          Uint8List.fromList(file.bytes),
          fileOptions: FileOptions(contentType: file.mimeType, upsert: false),
        );
    try {
      await _client.from('documents').insert({
        'id': documentId,
        'organisation_id': issue.organisationId,
        'property_id': issue.propertyId,
        'maintenance_issue_id': issue.id,
        'scope': 'maintenance',
        'document_type': 'maintenance_evidence',
        'original_filename': file.name,
        'storage_bucket': DocumentRepository.bucket,
        'storage_path': path,
        'mime_type': file.mimeType,
        'size_bytes': file.sizeBytes,
        'state': 'uploaded',
        'created_by': _userId,
      });
    } catch (_) {
      await _client.storage.from(DocumentRepository.bucket).remove([path]);
      rethrow;
    }
  }

  Future<String> evidenceUrl(ComplianceEvidence evidence) => _client.storage
      .from(evidence.storageBucket)
      .createSignedUrl(evidence.storagePath, 60);

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
