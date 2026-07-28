import 'package:property_os/features/documents/domain/certificate_analysis.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CertificateAnalysisRepository {
  const CertificateAnalysisRepository(this._client);
  final SupabaseClient _client;

  Future<List<CertificateAnalysis>> listForDocument(String documentId) async {
    final rows = await _client
        .from('certificate_analyses')
        .select('id, document_id, status, suggestions, created_at')
        .eq('document_id', documentId)
        .order('created_at', ascending: false);
    return rows.map(CertificateAnalysis.fromJson).toList();
  }

  Future<CertificateAnalysis> analyse(String documentId) async {
    final result = await _client.functions.invoke(
      'certificate-processing',
      body: {
        'action': 'analyse',
        'documentId': documentId,
        'idempotencyKey': newIdempotencyKey(),
      },
    );
    if (result.status != 200) {
      throw CertificateAnalysisException(_message(result.data));
    }
    return CertificateAnalysis.fromJson(
      (result.data['analysis'] as Map).cast<String, dynamic>(),
    );
  }

  Future<void> confirm(
    String analysisId,
    Map<String, dynamic> selectedValues,
  ) async {
    final result = await _client.functions.invoke(
      'certificate-processing',
      body: {
        'action': 'confirm',
        'analysisId': analysisId,
        'values': selectedValues,
      },
    );
    if (result.status != 200) {
      throw CertificateAnalysisException(_message(result.data));
    }
  }

  String _message(dynamic data) {
    final code = data is Map ? data['error'] : null;
    return switch (code) {
      'daily_analysis_limit_reached' =>
        'Your organisation has reached its 20 certificate analyses for the last 24 hours.',
      'unreadable_document' =>
        'The certificate could not be read reliably. Try a clearer scan or photo.',
      'analysis_not_configured' =>
        'Certificate analysis is not configured yet.',
      _ => 'The certificate could not be analysed. Please try again.',
    };
  }
}

class CertificateAnalysisException implements Exception {
  const CertificateAnalysisException(this.message);
  final String message;
}
