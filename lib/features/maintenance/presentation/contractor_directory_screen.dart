import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/features/maintenance/application/maintenance_providers.dart';
import 'package:property_os/features/maintenance/domain/maintenance_models.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

class ContractorDirectoryScreen extends ConsumerStatefulWidget {
  const ContractorDirectoryScreen({super.key});

  @override
  ConsumerState<ContractorDirectoryScreen> createState() =>
      _ContractorDirectoryScreenState();
}

class _ContractorDirectoryScreenState
    extends ConsumerState<ContractorDirectoryScreen> {
  final _search = TextEditingController();
  bool _showArchived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final organisation = ref.watch(organisationProvider);
    final canWrite = canWriteOrganisation(organisation.valueOrNull);
    final contractors = ref.watch(contractorDirectoryProvider);
    return WorkspacePage(
      eyebrow: 'Maintenance',
      title: 'Contractor directory',
      subtitle: 'Maintain the people and businesses used for property repairs.',
      action: canWrite
          ? FilledButton.icon(
              onPressed: () => _edit(null),
              icon: const Icon(Icons.add),
              label: const Text('Add contractor'),
            )
          : const Chip(label: Text('VIEW ONLY')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 340,
                    child: TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Search contractor or trade',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  FilterChip(
                    selected: _showArchived,
                    label: const Text('Show archived'),
                    onSelected: (value) =>
                        setState(() => _showArchived = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          contractors.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => SuiteEmptyState(
              icon: Icons.error_outline,
              title: 'Contractors could not be loaded',
              message: 'Refresh the page to load the directory again.',
            ),
            data: (items) {
              final query = _search.text.trim().toLowerCase();
              final visible = items.where((item) {
                if (!_showArchived && !item.isActive) return false;
                if (query.isEmpty) return true;
                return item.name.toLowerCase().contains(query) ||
                    (item.trade?.toLowerCase().contains(query) ?? false);
              }).toList();
              if (visible.isEmpty) {
                return const SuiteEmptyState(
                  icon: Icons.engineering_outlined,
                  title: 'No contractors in this view',
                  message: 'Add a contractor or change the directory filters.',
                );
              }
              return Card(
                child: Column(
                  children: [
                    for (final contractor in visible)
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 10,
                        ),
                        leading: CircleAvatar(
                          child: Icon(
                            contractor.isActive
                                ? Icons.engineering_outlined
                                : Icons.archive_outlined,
                          ),
                        ),
                        title: Text(contractor.name),
                        subtitle: Text([
                          if (contractor.trade != null) contractor.trade!,
                          if (contractor.email != null) contractor.email!,
                          if (contractor.phone != null) contractor.phone!,
                        ].join(' · ')),
                        trailing: canWrite
                            ? TextButton(
                                onPressed: () => _edit(contractor),
                                child: const Text('Edit'),
                              )
                            : contractor.isActive
                                ? null
                                : const Chip(label: Text('ARCHIVED')),
                        onTap: canWrite ? () => _edit(contractor) : null,
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _edit(MaintenanceContractor? contractor) async {
    final organisation = await ref.read(organisationProvider.future);
    if (!canWriteOrganisation(organisation) ||
        organisation == null ||
        !mounted) {
      return;
    }
    final input = await showDialog<ContractorInput>(
      context: context,
      builder: (_) => ContractorEditorDialog(
        organisationId: organisation.id,
        contractor: contractor,
      ),
    );
    if (input == null) return;
    try {
      await ref.read(maintenanceRepositoryProvider).saveContractor(input);
      refreshMaintenance(ref);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The contractor could not be saved.')),
        );
      }
    }
  }
}

class ContractorEditorDialog extends StatefulWidget {
  const ContractorEditorDialog({
    required this.organisationId,
    this.contractor,
    super.key,
  });

  final String organisationId;
  final MaintenanceContractor? contractor;

  @override
  State<ContractorEditorDialog> createState() => _ContractorEditorDialogState();
}

class _ContractorEditorDialogState extends State<ContractorEditorDialog> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.contractor?.name);
  late final _trade = TextEditingController(text: widget.contractor?.trade);
  late final _email = TextEditingController(text: widget.contractor?.email);
  late final _phone = TextEditingController(text: widget.contractor?.phone);
  late final _notes = TextEditingController(text: widget.contractor?.notes);
  late bool _active = widget.contractor?.isActive ?? true;

  @override
  void dispose() {
    _name.dispose();
    _trade.dispose();
    _email.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            widget.contractor == null ? 'Add contractor' : 'Edit contractor'),
        content: SizedBox(
          width: 560,
          child: Form(
            key: _key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _name,
                    maxLength: 160,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Contractor or business name',
                    ),
                    validator: (value) => value?.trim().isEmpty != false
                        ? 'Enter the contractor name.'
                        : null,
                  ),
                  TextFormField(
                    controller: _trade,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Trade (optional)',
                    ),
                  ),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email (optional)',
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return null;
                      return RegExp(r'^\S+@\S+\.\S+$').hasMatch(email)
                          ? null
                          : 'Enter a valid email address.';
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Telephone (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notes,
                    maxLength: 2000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                  ),
                  if (widget.contractor != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active contractor'),
                      subtitle: const Text(
                        'Archived contractors remain on historical issues.',
                      ),
                      value: _active,
                      onChanged: (value) => setState(() => _active = value),
                    ),
                ],
              ),
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
              if (!_key.currentState!.validate()) return;
              Navigator.pop(
                context,
                ContractorInput(
                  contractorId: widget.contractor?.id,
                  organisationId: widget.organisationId,
                  name: _name.text,
                  trade: _trade.text,
                  email: _email.text,
                  phone: _phone.text,
                  notes: _notes.text,
                  status: _active ? 'active' : 'archived',
                ),
              );
            },
            child: Text(widget.contractor == null ? 'Add contractor' : 'Save'),
          ),
        ],
      );
}
