class ComplianceEvidence {
  const ComplianceEvidence({
    required this.id,
    required this.originalFilename,
    required this.storageBucket,
    required this.storagePath,
    required this.mimeType,
    required this.sizeBytes,
    required this.createdAt,
  });

  factory ComplianceEvidence.fromJson(Map<String, dynamic> json) =>
      ComplianceEvidence(
        id: json['id'] as String,
        originalFilename: json['original_filename'] as String,
        storageBucket: json['storage_bucket'] as String,
        storagePath: json['storage_path'] as String,
        mimeType: json['mime_type'] as String,
        sizeBytes: json['size_bytes'] as int,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String originalFilename;
  final String storageBucket;
  final String storagePath;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;
}

class EvidenceFile {
  const EvidenceFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final List<int> bytes;

  int get sizeBytes => bytes.length;
}

const evidenceMaximumBytes = 10 * 1024 * 1024;
const evidenceMimeTypes = <String>{
  'application/pdf',
  'image/jpeg',
  'image/png',
};

String? validateEvidenceFile(EvidenceFile file) {
  if (!evidenceMimeTypes.contains(file.mimeType)) {
    return 'Choose a PDF, JPEG or PNG file.';
  }
  if (file.sizeBytes == 0) return 'The selected file is empty.';
  if (file.sizeBytes > evidenceMaximumBytes) {
    return 'The selected file is larger than 10 MB.';
  }
  return null;
}

String sanitiseEvidenceFilename(String filename) {
  final cleaned = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_');
  return cleaned.isEmpty ? 'evidence' : cleaned;
}

String evidencePath({
  required String organisationId,
  required String propertyId,
  required String complianceRecordId,
  required String documentId,
  required String filename,
}) =>
    '$organisationId/$propertyId/$complianceRecordId/$documentId/'
    '${sanitiseEvidenceFilename(filename)}';

String evidenceTypeLabel(String mimeType) => switch (mimeType) {
      'application/pdf' => 'PDF',
      'image/jpeg' => 'JPEG',
      'image/png' => 'PNG',
      _ => 'File',
    };

String formatEvidenceSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
