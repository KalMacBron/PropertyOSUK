import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/documents/domain/certificate_analysis.dart';

void main() {
  test('parses structured certificate suggestions', () {
    final analysis = CertificateAnalysis.fromJson({
      'id': 'analysis-id',
      'document_id': 'document-id',
      'status': 'completed',
      'suggestions': {
        'certificate_type': 'gas_safety',
        'issue_date': '2026-07-01',
        'expiry_date': '2027-06-30',
        'reference_number': 'GAS-123',
        'printed_outcome': 'Satisfactory',
      },
      'created_at': '2026-07-28T12:00:00Z',
    });

    expect(analysis.suggestions.certificateType, 'gas_safety');
    expect(analysis.suggestions.expiryDate, '2027-06-30');
    expect(analysis.suggestions.referenceNumber, 'GAS-123');
  });

  test('limits analysis to supported certificate categories', () {
    expect(
        analysableRequirementCodes, containsAll(['gas_safety', 'eicr', 'epc']));
    expect(analysableRequirementCodes, isNot(contains('smoke_alarms')));
    expect(analysableRequirementCodes, isNot(contains('co_alarms')));
  });
}
