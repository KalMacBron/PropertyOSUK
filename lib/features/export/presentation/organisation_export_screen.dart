import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/features/export/application/organisation_export_providers.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';

class OrganisationExportScreen extends ConsumerStatefulWidget {
  const OrganisationExportScreen({super.key});

  @override
  ConsumerState<OrganisationExportScreen> createState() =>
      _OrganisationExportScreenState();
}

class _OrganisationExportScreenState
    extends ConsumerState<OrganisationExportScreen> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final organisation = ref.watch(organisationProvider).valueOrNull;
    if (organisation == null ||
        !const ['owner', 'admin'].contains(organisation.role)) {
      return const Center(child: Text('Owner or admin access is required.'));
    }
    return WorkspacePage(
      eyebrow: 'Settings',
      title: 'Portfolio report',
      subtitle:
          'Download a clear, formatted Excel report of your PropertyOS records.',
      action: FilledButton.icon(
        onPressed: _exporting ? null : _downloadWorkbook,
        icon: _exporting
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined),
        label: Text(_exporting ? 'Preparing…' : 'Download portfolio report'),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SensitiveDataNotice(),
          SizedBox(height: 18),
          _WorkbookContents(),
        ],
      ),
    );
  }

  Future<void> _downloadWorkbook() async {
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
      final bytes = ref.read(portfolioWorkbookBuilderProvider).build(payload);
      final date = DateFormat('yyyyMMdd').format(DateTime.now());
      await FilePicker.saveFile(
        dialogTitle: 'Save PropertyOS portfolio report',
        fileName: 'propertyos-${_filename(organisation.name)}-$date.xlsx',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: bytes,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The portfolio report could not be prepared.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
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
                      'Handle the report as sensitive information',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'The workbook can contain tenant contact details, property records, costs and user membership information. Store it securely and share it only with authorised people. Document contents are never embedded.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _WorkbookContents extends StatelessWidget {
  const _WorkbookContents();

  @override
  Widget build(BuildContext context) => SectionPanel(
        title: 'What the report contains',
        subtitle:
            'A formatted Excel workbook with filters, frozen headings, UK dates and GBP values.',
        child: const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            Chip(label: Text('Summary')),
            Chip(label: Text('Properties')),
            Chip(label: Text('Ownership')),
            Chip(label: Text('Compliance')),
            Chip(label: Text('Tenancies')),
            Chip(label: Text('Maintenance')),
            Chip(label: Text('Contractors')),
            Chip(label: Text('Tasks')),
            Chip(label: Text('Expenses')),
            Chip(label: Text('Users')),
            Chip(label: Text('Document register')),
            Chip(label: Text('Audit history')),
          ],
        ),
      );
}

String _filename(String value) {
  final cleaned =
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return cleaned.replaceAll(RegExp(r'^-+|-+$'), '');
}
