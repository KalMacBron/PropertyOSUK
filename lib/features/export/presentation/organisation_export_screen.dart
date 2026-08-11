import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/features/export/application/organisation_export_providers.dart';
import 'package:property_os/features/export/domain/organisation_export_models.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:url_launcher/url_launcher.dart';

class OrganisationExportScreen extends ConsumerStatefulWidget {
  const OrganisationExportScreen({super.key});

  @override
  ConsumerState<OrganisationExportScreen> createState() =>
      _OrganisationExportScreenState();
}

class _OrganisationExportScreenState
    extends ConsumerState<OrganisationExportScreen> {
  final _search = TextEditingController();
  bool _exporting = false;
  String? _downloadingDocumentId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final organisation = ref.watch(organisationProvider).valueOrNull;
    if (organisation == null ||
        !const ['owner', 'admin'].contains(organisation.role)) {
      return const Center(child: Text('Owner or admin access is required.'));
    }
    final documents = ref.watch(organisationExportDocumentsProvider);
    return WorkspacePage(
      eyebrow: 'Settings',
      title: 'Organisation export',
      subtitle: 'Take a portable copy of confirmed PropertyOS Alpha records.',
      action: FilledButton.icon(
        onPressed: _exporting ? null : _downloadJson,
        icon: _exporting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined),
        label: Text(_exporting ? 'Preparing…' : 'Download organisation JSON'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SensitiveDataNotice(),
          const SizedBox(height: 18),
          SectionPanel(
            title: 'Private documents',
            subtitle:
                'Documents remain separate and use a fresh 60-second authorised link.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 420,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Search filename, property or type',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                documents.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, __) => const SuiteEmptyState(
                    icon: Icons.error_outline,
                    title: 'Document manifest unavailable',
                    message: 'Refresh the page to try again.',
                  ),
                  data: (items) => _DocumentList(
                    documents: _filter(items),
                    downloadingDocumentId: _downloadingDocumentId,
                    onDownload: _downloadDocument,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<ExportDocument> _filter(List<ExportDocument> documents) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return documents;
    return documents.where((document) {
      return document.originalFilename.toLowerCase().contains(query) ||
          document.documentType.toLowerCase().contains(query) ||
          document.scope.toLowerCase().contains(query) ||
          (document.propertyName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Future<void> _downloadJson() async {
    final organisation = await ref.read(organisationProvider.future);
    if (organisation == null ||
        !const ['owner', 'admin'].contains(organisation.role)) {
      return;
    }
    setState(() => _exporting = true);
    try {
      final payload = await ref
          .read(organisationExportRepositoryProvider)
          .exportData(organisation.id);
      final encoded = const JsonEncoder.withIndent('  ').convert(payload);
      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      await FilePicker.saveFile(
        dialogTitle: 'Save PropertyOS organisation export',
        fileName: 'propertyos-${_filename(organisation.name)}-$date.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(encoded)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The organisation export could not be prepared.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _downloadDocument(ExportDocument document) async {
    final organisation = await ref.read(organisationProvider.future);
    if (organisation == null ||
        !const ['owner', 'admin'].contains(organisation.role)) {
      return;
    }
    setState(() => _downloadingDocumentId = document.id);
    try {
      final url = await ref
          .read(organisationExportRepositoryProvider)
          .authorisedDocumentUrl(
            organisationId: organisation.id,
            documentId: document.id,
          );
      final opened = await launchUrl(
        Uri.parse(url),
        webOnlyWindowName: '_blank',
      );
      if (!opened) throw StateError('document_link_not_opened');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The document could not be opened.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingDocumentId = null);
    }
  }
}

class _SensitiveDataNotice extends StatelessWidget {
  const _SensitiveDataNotice();

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, size: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Handle exports as sensitive information',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'The JSON can contain tenant contact details, property records, costs and user membership information. Store it securely and share it only with authorised people. Document contents are never embedded in the JSON.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({
    required this.documents,
    required this.downloadingDocumentId,
    required this.onDownload,
  });

  final List<ExportDocument> documents;
  final String? downloadingDocumentId;
  final ValueChanged<ExportDocument> onDownload;

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) {
      return const SuiteEmptyState(
        icon: Icons.description_outlined,
        title: 'No documents in this view',
        message: 'Change the search or add evidence to a PropertyOS record.',
      );
    }
    return Column(
      children: [
        for (final document in documents)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 8,
            ),
            leading: const Icon(Icons.description_outlined),
            title: Text(document.originalFilename),
            subtitle: Text([
              document.propertyName ?? 'Organisation',
              document.documentType.replaceAll('_', ' '),
              DateFormat('dd/MM/yyyy').format(document.createdAt.toLocal()),
              if (document.sizeBytes != null) _size(document.sizeBytes!),
            ].join(' · ')),
            trailing: IconButton(
              tooltip: 'Download authorised document',
              onPressed: downloadingDocumentId == null
                  ? () => onDownload(document)
                  : null,
              icon: downloadingDocumentId == document.id
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_outlined),
            ),
          ),
      ],
    );
  }
}

String _filename(String value) {
  final cleaned =
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
}

String _size(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
