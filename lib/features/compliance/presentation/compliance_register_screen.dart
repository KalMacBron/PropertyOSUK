import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:property_os/features/compliance/application/compliance_providers.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';

class ComplianceRegisterScreen extends ConsumerWidget {
  const ComplianceRegisterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirements = ref.watch(complianceRequirementsProvider);
    final portfolio = ref.watch(compliancePortfolioProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Property compliance register',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Track key records and renewal dates across your portfolio. '
          'Statuses are management prompts, not legal certification.',
        ),
        const SizedBox(height: 24),
        requirements.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorCard(
            message: 'Compliance categories could not be loaded.',
            retry: () => ref.invalidate(complianceRequirementsProvider),
          ),
          data: (types) => portfolio.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorCard(
              message: 'Your compliance register could not be loaded.',
              retry: () => ref.invalidate(compliancePortfolioProvider),
            ),
            data: (properties) =>
                _RegisterContent(requirements: types, properties: properties),
          ),
        ),
      ],
    );
  }
}

class _RegisterContent extends ConsumerWidget {
  const _RegisterContent({
    required this.requirements,
    required this.properties,
  });

  final List<ComplianceRequirement> requirements;
  final List<PropertyCompliance> properties;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateTime.now();
    final counts = {for (final status in ComplianceStatus.values) status: 0};
    for (final property in properties) {
      for (final requirement in requirements) {
        final status = property.recordFor(requirement.id)?.statusOn(today) ??
            ComplianceStatus.notRecorded;
        counts[status] = counts[status]! + 1;
      }
    }

    if (properties.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Add a property before recording compliance details.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ComplianceStatus.values
              .map(
                (status) =>
                    _SummaryCard(status: status, count: counts[status]!),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        ...properties.map(
          (property) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                initiallyExpanded: properties.length == 1,
                leading: const CircleAvatar(
                  child: Icon(Icons.home_work_outlined),
                ),
                title: Text(
                  property.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${property.address}, ${property.postcode}'),
                children: requirements
                    .map(
                      (requirement) => _RequirementRow(
                        property: property,
                        requirement: requirement,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RequirementRow extends ConsumerWidget {
  const _RequirementRow({required this.property, required this.requirement});

  final PropertyCompliance property;
  final ComplianceRequirement requirement;

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final organisation = await ref.read(organisationProvider.future);
    if (!context.mounted || organisation == null) return;
    final record = property.recordFor(requirement.id);
    final draft = await showDialog<_ComplianceDraft>(
      context: context,
      builder: (_) =>
          _ComplianceDialog(requirement: requirement, existing: record),
    );
    if (draft == null) return;
    try {
      await ref.read(complianceRepositoryProvider).saveRecord(
            organisationId: organisation.id,
            propertyId: property.id,
            requirementTypeId: requirement.id,
            issueDate: draft.issueDate,
            expiryDate: draft.expiryDate,
            reviewDate: draft.reviewDate,
            referenceNumber: draft.referenceNumber,
            notes: draft.notes,
          );
      refreshCompliance(ref);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${requirement.name} saved.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The compliance record could not be saved.'),
          ),
        );
      }
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final record = property.recordFor(requirement.id);
    if (record == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove compliance record?'),
        content: Text(
          'Remove ${requirement.name} from ${property.name}? '
          'The category will return to Not recorded.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(complianceRepositoryProvider).deleteRecord(record.id);
      refreshCompliance(ref);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The compliance record could not be removed.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = property.recordFor(requirement.id);
    final status =
        record?.statusOn(DateTime.now()) ?? ComplianceStatus.notRecorded;
    final date = record?.applicableDate;
    final subtitle = date == null
        ? requirement.description
        : '${record!.expiryDate != null ? 'Expires' : 'Review'} '
            '${DateFormat('dd/MM/yyyy').format(date)}';

    return ListTile(
      leading: _StatusDot(status: status),
      title: Text(requirement.name),
      subtitle: Text(subtitle),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusChip(status: status),
          IconButton(
            tooltip: record == null ? 'Add record' : 'Edit record',
            onPressed: () => _edit(context, ref),
            icon: Icon(
              record == null ? Icons.add_circle_outline : Icons.edit_outlined,
            ),
          ),
          if (record != null)
            IconButton(
              tooltip: 'Remove record',
              onPressed: () => _delete(context, ref),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }
}

class _ComplianceDialog extends StatefulWidget {
  const _ComplianceDialog({required this.requirement, required this.existing});

  final ComplianceRequirement requirement;
  final ComplianceRecord? existing;

  @override
  State<_ComplianceDialog> createState() => _ComplianceDialogState();
}

class _ComplianceDialogState extends State<_ComplianceDialog> {
  late DateTime? _issueDate = widget.existing?.issueDate;
  late DateTime? _expiryDate = widget.existing?.expiryDate;
  late DateTime? _reviewDate = widget.existing?.reviewDate;
  late final TextEditingController _reference = TextEditingController(
    text: widget.existing?.referenceNumber ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.notes ?? '',
  );

  bool get _usesReviewDate =>
      widget.requirement.code == 'smoke_alarms' ||
      widget.requirement.code == 'co_alarms';

  Future<DateTime?> _pick(DateTime? value) => showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now().add(const Duration(days: 3650)),
      );

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.requirement.name),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.requirement.description),
                const SizedBox(height: 20),
                _DateField(
                  label: 'Issue or check date',
                  value: _issueDate,
                  onTap: () async {
                    final value = await _pick(_issueDate);
                    if (value != null) setState(() => _issueDate = value);
                  },
                ),
                const SizedBox(height: 12),
                _DateField(
                  label: _usesReviewDate ? 'Next review date' : 'Expiry date',
                  value: _usesReviewDate ? _reviewDate : _expiryDate,
                  onTap: () async {
                    final value = await _pick(
                      _usesReviewDate ? _reviewDate : _expiryDate,
                    );
                    if (value != null) {
                      setState(() {
                        if (_usesReviewDate) {
                          _reviewDate = value;
                          _expiryDate = null;
                        } else {
                          _expiryDate = value;
                          _reviewDate = null;
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reference,
                  decoration: const InputDecoration(
                    labelText: 'Reference number (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  maxLines: 3,
                  decoration:
                      const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final actionDate = _usesReviewDate ? _reviewDate : _expiryDate;
              if (actionDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _usesReviewDate
                          ? 'Choose a review date.'
                          : 'Choose an expiry date.',
                    ),
                  ),
                );
                return;
              }
              Navigator.pop(
                context,
                _ComplianceDraft(
                  issueDate: _issueDate,
                  expiryDate: _expiryDate,
                  reviewDate: _reviewDate,
                  referenceNumber: _reference.text,
                  notes: _notes.text,
                ),
              );
            },
            child: const Text('Save record'),
          ),
        ],
      );
}

class _ComplianceDraft {
  const _ComplianceDraft({
    required this.issueDate,
    required this.expiryDate,
    required this.reviewDate,
    required this.referenceNumber,
    required this.notes,
  });

  final DateTime? issueDate;
  final DateTime? expiryDate;
  final DateTime? reviewDate;
  final String referenceNumber;
  final String notes;
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.calendar_today_outlined),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value == null
                ? label
                : '$label: ${DateFormat('dd/MM/yyyy').format(value!)}',
          ),
        ),
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.status, required this.count});
  final ComplianceStatus status;
  final int count;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _StatusDot(status: status),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(_statusLabel(status)),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final ComplianceStatus status;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: _StatusDot(status: status),
        label: Text(_statusLabel(status)),
        visualDensity: VisualDensity.compact,
      );
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final ComplianceStatus status;

  @override
  Widget build(BuildContext context) => Icon(
        Icons.circle,
        size: 12,
        color: switch (status) {
          ComplianceStatus.compliant => Colors.green.shade700,
          ComplianceStatus.dueSoon => Colors.amber.shade800,
          ComplianceStatus.overdue => Colors.red.shade700,
          ComplianceStatus.notRecorded => Colors.grey.shade600,
        },
      );
}

String _statusLabel(ComplianceStatus status) => switch (status) {
      ComplianceStatus.compliant => 'Compliant',
      ComplianceStatus.dueSoon => 'Due soon',
      ComplianceStatus.overdue => 'Overdue',
      ComplianceStatus.notRecorded => 'Not recorded',
    };

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.retry});
  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(child: Text(message)),
              TextButton(onPressed: retry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}
