import 'dart:math';
import 'dart:typed_data';

import 'package:property_os/features/documents/domain/compliance_evidence.dart';
import 'package:property_os/features/expenses/domain/expense_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExpenseRepository {
  const ExpenseRepository(this._client);

  static const _bucket = 'property-documents';
  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  Future<List<ExpenseProperty>> listProperties(String organisationId) async {
    final rows = await _client
        .from('properties')
        .select(
          'id, display_name, address_line_1, postcode, '
          'property_ownerships(ownership_entities(id, legal_name))',
        )
        .eq('organisation_id', organisationId)
        .eq('status', 'active')
        .order('address_line_1');
    return rows.map(ExpenseProperty.fromJson).toList();
  }

  Future<List<PropertyExpense>> listExpenses(String organisationId) async {
    final rows = await _client
        .from('property_expenses')
        .select(
          '*, '
          'properties!expenses_property_organisation_fkey('
          'display_name, address_line_1), '
          'expense_ownership:property_ownerships!expenses_ownership_fkey('
          'ownership_entities!'
          'property_ownerships_ownership_entity_id_organisation_id_fkey('
          'legal_name)), '
          'property_compliance_records!expenses_compliance_fkey('
          'reference_number, compliance_requirement_types(name)), '
          'documents!documents_expense_fkey('
          'id, original_filename, storage_bucket, storage_path)',
        )
        .eq('organisation_id', organisationId)
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false);
    return rows.map(PropertyExpense.fromJson).toList();
  }

  Future<List<Map<String, dynamic>>> listComplianceRecords(
    String organisationId,
    String propertyId,
  ) {
    return _client
        .from('property_compliance_records')
        .select(
          'id, reference_number, compliance_requirement_types(name)',
        )
        .eq('organisation_id', organisationId)
        .eq('property_id', propertyId);
  }

  Future<String> saveExpense({
    String? id,
    required String organisationId,
    required String propertyId,
    required String ownershipEntityId,
    required DateTime expenseDate,
    required String description,
    required String category,
    required int amountPence,
    required String vatTreatment,
    required String paymentStatus,
    String? supplier,
    int? vatAmountPence,
    String? notes,
    String? complianceRecordId,
  }) async {
    final values = {
      'organisation_id': organisationId,
      'property_id': propertyId,
      'ownership_entity_id': ownershipEntityId,
      'compliance_record_id': complianceRecordId,
      'expense_date': _date(expenseDate),
      'supplier': _optional(supplier),
      'description': description.trim(),
      'category': category,
      'amount_pence': amountPence,
      'vat_treatment': vatTreatment,
      'vat_amount_pence': vatAmountPence,
      'payment_status': paymentStatus,
      'notes': _optional(notes),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      final row = await _client
          .from('property_expenses')
          .insert({...values, 'created_by': _userId})
          .select('id')
          .single();
      return row['id'] as String;
    }
    values.remove('organisation_id');
    await _client.from('property_expenses').update(values).eq('id', id);
    return id;
  }

  Future<void> deleteExpense(PropertyExpense expense) async {
    final evidence = expense.evidence;
    if (evidence != null) {
      await _client.from('documents').delete().eq('id', evidence.id);
      await _client.storage.from(evidence.bucket).remove([evidence.path]);
    }
    await _client.from('property_expenses').delete().eq('id', expense.id);
  }

  Future<void> uploadEvidence({
    required PropertyExpense expense,
    required EvidenceFile file,
  }) async {
    final validation = validateEvidenceFile(file);
    if (validation != null) throw ExpenseValidationException(validation);
    if (expense.evidence != null) {
      throw const ExpenseValidationException(
        'Remove the existing evidence before uploading a replacement.',
      );
    }
    final documentId = _newUuid();
    final filename = sanitiseEvidenceFilename(file.name);
    final path = '${expense.organisationId}/${expense.propertyId}/'
        '${expense.id}/$documentId/$filename';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          Uint8List.fromList(file.bytes),
          fileOptions: FileOptions(contentType: file.mimeType, upsert: false),
        );
    try {
      await _client.from('documents').insert({
        'id': documentId,
        'organisation_id': expense.organisationId,
        'property_id': expense.propertyId,
        'expense_id': expense.id,
        'scope': 'property',
        'document_type': 'expense_evidence',
        'original_filename': file.name,
        'storage_bucket': _bucket,
        'storage_path': path,
        'mime_type': file.mimeType,
        'size_bytes': file.sizeBytes,
        'state': 'uploaded',
        'created_by': _userId,
      });
    } catch (_) {
      await _client.storage.from(_bucket).remove([path]);
      rethrow;
    }
  }

  Future<String> evidenceUrl(ExpenseEvidence evidence) =>
      _client.storage.from(evidence.bucket).createSignedUrl(evidence.path, 60);

  Future<void> deleteEvidence(ExpenseEvidence evidence) async {
    await _client.from('documents').delete().eq('id', evidence.id);
    await _client.storage.from(evidence.bucket).remove([evidence.path]);
  }

  String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
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

class ExpenseValidationException implements Exception {
  const ExpenseValidationException(this.message);
  final String message;
}
