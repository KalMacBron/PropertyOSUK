import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';

class WorkspaceSetupScreen extends ConsumerStatefulWidget {
  const WorkspaceSetupScreen({super.key});

  @override
  ConsumerState<WorkspaceSetupScreen> createState() =>
      _WorkspaceSetupScreenState();
}

class _WorkspaceSetupScreenState extends ConsumerState<WorkspaceSetupScreen> {
  final _organisation = TextEditingController();
  final _legalName = TextEditingController();
  final _companyNumber = TextEditingController();
  final _address = TextEditingController();
  final _town = TextEditingController();
  final _postcode = TextEditingController();
  var _step = 0;
  var _entityType = 'individual';
  String? _organisationId;
  String? _ownershipEntityId;
  bool _saving = false;
  String? _error;

  String get _displayName {
    final metadata = ref.read(supabaseProvider).auth.currentUser?.userMetadata;
    return metadata?['display_name']?.toString().trim() ?? '';
  }

  Future<void> _createOrganisation() async {
    if (_organisation.text.trim().isEmpty) {
      setState(() => _error = 'Enter a portfolio name.');
      return;
    }
    if (_organisation.text.trim().length > 120) {
      setState(
          () => _error = 'Use 120 characters or fewer for the portfolio name.');
      return;
    }
    await _run(() async {
      final organisation =
          await ref.read(portfolioRepositoryProvider).createOrganisation(
                _organisation.text,
                displayName: _displayName,
              );
      _organisationId = organisation.id;
      _legalName.text = _entityType == 'individual' ? _displayName : '';
      setState(() => _step = 1);
    });
  }

  Future<void> _createOwnership() async {
    if (_legalName.text.trim().isEmpty) {
      setState(() => _error = 'Enter the legal owner name.');
      return;
    }
    await _run(() async {
      _ownershipEntityId =
          await ref.read(portfolioRepositoryProvider).createOwnershipEntity(
                organisationId: _organisationId!,
                entityType: _entityType,
                legalName: _legalName.text,
                companyNumber: _companyNumber.text,
              );
      setState(() => _step = 2);
    });
  }

  Future<void> _createProperty() async {
    if (_address.text.trim().isEmpty ||
        _town.text.trim().isEmpty ||
        _postcode.text.trim().isEmpty) {
      setState(() => _error = 'Enter the property address, town and postcode.');
      return;
    }
    await _run(() async {
      await ref.read(portfolioRepositoryProvider).createProperty(
            organisationId: _organisationId!,
            ownershipEntityId: _ownershipEntityId!,
            ownershipPercentage: 100,
            addressLine1: _address.text,
            townOrCity: _town.text,
            postcode: _postcode.text,
          );
      _finish();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'We could not save this step. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _finish() {
    ref.invalidate(organisationMembershipsProvider);
    ref.invalidate(organisationProvider);
    ref.invalidate(ownershipEntitiesProvider);
    ref.invalidate(propertiesProvider);
  }

  @override
  void dispose() {
    _organisation.dispose();
    _legalName.dispose();
    _companyNumber.dispose();
    _address.dispose();
    _town.dispose();
    _postcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PropertyOsColours.workspace,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: ColoredBox(
                          color: PropertyOsColours.deepNavy,
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: SuiteBrand(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text('Step ${_step + 1} of 3',
                          style: const TextStyle(
                              color: PropertyOsColours.amberText,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        switch (_step) {
                          0 => 'Set up your portfolio',
                          1 => 'Who owns the properties?',
                          _ => 'Add your first property',
                        },
                        style: const TextStyle(
                            fontSize: 36, color: PropertyOsColours.ink),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        switch (_step) {
                          0 =>
                            'For individual landlords and companies alike. Give your private workspace a name; you can choose Individual as the owner type on the next step.',
                          1 =>
                            'Record the individual or company that legally owns property.',
                          _ =>
                            'You can add the first property now or continue with an empty portfolio.',
                        },
                        style: const TextStyle(color: PropertyOsColours.muted),
                      ),
                      const SizedBox(height: 28),
                      if (_step == 0) _organisationStep(),
                      if (_step == 1) _ownershipStep(),
                      if (_step == 2) _propertyStep(),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _organisationStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _organisation,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Portfolio name',
              hintText: 'My property portfolio',
            ),
            onSubmitted: (_) => _createOrganisation(),
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving ? null : _createOrganisation,
            child: Text(_saving ? 'Creating…' : 'Create portfolio'),
          ),
        ],
      );

  Widget _ownershipStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _entityType,
            decoration: const InputDecoration(labelText: 'Owner type'),
            items: const [
              DropdownMenuItem(value: 'individual', child: Text('Individual')),
              DropdownMenuItem(
                  value: 'limited_company', child: Text('Limited company')),
              DropdownMenuItem(value: 'joint', child: Text('Joint owners')),
              DropdownMenuItem(value: 'trust', child: Text('Trust')),
              DropdownMenuItem(
                  value: 'partnership', child: Text('Partnership')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) => setState(() => _entityType = value!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _legalName,
            decoration: const InputDecoration(labelText: 'Legal owner name'),
          ),
          if (_entityType == 'limited_company') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _companyNumber,
              decoration: const InputDecoration(labelText: 'Company number'),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving ? null : _createOwnership,
            child: Text(_saving ? 'Saving…' : 'Save ownership details'),
          ),
          TextButton(
            onPressed: _saving ? null : _finish,
            child: const Text('Skip for now'),
          ),
        ],
      );

  Widget _propertyStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _address,
            decoration: const InputDecoration(labelText: 'Address line 1'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _town,
                  decoration: const InputDecoration(labelText: 'Town or city'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _postcode,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Postcode'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _saving ? null : _createProperty,
            child: Text(_saving ? 'Adding…' : 'Add property and continue'),
          ),
          TextButton(
            onPressed: _saving ? null : _finish,
            child: const Text('Continue without a property'),
          ),
        ],
      );
}
