import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/export/domain/organisation_export_models.dart';

void main() {
  test('export document parses safe manifest fields', () {
    final document = ExportDocument.fromJson({
      'document_id': 'document',
      'property_id': 'property',
      'property_name': 'Oak House',
      'scope': 'compliance',
      'document_type': 'compliance_evidence',
      'original_filename': 'certificate.pdf',
      'mime_type': 'application/pdf',
      'size_bytes': 1024,
      'created_at': '2026-08-11T10:00:00Z',
    });

    expect(document.id, 'document');
    expect(document.propertyName, 'Oak House');
    expect(document.sizeBytes, 1024);
    expect(document.createdAt.isUtc, isTrue);
  });

  test('prepared document parses runtime-only storage context', () {
    final prepared = PreparedExportDocument.fromJson({
      'storage_bucket': 'property-documents',
      'storage_path': 'organisation/document/file.pdf',
    });

    expect(prepared.storageBucket, 'property-documents');
    expect(prepared.storagePath, 'organisation/document/file.pdf');
  });
}
