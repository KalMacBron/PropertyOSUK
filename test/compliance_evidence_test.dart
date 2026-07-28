import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/documents/domain/compliance_evidence.dart';

void main() {
  EvidenceFile file({
    String name = 'certificate.pdf',
    String mimeType = 'application/pdf',
    int size = 10,
  }) =>
      EvidenceFile(
        name: name,
        mimeType: mimeType,
        bytes: List<int>.filled(size, 1),
      );

  test('accepts supported evidence at the 10 MB boundary', () {
    expect(
      validateEvidenceFile(file(size: evidenceMaximumBytes)),
      isNull,
    );
  });

  test('rejects unsupported, empty and oversized evidence', () {
    expect(
      validateEvidenceFile(file(mimeType: 'text/plain')),
      'Choose a PDF, JPEG or PNG file.',
    );
    expect(validateEvidenceFile(file(size: 0)), 'The selected file is empty.');
    expect(
      validateEvidenceFile(file(size: evidenceMaximumBytes + 1)),
      'The selected file is larger than 10 MB.',
    );
  });

  test('builds an immutable organisation-scoped path', () {
    expect(
      evidencePath(
        organisationId: 'organisation-id',
        propertyId: 'property-id',
        complianceRecordId: 'record-id',
        documentId: 'document-id',
        filename: 'Gas certificate (July).pdf',
      ),
      'organisation-id/property-id/record-id/document-id/'
      'Gas_certificate_July_.pdf',
    );
  });

  test('formats evidence metadata for display', () {
    expect(evidenceTypeLabel('image/jpeg'), 'JPEG');
    expect(formatEvidenceSize(512), '512 B');
    expect(formatEvidenceSize(1536), '1.5 KB');
    expect(formatEvidenceSize(1572864), '1.5 MB');
  });
}
