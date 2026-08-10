import 'package:property_os/features/tenancies/domain/tenancy_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TenancyRepository {
  const TenancyRepository(this._client);

  final SupabaseClient _client;

  Future<List<PortfolioTenancy>> listTenancies(String organisationId) async {
    final rows = await _client
        .from('tenancies')
        .select(
          '*, properties(display_name,address_line_1,postcode), '
          'tenancy_tenants(is_lead,tenants(id,display_name))',
        )
        .eq('organisation_id', organisationId)
        .order('start_date', ascending: false);
    return rows.map(PortfolioTenancy.fromJson).toList();
  }

  Future<String> save(TenancyInput input) {
    final params = {
      'target_property_id': input.propertyId,
      'tenant_display_name': input.tenantDisplayName.trim(),
      'tenancy_start_date': _date(input.startDate),
      'tenancy_fixed_term_end_date': input.fixedTermEndDate == null
          ? null
          : _date(input.fixedTermEndDate!),
      'tenancy_monthly_rent_pence': input.monthlyRentPence,
      'tenancy_rent_due_day': input.rentDueDay,
    };
    if (input.tenancyId == null) {
      return _client.rpc<String>(
        'create_tenancy',
        params: {...params, 'target_organisation_id': input.organisationId},
      );
    }
    if (input.actualEndDate != null) {
      return _client.rpc<String>(
        'correct_historical_tenancy',
        params: {
          ...params,
          'target_tenancy_id': input.tenancyId,
          'tenancy_actual_end_date': _date(input.actualEndDate!),
        },
      );
    }
    return _client.rpc<String>(
      'update_tenancy',
      params: {...params, 'target_tenancy_id': input.tenancyId},
    );
  }

  Future<String> endTenancy(String tenancyId, DateTime actualEndDate) =>
      _client.rpc<String>(
        'end_tenancy',
        params: {
          'target_tenancy_id': tenancyId,
          'tenancy_actual_end_date': _date(actualEndDate),
        },
      );

  Future<String> reopenTenancy(String tenancyId) => _client.rpc<String>(
        'reopen_tenancy',
        params: {'target_tenancy_id': tenancyId},
      );

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
