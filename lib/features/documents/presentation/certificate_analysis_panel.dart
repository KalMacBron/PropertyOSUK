import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/features/compliance/application/compliance_providers.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/documents/application/certificate_analysis_providers.dart';
import 'package:property_os/features/documents/domain/certificate_analysis.dart';
import 'package:property_os/features/documents/domain/compliance_evidence.dart';

class CertificateAnalysisPanel extends ConsumerStatefulWidget {
  const CertificateAnalysisPanel({
    required this.evidence,
    required this.requirementCode,
    required this.existingRecord,
    required this.canAnalyse,
    super.key,
  });

  final ComplianceEvidence evidence;
  final String requirementCode;
  final ComplianceRecord existingRecord;
  final bool canAnalyse;

  @override
  ConsumerState<CertificateAnalysisPanel> createState() =>
      _CertificateAnalysisPanelState();
}

class _CertificateAnalysisPanelState
    extends ConsumerState<CertificateAnalysisPanel> {
  bool _working = false;

  Future<void> _analyse() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Analyse this certificate?'),
        content: Text(
          '${widget.evidence.originalFilename} will be sent securely to OpenAI '
          'to extract suggested certificate details. OpenAI API data is not used '
          'for model training by default, but standard abuse-monitoring retention '
          'may apply. PropertyOS will not update your compliance record until you '
          'review and confirm selected fields.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('I understand — analyse'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;

    setState(() => _working = true);
    try {
      final analysis = await ref
          .read(certificateAnalysisRepositoryProvider)
          .analyse(widget.evidence.id);
      ref.invalidate(certificateAnalysesProvider(widget.evidence.id));
      if (!mounted) return;
      await _review(analysis);
    } on CertificateAnalysisException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) {
        _message('The certificate could not be analysed. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _review(CertificateAnalysis analysis) async {
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _CertificateReviewDialog(
        analysis: analysis,
        existing: widget.existingRecord,
      ),
    );
    if (selected == null || !mounted) return;

    setState(() => _working = true);
    try {
      await ref
          .read(certificateAnalysisRepositoryProvider)
          .confirm(analysis.id, selected);
      ref.invalidate(certificateAnalysesProvider(widget.evidence.id));
      refreshCompliance(ref);
      if (mounted) _message('Selected certificate details confirmed.');
    } on CertificateAnalysisException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) {
        _message('The selected details could not be confirmed.');
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    if (!analysableRequirementCodes.contains(widget.requirementCode)) {
      return const SizedBox.shrink();
    }
    final analyses = ref.watch(certificateAnalysesProvider(widget.evidence.id));
    final latest = analyses.valueOrNull?.firstOrNull;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (latest != null)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Chip(
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.auto_awesome, size: 16),
              label: Text(
                latest.status == 'confirmed'
                    ? 'AI details confirmed'
                    : 'AI suggestions ready',
              ),
            ),
          ),
        if (widget.canAnalyse)
          TextButton.icon(
            onPressed: _working ? null : _analyse,
            icon: _working
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_outlined),
            label: Text(latest == null ? 'Analyse' : 'Analyse again'),
          ),
        if (latest != null &&
            latest.status == 'completed' &&
            widget.canAnalyse)
          TextButton(
            onPressed: _working ? null : () => _review(latest),
            child: const Text('Review'),
          ),
      ],
    );
  }
}

class _CertificateReviewDialog extends StatefulWidget {
  const _CertificateReviewDialog({
    required this.analysis,
    required this.existing,
  });

  final CertificateAnalysis analysis;
  final ComplianceRecord existing;

  @override
  State<_CertificateReviewDialog> createState() =>
      _CertificateReviewDialogState();
}

class _CertificateReviewDialogState extends State<_CertificateReviewDialog> {
  late final TextEditingController _issue = TextEditingController(
    text: widget.analysis.suggestions.issueDate ?? '',
  );
  late final TextEditingController _expiry = TextEditingController(
    text: widget.analysis.suggestions.expiryDate ?? '',
  );
  late final TextEditingController _reference = TextEditingController(
    text: widget.analysis.suggestions.referenceNumber ?? '',
  );
  late final TextEditingController _outcome = TextEditingController(
    text: widget.analysis.suggestions.printedOutcome ?? '',
  );
  late bool _useIssue = widget.analysis.suggestions.issueDate != null &&
      widget.existing.issueDate == null;
  late bool _useExpiry = widget.analysis.suggestions.expiryDate != null &&
      widget.existing.expiryDate == null;
  late bool _useReference =
      widget.analysis.suggestions.referenceNumber != null &&
          (widget.existing.referenceNumber?.isEmpty ?? true);
  late bool _useOutcome = widget.analysis.suggestions.printedOutcome != null &&
      (widget.existing.notes?.isEmpty ?? true);

  @override
  void dispose() {
    _issue.dispose();
    _expiry.dispose();
    _reference.dispose();
    _outcome.dispose();
    super.dispose();
  }

  bool _validDate(String value) =>
      value.isEmpty || RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value);

  void _confirm() {
    if ((_useIssue && !_validDate(_issue.text)) ||
        (_useExpiry && !_validDate(_expiry.text))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use YYYY-MM-DD for selected dates.')),
      );
      return;
    }
    final values = <String, dynamic>{};
    if (_useIssue) values['issue_date'] = _issue.text;
    if (_useExpiry) values['expiry_date'] = _expiry.text;
    if (_useReference) values['reference_number'] = _reference.text;
    if (_useOutcome) values['notes'] = _outcome.text;
    if (values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one field to confirm.')),
      );
      return;
    }
    Navigator.pop(context, values);
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = widget.analysis.suggestions;
    return AlertDialog(
      title: const Text('Review AI suggestions'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'AI-generated and unverified. Select only the fields you '
                    'have checked against the original certificate.',
                  ),
                ),
              ),
              Text(
                'Likely type: ${suggestions.certificateType ?? 'Not identified'}',
              ),
              const SizedBox(height: 12),
              _ReviewField(
                label: 'Issue date',
                selected: _useIssue,
                controller: _issue,
                existing: widget.existing.issueDate?.toIso8601String().split('T').first,
                onChanged: (value) => setState(() => _useIssue = value),
              ),
              _ReviewField(
                label: 'Expiry date',
                selected: _useExpiry,
                controller: _expiry,
                existing:
                    widget.existing.expiryDate?.toIso8601String().split('T').first,
                onChanged: (value) => setState(() => _useExpiry = value),
              ),
              _ReviewField(
                label: 'Reference number',
                selected: _useReference,
                controller: _reference,
                existing: widget.existing.referenceNumber,
                onChanged: (value) => setState(() => _useReference = value),
              ),
              _ReviewField(
                label: 'Printed outcome (saved as notes)',
                selected: _useOutcome,
                controller: _outcome,
                existing: widget.existing.notes,
                onChanged: (value) => setState(() => _useOutcome = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: _confirm,
          child: const Text('Confirm selected fields'),
        ),
      ],
    );
  }
}

class _ReviewField extends StatelessWidget {
  const _ReviewField({
    required this.label,
    required this.selected,
    required this.controller,
    required this.existing,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final TextEditingController controller;
  final String? existing;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CheckboxListTile(
        value: selected,
        onChanged: (value) => onChanged(value ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: TextField(
          controller: controller,
          enabled: selected,
          decoration: InputDecoration(
            labelText: label,
            helperText: existing == null || existing!.isEmpty
                ? 'No confirmed value'
                : 'Current value: $existing — tick to replace deliberately',
          ),
        ),
      );
}
