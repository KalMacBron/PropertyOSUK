import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:property_os/features/timeline/application/timeline_providers.dart';

class PropertyTimelineSection extends ConsumerWidget {
  const PropertyTimelineSection({required this.propertyId, super.key});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeline = ref.watch(propertyTimelineProvider(propertyId));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Property timeline',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            timeline.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Row(
                children: [
                  const Expanded(
                    child: Text('The property timeline could not be loaded.'),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(propertyTimelineProvider(propertyId)),
                    child: const Text('Try again'),
                  ),
                ],
              ),
              data: (events) => events.isEmpty
                  ? const Text('No timeline events have been recorded yet.')
                  : Column(
                      children: events
                          .map(
                            (event) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.history),
                              title: Text(event.title),
                              subtitle: Text(
                                '${DateFormat('dd/MM/yyyy HH:mm').format(event.occurredAt.toLocal())}'
                                '${event.description == null ? '' : '\n${event.description}'}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
