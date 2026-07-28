import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/documents/data/document_repository.dart';
import 'package:property_os/features/documents/domain/compliance_evidence.dart';

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(ref.watch(supabaseProvider)),
);

class EvidenceQuery {
  const EvidenceQuery({
    required this.organisationId,
    required this.complianceRecordId,
  });

  final String organisationId;
  final String complianceRecordId;

  @override
  bool operator ==(Object other) =>
      other is EvidenceQuery &&
      other.organisationId == organisationId &&
      other.complianceRecordId == complianceRecordId;

  @override
  int get hashCode => Object.hash(organisationId, complianceRecordId);
}

final complianceEvidenceProvider = FutureProvider.family<
    List<ComplianceEvidence>, EvidenceQuery>((ref, query) {
  return ref.watch(documentRepositoryProvider).listComplianceEvidence(
        query.organisationId,
        query.complianceRecordId,
      );
});
