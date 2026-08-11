class ExportDocument {
  const ExportDocument({
    required this.id,
    required this.scope,
    required this.documentType,
    required this.originalFilename,
    required this.createdAt,
    this.propertyId,
    this.propertyName,
    this.mimeType,
    this.sizeBytes,
  });

  factory ExportDocument.fromJson(Map<String, dynamic> json) => ExportDocument(
        id: json['document_id'] as String,
        propertyId: json['property_id'] as String?,
        propertyName: json['property_name'] as String?,
        scope: json['scope'] as String,
        documentType: json['document_type'] as String,
        originalFilename: json['original_filename'] as String,
        mimeType: json['mime_type'] as String?,
        sizeBytes: json['size_bytes'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String? propertyId;
  final String? propertyName;
  final String scope;
  final String documentType;
  final String originalFilename;
  final String? mimeType;
  final int? sizeBytes;
  final DateTime createdAt;
}

class PreparedExportDocument {
  const PreparedExportDocument({
    required this.storageBucket,
    required this.storagePath,
  });

  factory PreparedExportDocument.fromJson(Map<String, dynamic> json) =>
      PreparedExportDocument(
        storageBucket: json['storage_bucket'] as String,
        storagePath: json['storage_path'] as String,
      );

  final String storageBucket;
  final String storagePath;
}
