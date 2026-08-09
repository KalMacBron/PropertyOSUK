import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/today/application/today_providers.dart';
import 'package:property_os/features/today/domain/today_action.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(todayActionsProvider);
    final properties = ref.watch(propertiesProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Today',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Prioritised management prompts from confirmed portfolio records. '
          'PropertyOS does not certify compliance or provide legal advice.',
        ),
        const SizedBox(height: 24),
        actions.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _ErrorCard(
            retry: () => ref.invalidate(todayActionsProvider),
          ),
          data: (items) => properties.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _ErrorCard(
              retry: () => ref.invalidate(propertiesProvider),
            ),
            data: (propertyRows) {
              final names = <String, String>{
                for (final row in propertyRows)
                  row['id'] as String:
                      ((row['display_name'] as String?)?.trim().isNotEmpty ??
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
              return Column(
                children: items
                    .map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _TodayActionCard(
                          action: action,
                          propertyName: action.propertyId == null
                              ? null
                              : names[action.propertyId],
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
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
    return Card(
      child: ListTile(
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
        trailing: canOpen ? const Icon(Icons.chevron_right) : null,
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
