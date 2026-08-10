import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:property_os/features/compliance/application/compliance_providers.dart';
import 'package:property_os/features/documents/presentation/compliance_evidence_section.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/timeline/application/timeline_providers.dart';
import 'package:property_os/features/timeline/presentation/property_timeline_section.dart';
import 'package:property_os/features/today/application/today_providers.dart';
import 'package:property_os/features/today/domain/compliance_dashboard.dart';
import 'package:property_os/features/today/domain/today_action.dart';

class ComplianceRecordScreen extends ConsumerWidget {
  const ComplianceRecordScreen({
    required this.propertyId,
    required this.requirementId,
    this.todaySourceId,
    this.todayDueDate,
    super.key,
  });

  final String propertyId;
  final String requirementId;
  final String? todaySourceId;
  final DateTime? todayDueDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirements = ref.watch(complianceRequirementsProvider);
    final portfolio = ref.watch(compliancePortfolioProvider);
    final organisation = ref.watch(organisationProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/today'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Today'),
          ),
        ),
        const SizedBox(height: 8),
        requirements.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _MessageCard(
            message: 'The compliance category could not be loaded.',
          ),
          data: (types) => portfolio.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const _MessageCard(
              message: 'The compliance record could not be loaded.',
            ),
            data: (properties) {
              final property = properties
                  .where((value) => value.id == propertyId)
                  .firstOrNull;
              final requirement =
                  types.where((value) => value.id == requirementId).firstOrNull;
              if (property == null || requirement == null) {
                return const _MessageCard(
                  message: 'This compliance record is no longer available.',
                );
              }
              final record = property.recordFor(requirement.id);
              final item = buildDashboardItems(
                properties: [property],
                requirements: [requirement],
                today: europeLondonToday(),
                warningDays: requirement.defaultWarningDays,
              ).single;
              final canRecordExpense =
                  organisation.valueOrNull?.canWriteOperations ?? false;
              final expenseRoute = record == null
                  ? '/expenses?propertyId=${property.id}&create=true'
                  : '/expenses?propertyId=${property.id}'
                      '&complianceRecordId=${record.id}&create=true';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    requirement.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${property.name} · ${property.address}, '
                    '${property.postcode}',
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Wrap(
                        spacing: 32,
                        runSpacing: 20,
                        children: [
                          _Detail(
                            label: 'Status',
                            value: _statusLabel(item.status),
                          ),
                          _Detail(
                            label: 'Checked',
                            value: _date(record?.issueDate),
                          ),
                          _Detail(
                            label: record?.expiryDate != null
                                ? 'Expires'
                                : 'Review',
                            value: _date(record?.applicableDate),
                          ),
                          _Detail(
                            label: 'Certificate reference',
                            value: record?.referenceNumber?.trim().isNotEmpty ==
                                    true
                                ? record!.referenceNumber!.trim()
                                : 'Not recorded',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        record == null
                            ? 'No confirmed record exists for this requirement yet. You can still record a related property expense and link it later once the compliance record exists.'
                            : (record.notes?.trim().isNotEmpty == true
                                ? record.notes!.trim()
                                : 'No notes recorded.'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (record != null)
                    ComplianceEvidenceSection(
                      propertyId: property.id,
                      complianceRecordId: record.id,
                      requirementCode: requirement.code,
                      existingRecord: record,
                    ),
                  if (record != null) const SizedBox(height: 16),
                  if (record != null &&
                      canRecordExpense &&
                      todaySourceId == record.id &&
                      todayDueDate != null)
                    _TodayCompletionCard(
                      propertyId: property.id,
                      action: TodayAction(
                        sourceType: 'compliance',
                        sourceId: record.id,
                        title: 'Review ${requirement.name}',
                        reason: 'due_soon',
                        priority: 'medium',
                        propertyId: property.id,
                        requirementTypeId: requirement.id,
                        dueDate: todayDueDate,
                      ),
                    ),
                  if (record != null &&
                      canRecordExpense &&
                      todaySourceId == record.id &&
                      todayDueDate != null)
                    const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => context.go('/compliance'),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Manage in compliance register'),
                      ),
                      if (canRecordExpense)
                        OutlinedButton.icon(
                          onPressed: () => context.go(expenseRoute),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: Text(
                            record == null
                                ? 'Record property expense'
                                : 'Record compliance expense',
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  PropertyTimelineSection(propertyId: property.id),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TodayCompletionCard extends ConsumerStatefulWidget {
  const _TodayCompletionCard({
    required this.propertyId,
    required this.action,
  });

  final String propertyId;
  final TodayAction action;

  @override
  ConsumerState<_TodayCompletionCard> createState() =>
      _TodayCompletionCardState();
}

class _TodayCompletionCardState extends ConsumerState<_TodayCompletionCard> {
  bool _saving = false;

  Future<void> _complete() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(todayRepositoryProvider)
          .completeComplianceAction(widget.action);
      ref.invalidate(todayActionsProvider);
      ref.invalidate(propertyTimelineProvider(widget.propertyId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Today action marked complete.')),
        );
        context.go('/today');
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The Today action could not be completed. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'This recommended action is linked to this record and its '
                  'evidence. Completing it records a management event; it does '
                  'not certify compliance.',
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _complete,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Mark complete'),
              ),
            ],
          ),
        ),
      );
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message),
        ),
      );
}

String _date(DateTime? value) =>
    value == null ? 'Not recorded' : DateFormat('dd/MM/yyyy').format(value);

String _statusLabel(DashboardStatus status) => switch (status) {
      DashboardStatus.overdue => 'Overdue',
      DashboardStatus.expiringSoon => 'Expiring soon',
      DashboardStatus.compliant => 'Compliant',
      DashboardStatus.missingInformation => 'Missing information',
    };
