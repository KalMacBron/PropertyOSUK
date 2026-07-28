class CertificateAnalysis {
  const CertificateAnalysis({
    required this.id,
    required this.documentId,
    required this.status,
    required this.suggestions,
    required this.createdAt,
  });

  factory CertificateAnalysis.fromJson(Map<String, dynamic> json) =>
      CertificateAnalysis(
        id: json['id'] as String,
        documentId: json['document_id'] as String,
        status: json['status'] as String,
        suggestions: CertificateSuggestions.fromJson(
          (json['suggestions'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String documentId;
  final String status;
  final CertificateSuggestions suggestions;
  final DateTime createdAt;
}

class CertificateSuggestions {
  const CertificateSuggestions({
    this.certificateType,
    this.issueDate,
    this.expiryDate,
    this.referenceNumber,
    this.printedOutcome,
  });

  factory CertificateSuggestions.fromJson(Map<String, dynamic> json) =>
      CertificateSuggestions(
        certificateType: json['certificate_type'] as String?,
        issueDate: json['issue_date'] as String?,
        expiryDate: json['expiry_date'] as String?,
        referenceNumber: json['reference_number'] as String?,
        printedOutcome: json['printed_outcome'] as String?,
      );

  final String? certificateType;
  final String? issueDate;
  final String? expiryDate;
  final String? referenceNumber;
  final String? printedOutcome;
}

const analysableRequirementCodes = <String>{'gas_safety', 'eicr', 'epc'};

String newIdempotencyKey() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final padded = now.padLeft(32, '0').substring(0, 32);
  return '${padded.substring(0, 8)}-${padded.substring(8, 12)}-'
      '4${padded.substring(13, 16)}-8${padded.substring(17, 20)}-'
      '${padded.substring(20)}';
}
