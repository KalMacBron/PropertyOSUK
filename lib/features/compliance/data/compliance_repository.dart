import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ComplianceRepository {
  const ComplianceRepository(this._client);
  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  Future<List<ComplianceRequirement>> listRequirements(
    String organisationId,
  ) async {
    final rows = await _client
        .from('compliance_requirement_types')
        .select('id, code, name, description')
        .or('organisation_id.is.null,organisation_id.eq.$organisationId')
        .inFilter('code', trackedRequirementCodes.toList())
        .order('name');
    return rows.map(ComplianceRequirement.fromJson).toList();
  }

  Future<List<PropertyCompliance>> listPortfolio(String organisationId) async {
    final propertyRows = await _client
        .from('properties')
        .select('id, display_name, address_line_1, town_or_city, postcode')
        .eq('organisation_id', organisationId)
        .eq('status', 'active')
        .order('address_line_1');
    final recordRows = await _client
        .from('property_compliance_records')
        .select(
          'id, property_id, requirement_type_id, issue_date, expiry_date, review_date, reference_number, notes',
        )
        .eq('organisation_id', organisationId);
    final records = recordRows.map(ComplianceRecord.fromJson).toList();

    return propertyRows.map((row) {
      final id = row['id'] as String;
      final address = '${row['address_line_1']}, ${row['town_or_city']}';
      return PropertyCompliance(
        id: id,
        name: (row['display_name'] as String?)?.trim().isNotEmpty == true
            ? row['display_name'] as String
            : row['address_line_1'] as String,
        address: address,
        postcode: row['postcode'] as String,
        records: records.where((record) => record.propertyId == id).toList(),
      );
    }).toList();
  }

  Future<void> saveRecord({
    required String organisationId,
    required String propertyId,
    required String requirementTypeId,
    required DateTime? issueDate,
    required DateTime? expiryDate,
    required DateTime? reviewDate,
    required String? referenceNumber,
    required String? notes,
  }) async {
    await _client.from('property_compliance_records').upsert({
      'organisation_id': organisationId,
      'property_id': propertyId,
      'requirement_type_id': requirementTypeId,
      'issue_date': _dateValue(issueDate),
      'expiry_date': _dateValue(expiryDate),
      'review_date': _dateValue(reviewDate),
      'reference_number': _optional(referenceNumber),
      'notes': _optional(notes),
      'confirmed_at': DateTime.now().toUtc().toIso8601String(),
      'confirmed_by': _userId,
      'created_by': _userId,
    }, onConflict: 'property_id,requirement_type_id');
  }

  Future<void> deleteRecord(String recordId) =>
      _client.from('property_compliance_records').delete().eq('id', recordId);

  String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _dateValue(DateTime? value) => value == null
      ? null
      : '${value.year.toString().padLeft(4, '0')}-'
            '${value.month.toString().padLeft(2, '0')}-'
            '${value.day.toString().padLeft(2, '0')}';
}
