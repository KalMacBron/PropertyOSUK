import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/documents/data/certificate_analysis_repository.dart';
import 'package:property_os/features/documents/domain/certificate_analysis.dart';

final certificateAnalysisRepositoryProvider =
    Provider<CertificateAnalysisRepository>(
  (ref) => CertificateAnalysisRepository(ref.watch(supabaseProvider)),
);

final certificateAnalysesProvider =
    FutureProvider.family<List<CertificateAnalysis>, String>((ref, documentId) {
  return ref.watch(certificateAnalysisRepositoryProvider).listForDocument(
        documentId,
      );
});
