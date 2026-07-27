import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

class PropertiesScreen extends ConsumerWidget {
  const PropertiesScreen({super.key});

  Future<void> _addProperty(BuildContext context, WidgetRef ref) async {
    final organisation = await ref.read(organisationProvider.future);
    final owners = await ref.read(ownershipEntitiesProvider.future);
    if (!context.mounted || organisation == null) return;
    if (owners.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an ownership entity first.')),
      );
      return;
    }
    final saved = await showDialog<_PropertyDraft>(
      context: context,
      builder: (_) => _PropertyDialog(owners: owners),
    );
    if (saved == null) return;
    await ref
        .read(portfolioRepositoryProvider)
        .createProperty(
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
    ref.invalidate(propertiesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final properties = ref.watch(propertiesProvider);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Properties',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
                ),
                Text('Your active property portfolio.'),
              ],
            ),
            FilledButton.icon(
              onPressed: () => _addProperty(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add property'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        properties.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('Properties could not be loaded.'),
          data: (items) => items.isEmpty
              ? const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No properties yet. Add an owner, then onboard your first property.',
                    ),
                  ),
                )
              : Card(
                  child: Column(
                    children: items.map((item) {
                      final owners =
                          item['property_ownerships'] as List<dynamic>? ?? [];
                      final ownerNames = owners
                          .map(
                            (row) =>
                                (row['ownership_entities']
                                    as Map<String, dynamic>?)?['legal_name'],
                          )
                          .whereType<String>()
                          .join(', ');
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.home_outlined),
                        ),
                        title: Text(
                          (item['display_name'] as String?)?.isNotEmpty == true
                              ? item['display_name'] as String
                              : item['address_line_1'] as String,
                        ),
                        subtitle: Text(
                          '${item['address_line_1']}, ${item['town_or_city']}, ${item['postcode']}\nOwner: $ownerNames',
                        ),
                        isThreeLine: true,
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
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
  const _PropertyDialog({required this.owners});
  final List<OwnershipEntity> owners;
  @override
  State<_PropertyDialog> createState() => _PropertyDialogState();
}

class _PropertyDialogState extends State<_PropertyDialog> {
  final _key = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _address = TextEditingController();
  final _town = TextEditingController();
  final _postcode = TextEditingController();
  final _bedrooms = TextEditingController();
  final _percentage = TextEditingController(text: '100');
  late String _ownerId = widget.owners.first.id;
  String _propertyType = 'House';

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
                decoration: const InputDecoration(labelText: 'Address line 1'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _town,
                decoration: const InputDecoration(labelText: 'Town or city'),
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
                decoration: const InputDecoration(labelText: 'Property type'),
                items: ['House', 'Flat', 'Maisonette', 'HMO', 'Other']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
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
                decoration: const InputDecoration(labelText: 'Legal owner'),
                items: widget.owners
                    .map(
                      (owner) => DropdownMenuItem(
                        value: owner.id,
                        child: Text(owner.legalName),
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
