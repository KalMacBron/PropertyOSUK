import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

const ownershipTypeLabels = {
  'individual': 'Individual',
  'joint': 'Joint ownership',
  'limited_company': 'Limited company',
  'trust': 'Trust',
  'partnership': 'Partnership',
  'other': 'Other',
};

class OwnershipEntitiesScreen extends ConsumerWidget {
  const OwnershipEntitiesScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final organisation = await ref.read(organisationProvider.future);
    if (!canWriteOrganisation(organisation)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This workspace is view only.')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final companyNumber = TextEditingController();
    var type = 'individual';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add ownership entity'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                      labelText: 'Ownership type',
                    ),
                    items: ownershipTypeLabels.entries
                        .map(
                          (entry) => DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => type = value!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Legal owner or entity name',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter the legal name'
                        : null,
                  ),
                  if (type == 'limited_company') ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: companyNumber,
                      decoration: const InputDecoration(
                        labelText: 'Companies House number',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return null;
                        }
                        return RegExp(
                          r'^[A-Za-z0-9]{8}$',
                        ).hasMatch(value.trim())
                            ? null
                            : 'Use the 8-character company number';
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'PropertyOS records your declared ownership arrangement. It does not verify ownership or determine legal or tax treatment.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Add entity'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    if (organisation == null) return;
    await ref.read(portfolioRepositoryProvider).createOwnershipEntity(
          organisationId: organisation.id,
          entityType: type,
          legalName: name.text,
          companyNumber: companyNumber.text,
        );
    ref.invalidate(ownershipEntitiesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entities = ref.watch(ownershipEntitiesProvider);
    final organisation = ref.watch(organisationProvider);
    final canWrite = canWriteOrganisation(organisation.valueOrNull);
    return WorkspacePage(
      eyebrow: 'Portfolio structure',
      title: 'Ownership entities',
      subtitle:
          'Individuals, joint owners, companies, trusts and partnerships.',
      action: canWrite
          ? FilledButton.icon(
              onPressed: () => _add(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add owner'),
            )
          : null,
      child: entities.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Text('Ownership entities could not be loaded.'),
        data: (items) => items.isEmpty
            ? const SuiteEmptyState(
                icon: Icons.account_balance_outlined,
                title: 'No ownership entities yet',
                message:
                    'Add the legal owner before onboarding your first property.',
              )
            : Card(
                child: Column(
                  children: items
                      .map(
                        (item) => ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 10),
                          leading: Container(
                              width: 44,
                              height: 44,
                              color: const Color(0xFFF0F4F6),
                              child: const Icon(Icons.account_balance_outlined,
                                  color: PropertyOsColours.navy)),
                          title: Text(item.legalName),
                          subtitle: Text(
                            ownershipTypeLabels[item.entityType] ??
                                item.entityType,
                          ),
                          trailing: item.companyNumber == null
                              ? null
                              : Text(item.companyNumber!),
                        ),
                      )
                      .toList(),
                ),
              ),
      ),
    );
  }
}
