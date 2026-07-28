import 'package:supabase_flutter/supabase_flutter.dart';

class OrganisationSummary {
  const OrganisationSummary({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final String role;

  bool get canUploadEvidence =>
      role == 'owner' || role == 'admin' || role == 'member';

  bool get canDeleteEvidence => role == 'owner' || role == 'admin';
}

class OwnershipEntity {
  const OwnershipEntity({
    required this.id,
    required this.legalName,
    required this.entityType,
    this.companyNumber,
  });

  factory OwnershipEntity.fromJson(Map<String, dynamic> json) {
    return OwnershipEntity(
      id: json['id'] as String,
      legalName: json['legal_name'] as String,
      entityType: json['entity_type'] as String,
      companyNumber: json['company_number'] as String?,
    );
  }

  final String id;
  final String legalName;
  final String entityType;
  final String? companyNumber;
}

class PortfolioRepository {
  const PortfolioRepository(this._client);
  final SupabaseClient _client;

  String get _userId => _client.auth.currentUser!.id;

  Future<OrganisationSummary?> currentOrganisation() async {
    final rows = await _client
        .from('organisation_members')
        .select('organisation_id, role, organisations(name)')
        .eq('user_id', _userId)
        .limit(1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final organisation = row['organisations'] as Map<String, dynamic>;
    return OrganisationSummary(
      id: row['organisation_id'] as String,
      name: organisation['name'] as String,
      role: row['role'] as String,
    );
  }

  Future<OrganisationSummary> createOrganisation(String name) async {
    final slug =
        '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-${DateTime.now().millisecondsSinceEpoch}';
    final id = await _client.rpc<String>(
      'create_organisation',
      params: {'organisation_name': name.trim(), 'organisation_slug': slug},
    );
    return OrganisationSummary(id: id, name: name.trim(), role: 'owner');
  }

  Future<List<OwnershipEntity>> listOwnershipEntities(
    String organisationId,
  ) async {
    final rows = await _client
        .from('ownership_entities')
        .select()
        .eq('organisation_id', organisationId)
        .eq('status', 'active')
        .order('legal_name');
    return rows.map(OwnershipEntity.fromJson).toList();
  }

  Future<void> createOwnershipEntity({
    required String organisationId,
    required String entityType,
    required String legalName,
    String? companyNumber,
  }) async {
    await _client.from('ownership_entities').insert({
      'organisation_id': organisationId,
      'entity_type': entityType,
      'legal_name': legalName.trim(),
      'company_number': companyNumber?.trim().isEmpty == true
          ? null
          : companyNumber?.trim().toUpperCase(),
      'created_by': _userId,
    });
  }

  Future<List<Map<String, dynamic>>> listProperties(String organisationId) {
    return _client
        .from('properties')
        .select(
          'id, display_name, address_line_1, town_or_city, postcode, property_ownerships(ownership_percentage, ownership_entities(legal_name))',
        )
        .eq('organisation_id', organisationId)
        .eq('status', 'active')
        .order('address_line_1');
  }

  Future<void> createProperty({
    required String organisationId,
    required String ownershipEntityId,
    required double ownershipPercentage,
    required String addressLine1,
    required String townOrCity,
    required String postcode,
    String? displayName,
    String? propertyType,
    int? bedrooms,
  }) async {
    await _client.rpc<void>(
      'create_property_with_ownership',
      params: {
        'target_organisation_id': organisationId,
        'target_ownership_entity_id': ownershipEntityId,
        'target_ownership_percentage': ownershipPercentage,
        'property_address_line_1': addressLine1.trim(),
        'property_town_or_city': townOrCity.trim(),
        'property_postcode': postcode.trim().toUpperCase(),
        'property_display_name':
            displayName?.trim().isEmpty == true ? null : displayName?.trim(),
        'property_type_name': propertyType,
        'property_bedrooms': bedrooms,
      },
    );
  }
}
