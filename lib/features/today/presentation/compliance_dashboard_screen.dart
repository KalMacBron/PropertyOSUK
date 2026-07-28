import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:property_os/features/compliance/application/compliance_providers.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/today/domain/compliance_dashboard.dart';

class ComplianceDashboardScreen extends ConsumerStatefulWidget {
  const ComplianceDashboardScreen({super.key});

  @override
  ConsumerState<ComplianceDashboardScreen> createState() =>
      _ComplianceDashboardScreenState();
}

class _ComplianceDashboardScreenState
    extends ConsumerState<ComplianceDashboardScreen> {
  int _warningDays = 30;
  String? _propertyId;
  String? _requirementId;
  DashboardStatus? _status;

  @override
  Widget build(BuildContext context) {
    final requirements = ref.watch(complianceRequirementsProvider);
    final portfolio = ref.watch(compliancePortfolioProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Compliance dashboard',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'See what needs attention across your portfolio. Statuses are '
          'management prompts, not legal certification.',
        ),
        const SizedBox(height: 24),
        requirements.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _ErrorCard(
            message: 'Compliance categories could not be loaded.',
            retry: () => ref.invalidate(complianceRequirementsProvider),
          ),
          data: (types) => portfolio.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _ErrorCard(
              message: 'Your compliance dashboard could not be loaded.',
              retry: () => ref.invalidate(compliancePortfolioProvider),
            ),
            data: (properties) => _DashboardContent(
              requirements: types,
              properties: properties,
              warningDays: _warningDays,
              propertyId: _propertyId,
              requirementId: _requirementId,
              status: _status,
              onWarningDaysChanged: (value) =>
                  setState(() => _warningDays = value),
              onPropertyChanged: (value) => setState(() => _propertyId = value),
              onRequirementChanged: (value) =>
                  setState(() => _requirementId = value),
              onStatusChanged: (value) => setState(() => _status = value),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.requirements,
    required this.properties,
    required this.warningDays,
    required this.propertyId,
    required this.requirementId,
    required this.status,
    required this.onWarningDaysChanged,
    required this.onPropertyChanged,
    required this.onRequirementChanged,
    required this.onStatusChanged,
  });

  final List<ComplianceRequirement> requirements;
  final List<PropertyCompliance> properties;
  final int warningDays;
  final String? propertyId;
  final String? requirementId;
  final DashboardStatus? status;
  final ValueChanged<int> onWarningDaysChanged;
  final ValueChanged<String?> onPropertyChanged;
  final ValueChanged<String?> onRequirementChanged;
  final ValueChanged<DashboardStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Add a property to start tracking compliance actions.'),
        ),
      );
    }
    final allItems = buildDashboardItems(
      properties: properties,
      requirements: requirements,
      today: europeLondonToday(),
      warningDays: warningDays,
    );
    final filtered = allItems.where((item) {
      if (propertyId != null && item.property.id != propertyId) return false;
      if (requirementId != null && item.requirement.id != requirementId) {
        return false;
      }
      if (status != null && item.status != status) return false;
      return true;
    }).toList();
    final counts = dashboardCounts(filtered);
    final visibleItems = filtered.where((item) {
      if (status == DashboardStatus.compliant) return true;
      return item.status != DashboardStatus.compliant;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Filters(
          properties: properties,
          requirements: requirements,
          warningDays: warningDays,
          propertyId: propertyId,
          requirementId: requirementId,
          status: status,
          onWarningDaysChanged: onWarningDaysChanged,
          onPropertyChanged: onPropertyChanged,
          onRequirementChanged: onRequirementChanged,
          onStatusChanged: onStatusChanged,
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: DashboardStatus.values
              .map(
                (value) => _SummaryCard(
                  status: value,
                  count: counts.countFor(value),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_active_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What needs attention?',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(attentionSummary(counts, warningDays)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Prioritised actions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (visibleItems.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No compliance actions match these filters.'),
            ),
          )
        else
          ...visibleItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActionCard(item: item),
            ),
          ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.properties,
    required this.requirements,
    required this.warningDays,
    required this.propertyId,
    required this.requirementId,
    required this.status,
    required this.onWarningDaysChanged,
    required this.onPropertyChanged,
    required this.onRequirementChanged,
    required this.onStatusChanged,
  });

  final List<PropertyCompliance> properties;
  final List<ComplianceRequirement> requirements;
  final int warningDays;
  final String? propertyId;
  final String? requirementId;
  final DashboardStatus? status;
  final ValueChanged<int> onWarningDaysChanged;
  final ValueChanged<String?> onPropertyChanged;
  final ValueChanged<String?> onRequirementChanged;
  final ValueChanged<DashboardStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String?>(
                  initialValue: propertyId,
                  decoration: const InputDecoration(labelText: 'Property'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All properties'),
                    ),
                    ...properties.map(
                      (property) => DropdownMenuItem<String?>(
                        value: property.id,
                        child: Text(
                          property.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onPropertyChanged,
                ),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String?>(
                  initialValue: requirementId,
                  decoration:
                      const InputDecoration(labelText: 'Compliance type'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All compliance types'),
                    ),
                    ...requirements.map(
                      (requirement) => DropdownMenuItem<String?>(
                        value: requirement.id,
                        child: Text(
                          requirement.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: onRequirementChanged,
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<DashboardStatus?>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: [
                    const DropdownMenuItem<DashboardStatus?>(
                      initialValue: null,
                      child: Text('All statuses'),
                    ),
                    ...DashboardStatus.values.map(
                      (value) => DropdownMenuItem<DashboardStatus?>(
                        value: value,
                        child: Text(_statusLabel(value)),
                      ),
                    ),
                  ],
                  onChanged: onStatusChanged,
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<int>(
                  initialValue: warningDays,
                  decoration: const InputDecoration(labelText: 'Expiry window'),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('Next 30 days')),
                    DropdownMenuItem(value: 60, child: Text('Next 60 days')),
                    DropdownMenuItem(value: 90, child: Text('Next 90 days')),
                  ],
                  onChanged: (value) {
                    if (value != null) onWarningDaysChanged(value);
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.item});

  final ComplianceDashboardItem item;

  @override
  Widget build(BuildContext context) {
    final due = item.dueDate;
    final details = <String>[
      if (due != null) DateFormat('dd/MM/yyyy').format(due),
      _timingLabel(item),
      if (item.referenceNumber?.trim().isNotEmpty ?? false)
        'Ref: ${item.referenceNumber!.trim()}',
    ];
    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: CircleAvatar(
          backgroundColor: _statusColour(item.status).withValues(alpha: 0.14),
          child:
              Icon(_statusIcon(item.status), color: _statusColour(item.status)),
        ),
        title: Text(
          item.requirement.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${item.property.name} · ${item.property.postcode}\n'
          '${details.join(' · ')}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go(
          '/compliance-record/${item.property.id}/${item.requirement.id}',
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.status, required this.count});

  final DashboardStatus status;
  final int count;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 190,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(_statusIcon(status), color: _statusColour(status)),
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

String _timingLabel(ComplianceDashboardItem item) {
  final days = item.daysUntilDue;
  if (days == null) return 'Expiry or review date missing';
  if (days < 0) {
    final overdue = -days;
    return '$overdue day${overdue == 1 ? '' : 's'} overdue';
  }
  if (days == 0) return 'Due today';
  return '$days day${days == 1 ? '' : 's'} remaining';
}

String _statusLabel(DashboardStatus status) => switch (status) {
      DashboardStatus.overdue => 'Overdue',
      DashboardStatus.expiringSoon => 'Expiring soon',
      DashboardStatus.compliant => 'Compliant',
      DashboardStatus.missingInformation => 'Missing information',
    };

IconData _statusIcon(DashboardStatus status) => switch (status) {
      DashboardStatus.overdue => Icons.error_outline,
      DashboardStatus.expiringSoon => Icons.schedule,
      DashboardStatus.compliant => Icons.check_circle_outline,
      DashboardStatus.missingInformation => Icons.help_outline,
    };

Color _statusColour(DashboardStatus status) => switch (status) {
      DashboardStatus.overdue => Colors.red.shade700,
      DashboardStatus.expiringSoon => Colors.amber.shade800,
      DashboardStatus.compliant => Colors.green.shade700,
      DashboardStatus.missingInformation => Colors.grey.shade700,
    };
