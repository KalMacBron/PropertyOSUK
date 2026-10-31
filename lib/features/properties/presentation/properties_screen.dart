import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

class PropertiesScreen extends ConsumerWidget {
  const PropertiesScreen({this.initialPropertyId, super.key});

  final String? initialPropertyId;

  Future<void> _addProperty(BuildContext context, WidgetRef ref) async {
    final organisation = await ref.read(organisationProvider.future);
    if (!canWriteOrganisation(organisation)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This workspace is view only.')),
        );
      }
      return;
    }
    final owners = await ref.read(ownershipEntitiesProvider.future);
    if (!context.mounted || organisation == null) return;
    if (owners.isEmpty) {
      final router = GoRouter.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add an owner before you add a property.'),
          action: SnackBarAction(
            label: 'Add owner',
            onPressed: () => router.go('/ownership'),
          ),
        ),
      );
      return;
    }
    _PropertyDraft? draft;
    while (true) {
      if (!context.mounted) return;
      final saved = await showDialog<_PropertyDraft>(
        context: context,
        builder: (_) => _PropertyDialog(owners: owners, initial: draft),
      );
      if (saved == null || !context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      try {
        await ref.read(portfolioRepositoryProvider).createProperty(
              organisationId: organisation.id,
              ownershipEntityId: saved.ownerId,
              ownershipPercentage: saved.percentage,
              addressLine1: saved.address,
              townOrCity: saved.town,
              postcode: saved.postcode,
              displayName: saved.displayName,
              propertyType: saved.propertyType,
              bedrooms: saved.bedrooms,
            );
      } catch (_) {
        // Keep what the user typed and let them try again.
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Property not added. Check your connection and try again.',
              ),
            ),
          );
        draft = saved;
        continue;
      }
      ref.invalidate(propertiesProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Property added')),
        );
      return;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(propertiesProvider);
    final organisation = ref.watch(organisationProvider);
    final canWrite = canWriteOrganisation(organisation.valueOrNull);
    return WorkspacePage(
      eyebrow: 'Portfolio register',
      title: 'Properties',
      subtitle: 'Your active residential property portfolio.',
      action: canWrite
          ? FilledButton.icon(
              onPressed: () => _addProperty(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add property'),
            )
          : null,
      child: properties.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => SuiteErrorState(
          message: 'Properties could not be loaded.',
          onRetry: () => ref.invalidate(propertiesProvider),
        ),
        data: (items) => items.isEmpty
            ? SuiteEmptyState(
                icon: Icons.home_work_outlined,
                title: 'No properties yet',
                message: canWrite
                    ? 'Add an owner, then add your first property.'
                    : 'No properties have been added to this workspace yet.',
                action: canWrite
                    ? OutlinedButton(
                        onPressed: () => context.go('/ownership'),
                        child: const Text('Add owner'),
                      )
                    : null,
              )
            : Card(
                child: Column(
                  children: items.map((item) {
                    final owners =
                        item['property_ownerships'] as List<dynamic>? ?? [];
                    final ownerNames = owners
                        .map(
                          (row) => (row['ownership_entities']
                              as Map<String, dynamic>?)?['legal_name'],
                        )
                        .whereType<String>()
                        .join(', ');
                    final selected = item['id'] == initialPropertyId;
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: selected
                                ? PropertyOsColours.amber
                                : Colors.transparent,
                            width: 4,
                          ),
                        ),
                      ),
                      child: ListTile(
                        selected: selected,
                        selectedColor: PropertyOsColours.ink,
                        selectedTileColor: const Color(0xFFFFF4D8),
                        onTap: () => context.go('/properties/${item['id']}'),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        leading: Container(
                            width: 44,
                            height: 44,
                            color: const Color(0xFFF0F4F6),
                            child: const Icon(Icons.home_outlined,
                                color: PropertyOsColours.navy)),
                        title: Text(
                          (item['display_name'] as String?)?.isNotEmpty == true
                              ? item['display_name'] as String
                              : item['address_line_1'] as String,
                        ),
                        subtitle: Text(
                          '${item['address_line_1']}, ${item['town_or_city']}, ${item['postcode']}\nOwner: $ownerNames',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }
}

class _PropertyDraft {
  const _PropertyDraft({
    required this.ownerId,
    required this.percentage,
    required this.address,
    required this.town,
    required this.postcode,
    this.displayName,
    this.propertyType,
    this.bedrooms,
  });
  final String ownerId, address, town, postcode;
  final double percentage;
  final String? displayName, propertyType;
  final int? bedrooms;
}

class _PropertyDialog extends StatefulWidget {
  const _PropertyDialog({required this.owners, this.initial});
  final List<OwnershipEntity> owners;
  final _PropertyDraft? initial;
  @override
  State<_PropertyDialog> createState() => _PropertyDialogState();
}

class _PropertyDialogState extends State<_PropertyDialog> {
  final _key = GlobalKey<FormState>();
  late final _displayName =
      TextEditingController(text: widget.initial?.displayName ?? '');
  late final _address =
      TextEditingController(text: widget.initial?.address ?? '');
  late final _town = TextEditingController(text: widget.initial?.town ?? '');
  late final _postcode =
      TextEditingController(text: widget.initial?.postcode ?? '');
  late final _bedrooms =
      TextEditingController(text: widget.initial?.bedrooms?.toString() ?? '');
  late final _percentage = TextEditingController(
    text: widget.initial == null
        ? '100'
        : _percentText(widget.initial!.percentage),
  );
  late String _ownerId =
      widget.owners.any((o) => o.id == widget.initial?.ownerId)
          ? widget.initial!.ownerId
          : widget.owners.first.id;
  late String _propertyType = widget.initial?.propertyType ?? 'House';

  @override
  void dispose() {
    _displayName.dispose();
    _address.dispose();
    _town.dispose();
    _postcode.dispose();
    _bedrooms.dispose();
    _percentage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Add property'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: _key,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: _displayName,
                    decoration: const InputDecoration(
                      labelText: 'Property name (optional)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    decoration:
                        const InputDecoration(labelText: 'Address line 1'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _town,
                    decoration:
                        const InputDecoration(labelText: 'Town or city'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _postcode,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Postcode'),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _propertyType,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Property type'),
                    items: ['House', 'Flat', 'Maisonette', 'HMO', 'Other']
                        .map(
                          (value) => DropdownMenuItem(
                              value: value, child: Text(value)),
                        )
                        .toList(),
                    onChanged: (value) => _propertyType = value!,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _bedrooms,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Bedrooms (optional)',
                    ),
                  ),
                  const Divider(height: 32),
                  DropdownButtonFormField<String>(
                    initialValue: _ownerId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Owner'),
                    items: widget.owners
                        .map(
                          (owner) => DropdownMenuItem(
                            value: owner.id,
                            child: Text(
                              owner.legalName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => _ownerId = value!,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _percentage,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Ownership percentage',
                    ),
                    validator: (value) {
                      final number = double.tryParse(value ?? '');
                      return number == null || number <= 0 || number > 100
                          ? 'Enter a percentage from 0.01 to 100'
                          : null;
                    },
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
                _PropertyDraft(
                  ownerId: _ownerId,
                  percentage: double.parse(_percentage.text),
                  address: _address.text,
                  town: _town.text,
                  postcode: _postcode.text,
                  displayName: _displayName.text,
                  propertyType: _propertyType,
                  bedrooms: int.tryParse(_bedrooms.text),
                ),
              );
            },
            child: const Text('Add property'),
          ),
        ],
      );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

String _percentText(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';
