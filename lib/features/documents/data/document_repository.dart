import 'dart:math';
import 'dart:typed_data';

import 'package:property_os/features/documents/domain/compliance_evidence.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentRepository {
  const DocumentRepository(this._client);

  static const bucket = 'property-documents';
  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  Future<List<ComplianceEvidence>> listComplianceEvidence(
    String organisationId,
    String complianceRecordId,
  ) async {
    final rows = await _client
        .from('documents')
        .select(
          'id, original_filename, storage_bucket, storage_path, mime_type, size_bytes, created_at',
        )
        .eq('organisation_id', organisationId)
        .eq('compliance_record_id', complianceRecordId)
        .eq('scope', 'compliance')
        .order('created_at', ascending: false);
    return rows.map(ComplianceEvidence.fromJson).toList();
  }

  Future<void> uploadComplianceEvidence({
    required String organisationId,
    required String propertyId,
    required String complianceRecordId,
    required EvidenceFile file,
  }) async {
    final validation = validateEvidenceFile(file);
    if (validation != null) throw EvidenceValidationException(validation);

    final documentId = _newUuid();
    final path = evidencePath(
      organisationId: organisationId,
      propertyId: propertyId,
      complianceRecordId: complianceRecordId,
      documentId: documentId,
      filename: file.name,
    );

    await _client.storage.from(bucket).uploadBinary(
          path,
          Uint8List.fromList(file.bytes),
          fileOptions: FileOptions(
            contentType: file.mimeType,
            upsert: false,
          ),
        );

    try {
      await _client.from('documents').insert({
        'id': documentId,
        'organisation_id': organisationId,
        'property_id': propertyId,
        'compliance_record_id': complianceRecordId,
        'scope': 'compliance',
        'document_type': 'compliance_evidence',
        'original_filename': file.name,
        'storage_bucket': bucket,
        'storage_path': path,
        'mime_type': file.mimeType,
        'size_bytes': file.sizeBytes,
        'state': 'uploaded',
        'created_by': _userId,
      });
    } catch (_) {
      try {
        await _client.storage.from(bucket).remove([path]);
      } catch (_) {
        throw const EvidenceUploadException(
          'The file metadata could not be saved and automatic cleanup failed. '
          'Please ask an administrator to remove the incomplete upload.',
        );
      }
      rethrow;
    }
  }

  Future<String> createViewUrl(ComplianceEvidence evidence) => _client.storage
      .from(evidence.storageBucket)
      .createSignedUrl(evidence.storagePath, 60);

  Future<void> deleteEvidence(ComplianceEvidence evidence) async {
    await _client.storage
        .from(evidence.storageBucket)
        .remove([evidence.storagePath]);
    await _client.from('documents').delete().eq('id', evidence.id);
  }

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

class EvidenceValidationException implements Exception {
  const EvidenceValidationException(this.message);
  final String message;
}

class EvidenceUploadException implements Exception {
  const EvidenceUploadException(this.message);
  final String message;
}
