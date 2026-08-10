import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/today/application/today_providers.dart';
import 'package:property_os/features/today/domain/portfolio_summary.dart';
import 'package:property_os/features/today/domain/today_action.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(todayActionsProvider);
    final properties = ref.watch(propertiesProvider);
    final summary = ref.watch(portfolioSummaryProvider);
    return ListView(padding: const EdgeInsets.all(32), children: [
      Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeading(
                      eyebrow:
                          '${DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now())} · Portfolio briefing',
                      title:
                          'Good ${DateTime.now().hour < 12 ? 'morning' : DateTime.now().hour < 18 ? 'afternoon' : 'evening'}',
                      subtitle:
                          'Prioritised management prompts from confirmed portfolio records.',
                    ),
                    const SizedBox(height: 28),
                    summary.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => _SummaryError(
                        retry: () => ref.invalidate(portfolioSummaryProvider),
                      ),
                      data: (value) => _SummaryDashboard(summary: value),
                    ),
                    const SizedBox(height: 28),
                    actions.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, __) => _ErrorCard(
                        retry: () => ref.invalidate(todayActionsProvider),
                      ),
                      data: (items) => properties.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, __) => _ErrorCard(
                          retry: () => ref.invalidate(propertiesProvider),
                        ),
                        data: (propertyRows) {
                          final names = <String, String>{
                            for (final row in propertyRows)
                              row['id'] as String:
                                  ((row['display_name'] as String?)
                                              ?.trim()
                                              .isNotEmpty ??
                                          false)
                                      ? row['display_name'] as String
                                      : row['address_line_1'] as String,
                          };
                          if (items.isEmpty) {
                            return const Card(
                              child: Padding(
                                padding: EdgeInsets.all(28),
                                child: Text(
                                  'Nothing needs your attention in the current Today window.',
                                ),
                              ),
                            );
                          }
                          return SectionPanel(
                              title: 'Management attention',
                              subtitle: 'Highest operational impact first',
                              child: Column(
                                children: items
                                    .asMap()
                                    .entries
                                    .map((entry) => Column(children: [
                                          _TodayActionCard(
                                            action: entry.value,
                                            propertyName: entry
                                                        .value.propertyId ==
                                                    null
                                                ? null
                                                : names[entry.value.propertyId],
                                          ),
                                          if (entry.key < items.length - 1)
                                            const Divider(height: 1),
                                        ]))
                                    .toList(),
                              ));
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                        'PropertyOS recommendations support portfolio management. They do not certify compliance or provide legal advice.',
                        style: TextStyle(
                            color: PropertyOsColours.muted, fontSize: 12)),
                  ])))
    ]);
  }
}

class _SummaryDashboard extends StatelessWidget {
  const _SummaryDashboard({required this.summary});

  final PortfolioSummary summary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1200
              ? 5
              : constraints.maxWidth >= 720
                  ? 3
                  : 1;
          final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _DashboardTile(
                width: width,
                label: 'Properties',
                value: '${summary.propertyCount}',
                detail: 'Active portfolio',
                colour: PropertyOsColours.navy,
                onTap: () => context.go('/properties'),
              ),
              _DashboardTile(
                width: width,
                label: 'Not recorded',
                value: '${summary.notRecorded}',
                detail: 'Compliance records missing',
                colour: PropertyOsColours.warning,
                onTap: () => context.go('/compliance'),
              ),
              _DashboardTile(
                width: width,
                label: 'Overdue',
                value: '${summary.overdue}',
                detail: 'Require immediate review',
                colour: PropertyOsColours.critical,
                onTap: () => context.go('/compliance'),
              ),
              _DashboardTile(
                width: width,
                label: 'Due soon',
                value: '${summary.dueSoon}',
                detail: 'Inside warning window',
                colour: PropertyOsColours.amberText,
                onTap: () => context.go('/compliance'),
              ),
              _DashboardTile(
                width: width,
                label: 'Recorded and current',
                value: '${summary.compliant}',
                detail: '${summary.complianceChecks} tracked checks',
                colour: PropertyOsColours.success,
                onTap: () => context.go('/compliance'),
              ),
            ],
          );
        },
      );
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.width,
    required this.label,
    required this.value,
    required this.detail,
    required this.colour,
    required this.onTap,
  });

  final double width;
  final String label;
  final String value;
  final String detail;
  final Color colour;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Material(
          color: Colors.white,
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: PropertyOsColours.border),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          label.toUpperCase(),
                          style: const TextStyle(
                            color: PropertyOsColours.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: PropertyOsColours.ink,
                          fontSize: 34,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(detail, style: TextStyle(color: colour, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.retry});
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => SectionPanel(
        title: 'Portfolio summary unavailable',
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Expanded(
                child: Text('Confirmed portfolio totals could not be loaded.'),
              ),
              TextButton(onPressed: retry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

class _TodayActionCard extends StatelessWidget {
  const _TodayActionCard({required this.action, required this.propertyName});

  final TodayAction action;
  final String? propertyName;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (propertyName != null) propertyName!,
      if (action.dueDate != null)
        DateFormat('dd/MM/yyyy').format(action.dueDate!),
      _reasonLabel(action.reason),
      if (action.evidenceDocumentId != null) 'Evidence attached',
    ];
    final canOpen = action.sourceType == 'compliance' &&
        action.propertyId != null &&
        action.requirementTypeId != null &&
        action.dueDate != null;
    return Material(
      color: Colors.white,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: _priorityColour(action.priority).withValues(
            alpha: 0.14,
          ),
          child: Icon(
            Icons.notifications_active_outlined,
            color: _priorityColour(action.priority),
          ),
        ),
        title: Text(
          action.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(details.join(' · ')),
        trailing: canOpen
            ? const Icon(Icons.chevron_right, color: PropertyOsColours.ink)
            : null,
        onTap: !canOpen
            ? null
            : () {
                final uri = Uri(
                  path:
                      '/compliance-record/${action.propertyId}/${action.requirementTypeId}',
                  queryParameters: {
                    'todaySourceId': action.sourceId,
                    'todayDueDate': _dateValue(action.dueDate!),
                  },
                );
                context.go(uri.toString());
              },
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.retry});

  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Expanded(
                child: Text('Today actions could not be loaded.'),
              ),
              TextButton(onPressed: retry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

Color _priorityColour(String priority) => switch (priority) {
      'urgent' => Colors.red.shade700,
      'high' => Colors.orange.shade800,
      'medium' => Colors.amber.shade800,
      _ => Colors.blueGrey.shade600,
    };

String _reasonLabel(String reason) => switch (reason) {
      'due_soon' => 'Due soon',
      'expired' => 'Expired',
      'overdue' => 'Overdue',
      'open' => 'Open',
      _ => reason.replaceAll('_', ' '),
    };

String _dateValue(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
