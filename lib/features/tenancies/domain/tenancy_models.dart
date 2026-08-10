class PortfolioTenancy {
  const PortfolioTenancy({
    required this.id,
    required this.organisationId,
    required this.propertyId,
    required this.propertyName,
    required this.tenantDisplayName,
    required this.startDate,
    required this.status,
    this.fixedTermEndDate,
    this.actualEndDate,
    this.monthlyRentPence,
    this.rentDueDay,
  });

  factory PortfolioTenancy.fromJson(Map<String, dynamic> json) {
    final property = json['properties'] as Map<String, dynamic>?;
    final links = json['tenancy_tenants'] as List<dynamic>? ?? const [];
    final lead = links.cast<Map<String, dynamic>>().firstWhere(
          (link) => link['is_lead'] == true,
          orElse: () => links.isEmpty
              ? <String, dynamic>{}
              : links.first as Map<String, dynamic>,
        );
    final tenant = lead['tenants'] as Map<String, dynamic>?;
    return PortfolioTenancy(
      id: json['id'] as String,
      organisationId: json['organisation_id'] as String,
      propertyId: json['property_id'] as String,
      propertyName: _propertyName(property),
      tenantDisplayName: tenant?['display_name'] as String? ?? 'Tenant',
      startDate: DateTime.parse(json['start_date'] as String),
      fixedTermEndDate: _date(json['fixed_term_end_date']),
      actualEndDate: _date(json['actual_end_date']),
      monthlyRentPence: json['monthly_rent_pence'] as int?,
      rentDueDay: json['rent_due_day'] as int?,
      status: json['status'] as String,
    );
  }

  final String id;
  final String organisationId;
  final String propertyId;
  final String propertyName;
  final String tenantDisplayName;
  final DateTime startDate;
  final DateTime? fixedTermEndDate;
  final DateTime? actualEndDate;
  final int? monthlyRentPence;
  final int? rentDueDay;
  final String status;

  bool get isEnded => actualEndDate != null || status == 'archived';
  bool isUpcoming(DateTime today) => !isEnded && startDate.isAfter(today);
  bool isCurrent(DateTime today) => !isEnded && !startDate.isAfter(today);

  static DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.parse(value as String);

  static String _propertyName(Map<String, dynamic>? property) {
    if (property == null) return 'Property';
    final displayName = (property['display_name'] as String?)?.trim();
    if (displayName?.isNotEmpty == true) return displayName!;
    final address = property['address_line_1'] as String? ?? 'Property';
    final postcode = property['postcode'] as String?;
    return postcode == null || postcode.isEmpty
        ? address
        : '$address, $postcode';
  }
}

class TenancyInput {
  const TenancyInput({
    required this.organisationId,
    required this.propertyId,
    required this.tenantDisplayName,
    required this.startDate,
    this.tenancyId,
    this.fixedTermEndDate,
    this.actualEndDate,
    this.monthlyRentPence,
    this.rentDueDay,
  });

  final String organisationId;
  final String propertyId;
  final String tenantDisplayName;
  final DateTime startDate;
  final String? tenancyId;
  final DateTime? fixedTermEndDate;
  final DateTime? actualEndDate;
  final int? monthlyRentPence;
  final int? rentDueDay;
}
