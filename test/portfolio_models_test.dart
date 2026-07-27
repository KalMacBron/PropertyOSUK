import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

void main() {
  test('ownership entity parses database output', () {
    final entity = OwnershipEntity.fromJson({
      'id': 'owner-id',
      'legal_name': 'KaelVaren Property Ltd',
      'entity_type': 'limited_company',
      'company_number': '12345678',
    });

    expect(entity.legalName, 'KaelVaren Property Ltd');
    expect(entity.entityType, 'limited_company');
    expect(entity.companyNumber, '12345678');
  });
}
