import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/compliance/application/compliance_providers.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/expenses/application/expense_providers.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';
import 'package:property_os/features/property_dashboard/application/property_dashboard_summary.dart';
import 'package:property_os/features/tasks/application/task_providers.dart';
import 'package:property_os/features/tenancies/application/tenancy_providers.dart';
import 'package:property_os/features/timeline/presentation/property_timeline_section.dart';

class PropertyDashboardScreen extends ConsumerWidget {
  const PropertyDashboardScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(propertiesProvider);
    return properties.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _Unavailable(
        title: 'Property unavailable',
        message: 'The property register could not be loaded.',
        onRetry: () => ref.invalidate(propertiesProvider),
      ),
      data: (items) {
        final matching = items.where((item) => item['id'] == propertyId);
        if (matching.isEmpty) {
          return const _Unavailable(
            title: 'Property not found',
            message: 'This property is unavailable in the active organisation.',
          );
        }
        return _Dashboard(property: matching.single);
      },
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard({required this.property});

  final Map<String, dynamic> property;

  String get propertyId => property['id'] as String;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organisation = ref.watch(organisationProvider);
    final canWrite = canWriteOrganisation(organisation.valueOrNull);
    final name = _propertyName(property);
    return WorkspacePage(
      eyebrow: 'Property operations',
      title: name,
      subtitle: _address(property),
      action: OutlinedButton.icon(
        onPressed: () => context.go('/properties'),
        icon: const Icon(Icons.arrow_back),
        label: const Text('All properties'),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _IdentityPanel(property: property),
            if (canWrite) ...[
              const SizedBox(height: 18),
              _QuickActions(propertyId: propertyId),
            ],
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth >= 1000
                    ? (constraints.maxWidth - 18) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: [
                    SizedBox(
                      width: width,
                      child: _CompliancePanel(propertyId: propertyId),
                    ),
                    SizedBox(
                      width: width,
                      child: _TenancyPanel(propertyId: propertyId),
                    ),
                    SizedBox(
                      width: width,
                      child: _TasksPanel(propertyId: propertyId),
                    ),
                    SizedBox(
                      width: width,
                      child: _ExpensesPanel(propertyId: propertyId),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            PropertyTimelineSection(propertyId: propertyId),
          ],
        ),
      ),
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel({required this.property});
  final Map<String, dynamic> property;

  @override
  Widget build(BuildContext context) {
    final ownerships = property['property_ownerships'] as List<dynamic>? ?? [];
    final owners = ownerships.map((row) {
      final map = row as Map<String, dynamic>;
      final entity = map['ownership_entities'] as Map<String, dynamic>?;
      final percentage = map['ownership_percentage'];
      return '${entity?['legal_name'] ?? 'Owner'}${percentage == null ? '' : ' · $percentage%'}';
    }).join(', ');
    return SectionPanel(
      title: 'Property overview',
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Wrap(
          spacing: 36,
          runSpacing: 14,
          children: [
            _Fact(
                label: 'Ownership',
                value: owners.isEmpty ? 'Not recorded' : owners),
            _Fact(
                label: 'Type',
                value: property['property_type'] as String? ?? 'Not recorded'),
            _Fact(
                label: 'Bedrooms',
                value: property['bedrooms']?.toString() ?? 'Not recorded'),
            _Fact(
                label: 'Status',
                value: property['status'] as String? ?? 'Active'),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.icon(
            onPressed: () =>
                context.go('/expenses?propertyId=$propertyId&create=true'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Add expense'),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                context.go('/tasks?propertyId=$propertyId&create=true'),
            icon: const Icon(Icons.add_task_outlined),
            label: const Text('Create task'),
          ),
          OutlinedButton.icon(
            onPressed: () =>
                context.go('/tenancies?propertyId=$propertyId&create=true'),
            icon: const Icon(Icons.key_outlined),
            label: const Text('Add tenancy'),
          ),
          OutlinedButton.icon(
            onPressed: () => context.go('/compliance?propertyId=$propertyId'),
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Open compliance'),
          ),
        ],
      );
}

class _CompliancePanel extends ConsumerWidget {
  const _CompliancePanel({required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final portfolio = ref.watch(compliancePortfolioProvider);
    final requirements = ref.watch(complianceRequirementsProvider);
    if (portfolio.isLoading || requirements.isLoading) {
      return const _LoadingPanel(title: 'Compliance');
    }
    if (portfolio.hasError || requirements.hasError) {
      return _ErrorPanel(
          title: 'Compliance',
          onRetry: () {
            ref.invalidate(compliancePortfolioProvider);
            ref.invalidate(complianceRequirementsProvider);
          });
    }
    final properties = portfolio.value ?? const <PropertyCompliance>[];
    final match = properties.where((property) => property.id == propertyId);
    if (match.isEmpty) {
      return const _MessagePanel(
          title: 'Compliance', message: 'No compliance register is available.');
    }
    final counts = propertyComplianceCounts(
      property: match.single,
      requirements: requirements.value ?? const [],
      today: DateTime.now(),
    );
    return SectionPanel(
      title: 'Compliance',
      subtitle: 'Management prompts, not legal certification',
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: ComplianceStatus.values
              .map((status) => _MetricButton(
                    label: _complianceLabel(status),
                    value: counts[status]!,
                    onTap: () => context.go(
                        '/compliance?propertyId=$propertyId&status=${status.name}'),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _TenancyPanel extends ConsumerWidget {
  const _TenancyPanel({required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(tenanciesProvider).when(
            loading: () => const _LoadingPanel(title: 'Tenancy'),
            error: (_, __) => _ErrorPanel(
                title: 'Tenancy',
                onRetry: () => ref.invalidate(tenanciesProvider)),
            data: (items) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final tenancy =
                  highlightedPropertyTenancy(items, propertyId, today);
              if (tenancy == null) {
                return const _MessagePanel(
                    title: 'Tenancy', message: 'No tenancy has been recorded.');
              }
              final lifecycle = tenancy.isCurrent(today)
                  ? 'Current'
                  : tenancy.isUpcoming(today)
                      ? 'Upcoming'
                      : 'Historical';
              return SectionPanel(
                title: 'Tenancy',
                subtitle: lifecycle,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  title: Text(tenancy.tenantDisplayName),
                  subtitle: Text(
                      '${_date(tenancy.startDate)}${tenancy.actualEndDate == null ? '' : ' – ${_date(tenancy.actualEndDate!)}'}${tenancy.monthlyRentPence == null ? '' : '\n${_money(tenancy.monthlyRentPence!)} monthly'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go('/tenancies?tenancyId=${tenancy.id}'),
                ),
              );
            },
          );
}

class _TasksPanel extends ConsumerWidget {
  const _TasksPanel({required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(tasksProvider).when(
            loading: () => const _LoadingPanel(title: 'Tasks'),
            error: (_, __) => _ErrorPanel(
                title: 'Tasks', onRetry: () => ref.invalidate(tasksProvider)),
            data: (items) {
              final summary = propertyTaskSummary(items, propertyId);
              return SectionPanel(
                title: 'Tasks',
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        _MetricButton(
                            label: 'Open',
                            value: summary.open,
                            onTap: () =>
                                context.go('/tasks?propertyId=$propertyId')),
                        _MetricButton(
                            label: 'Overdue',
                            value: summary.overdue,
                            onTap: () => context.go(
                                '/tasks?propertyId=$propertyId&filter=overdue')),
                        _MetricButton(
                            label: 'Completed',
                            value: summary.recentlyCompleted,
                            onTap: () => context.go(
                                '/tasks?propertyId=$propertyId&filter=completed')),
                      ]),
                      for (final task in summary.attention)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(task.title),
                          subtitle: Text(
                              '${task.priority.label}${task.dueDate == null ? '' : ' · Due ${_date(task.dueDate!)}'}'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
}

class _ExpensesPanel extends ConsumerWidget {
  const _ExpensesPanel({required this.propertyId});
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(expensesProvider).when(
            loading: () => const _LoadingPanel(title: 'Expenses'),
            error: (_, __) => _ErrorPanel(
                title: 'Expenses',
                onRetry: () => ref.invalidate(expensesProvider)),
            data: (items) {
              final total = propertyCurrentYearExpenseTotal(
                  items, propertyId, DateTime.now().year);
              final recent = recentPropertyExpenses(items, propertyId);
              return SectionPanel(
                title: 'Expenses',
                subtitle: '${DateTime.now().year} total ${_money(total)}',
                child: Column(
                  children: [
                    for (final expense in recent)
                      ListTile(
                        title: Text(expense.description),
                        subtitle: Text(
                            '${_date(expense.expenseDate)} · ${expense.category}'),
                        trailing: Text(_money(expense.amountPence)),
                      ),
                    ListTile(
                      title: const Text('Open property expenses'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.go('/expenses?propertyId=$propertyId'),
                    ),
                  ],
                ),
              );
            },
          );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: PropertyOsColours.muted)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

class _MetricButton extends StatelessWidget {
  const _MetricButton(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final int value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 120,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              border: Border.all(color: PropertyOsColours.border)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('$value', style: Theme.of(context).textTheme.headlineMedium),
          ]),
        ),
      );
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => SectionPanel(
      title: title,
      child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator())));
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.title, required this.onRetry});
  final String title;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => SectionPanel(
      title: title,
      child: ListTile(
          title: const Text('This summary could not be loaded.'),
          trailing:
              TextButton(onPressed: onRetry, child: const Text('Try again'))));
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => SectionPanel(
      title: title,
      child: Padding(padding: const EdgeInsets.all(22), child: Text(message)));
}

class _Unavailable extends StatelessWidget {
  const _Unavailable(
      {required this.title, required this.message, this.onRetry});
  final String title;
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => WorkspacePage(
        eyebrow: 'Property operations',
        title: title,
        subtitle: message,
        action: OutlinedButton(
            onPressed: () => context.go('/properties'),
            child: const Text('Back to properties')),
        child: ifRetry(onRetry),
      );
}

Widget ifRetry(VoidCallback? retry) => retry == null
    ? const SizedBox.shrink()
    : Align(
        alignment: Alignment.centerLeft,
        child: TextButton(onPressed: retry, child: const Text('Try again')));

String _propertyName(Map<String, dynamic> property) {
  final display = (property['display_name'] as String?)?.trim();
  return display?.isNotEmpty == true
      ? display!
      : property['address_line_1'] as String;
}

String _address(Map<String, dynamic> property) =>
    '${property['address_line_1']}, ${property['town_or_city']}, ${property['postcode']}';
String _date(DateTime value) => DateFormat('dd/MM/yyyy').format(value);
String _money(int pence) =>
    NumberFormat.currency(locale: 'en_GB', symbol: '£').format(pence / 100);
String _complianceLabel(ComplianceStatus status) => switch (status) {
      ComplianceStatus.compliant => 'Compliant',
      ComplianceStatus.dueSoon => 'Due soon',
      ComplianceStatus.overdue => 'Expired',
      ComplianceStatus.notRecorded => 'Not recorded',
    };
