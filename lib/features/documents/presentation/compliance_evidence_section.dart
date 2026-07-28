import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/documents/application/document_providers.dart';
import 'package:property_os/features/documents/presentation/certificate_analysis_panel.dart';
import 'package:property_os/features/documents/data/document_repository.dart';
import 'package:property_os/features/documents/domain/compliance_evidence.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:url_launcher/url_launcher.dart';

class ComplianceEvidenceSection extends ConsumerWidget {
  const ComplianceEvidenceSection({
    required this.propertyId,
    required this.complianceRecordId,
    required this.requirementCode,
    required this.existingRecord,
    super.key,
  });

  final String propertyId;
  final String complianceRecordId;
  final String requirementCode;
  final ComplianceRecord existingRecord;

  Future<void> _upload(
    BuildContext context,
    WidgetRef ref,
    String organisationId,
  ) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null || !context.mounted) return;

    final selected = result.files.single;
    final bytes = selected.bytes;
    if (bytes == null) {
      _message(context, 'The selected file could not be read. Try again.');
      return;
    }

    final extension = (selected.extension ?? '').toLowerCase();
    final mimeType = switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => '',
    };
    final file = EvidenceFile(
      name: selected.name,
      mimeType: mimeType,
      bytes: bytes,
    );
    final validation = validateEvidenceFile(file);
    if (validation != null) {
      _message(context, validation);
      return;
    }

    try {
      await ref.read(documentRepositoryProvider).uploadComplianceEvidence(
            organisationId: organisationId,
            propertyId: propertyId,
            complianceRecordId: complianceRecordId,
            file: file,
          );
      ref.invalidate(
        complianceEvidenceProvider(
          EvidenceQuery(
            organisationId: organisationId,
            complianceRecordId: complianceRecordId,
          ),
        ),
      );
      if (context.mounted) _message(context, 'Evidence uploaded.');
    } on EvidenceValidationException catch (error) {
      if (context.mounted) _message(context, error.message);
    } on EvidenceUploadException catch (error) {
      if (context.mounted) _message(context, error.message);
    } catch (_) {
      if (context.mounted) {
        _message(
          context,
          'The evidence could not be uploaded. Check your connection and try again.',
        );
      }
    }
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ComplianceEvidence evidence,
  ) async {
    try {
      final url =
          await ref.read(documentRepositoryProvider).createViewUrl(evidence);
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && context.mounted) {
        _message(context, 'The evidence could not be opened.');
      }
    } catch (_) {
      if (context.mounted) {
        _message(
          context,
          'A secure link could not be created. Please try again.',
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    String organisationId,
    ComplianceEvidence evidence,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete evidence?'),
        content: Text(
          'Permanently delete ${evidence.originalFilename}? '
          'The compliance record and its dates will not change.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(documentRepositoryProvider).deleteEvidence(evidence);
      ref.invalidate(
        complianceEvidenceProvider(
          EvidenceQuery(
            organisationId: organisationId,
            complianceRecordId: complianceRecordId,
          ),
        ),
      );
      if (context.mounted) _message(context, 'Evidence deleted.');
    } on EvidenceCleanupException catch (error) {
      ref.invalidate(
        complianceEvidenceProvider(
          EvidenceQuery(
            organisationId: organisationId,
            complianceRecordId: complianceRecordId,
          ),
        ),
      );
      if (context.mounted) _message(context, error.message);
    } catch (_) {
      if (context.mounted) {
        _message(
          context,
          'The evidence could not be deleted. Please try again.',
        );
      }
    }
  }

  void _message(BuildContext context, String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organisation = ref.watch(organisationProvider);
    return organisation.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: LinearProgressIndicator(),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.fromLTRB(72, 4, 16, 16),
        child: Text('Evidence permissions could not be loaded.'),
      ),
      data: (organisation) {
        if (organisation == null) return const SizedBox.shrink();
        final query = EvidenceQuery(
          organisationId: organisation.id,
          complianceRecordId: complianceRecordId,
        );
        final evidence = ref.watch(complianceEvidenceProvider(query));

        return Padding(
          padding: const EdgeInsets.fromLTRB(72, 0, 16, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Private evidence',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (organisation.canUploadEvidence)
                        TextButton.icon(
                          onPressed: () => _upload(
                            context,
                            ref,
                            organisation.id,
                          ),
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Upload'),
                        ),
                    ],
                  ),
                  evidence.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => Row(
                      children: [
                        const Expanded(
                          child: Text('Evidence could not be loaded.'),
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(complianceEvidenceProvider(query)),
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                    data: (files) {
                      if (files.isEmpty) {
                        return const Text(
                          'No evidence attached. Upload a PDF, JPEG or PNG up to 10 MB.',
                        );
                      }
                      return Column(
                        children: files
                            .map(
                              (file) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                leading: const Icon(
                                  Icons.insert_drive_file_outlined,
                                ),
                                title: Text(file.originalFilename),
                                subtitle: Text(
                                  '${evidenceTypeLabel(file.mimeType)} · '
                                  '${formatEvidenceSize(file.sizeBytes)} · '
                                  '${DateFormat('dd/MM/yyyy').format(file.createdAt.toLocal())}',
                                ),
                                trailing: Wrap(
                                  children: [
                                    IconButton(
                                      tooltip: 'View or download evidence',
                                      onPressed: () =>
                                          _open(context, ref, file),
                                      icon: const Icon(Icons.open_in_new),
                                    ),
                                    if (organisation.canDeleteEvidence)
                                      IconButton(
                                        tooltip: 'Delete evidence',
                                        onPressed: () => _delete(
                                          context,
                                          ref,
                                          organisation.id,
                                          file,
                                        ),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    CertificateAnalysisPanel(
                                      evidence: file,
                                      requirementCode: requirementCode,
                                      existingRecord: existingRecord,
                                      canAnalyse:
                                          organisation.canUploadEvidence,
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
