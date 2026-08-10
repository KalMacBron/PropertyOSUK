import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/tenancies/domain/tenancy_models.dart';

void main() {
  test('parses a privacy-minimised tenancy and classifies its lifecycle', () {
    final tenancy = PortfolioTenancy.fromJson({
      'id': 'tenancy',
      'organisation_id': 'organisation',
      'property_id': 'property',
      'start_date': '2026-08-01',
      'fixed_term_end_date': '2027-07-31',
      'actual_end_date': null,
      'monthly_rent_pence': 125000,
      'rent_due_day': 5,
      'status': 'active',
      'properties': {
        'display_name': 'Oak House',
        'address_line_1': '1 Test Street',
        'postcode': 'SW1A 1AA',
      },
      'tenancy_tenants': [
        {
          'is_lead': true,
          'tenants': {'id': 'tenant', 'display_name': 'A. Tenant'},
        },
      ],
    });

    expect(tenancy.propertyName, 'Oak House');
    expect(tenancy.tenantDisplayName, 'A. Tenant');
    expect(tenancy.monthlyRentPence, 125000);
    expect(tenancy.rentDueDay, 5);
    expect(tenancy.isCurrent(DateTime(2026, 8, 10)), isTrue);
    expect(tenancy.isUpcoming(DateTime(2026, 7, 31)), isTrue);
    expect(tenancy.isEnded, isFalse);
  });

  test('actual end date makes a tenancy historical', () {
    final tenancy = PortfolioTenancy.fromJson({
      'id': 'tenancy',
      'organisation_id': 'organisation',
      'property_id': 'property',
      'start_date': '2025-01-01',
      'fixed_term_end_date': null,
      'actual_end_date': '2026-07-31',
      'monthly_rent_pence': null,
      'rent_due_day': null,
      'status': 'archived',
      'properties': {
        'display_name': null,
        'address_line_1': '1 Test Street',
        'postcode': 'SW1A 1AA',
      },
      'tenancy_tenants': [
        {
          'is_lead': true,
          'tenants': {'id': 'tenant', 'display_name': 'B. Tenant'},
        },
      ],
    });

    expect(tenancy.propertyName, '1 Test Street, SW1A 1AA');
    expect(tenancy.isEnded, isTrue);
    expect(tenancy.isCurrent(DateTime(2026, 8, 10)), isFalse);
  });
}
