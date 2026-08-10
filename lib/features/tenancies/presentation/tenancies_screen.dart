import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';
import 'package:property_os/features/tenancies/application/tenancy_providers.dart';
import 'package:property_os/features/tenancies/domain/tenancy_models.dart';
import 'package:property_os/features/timeline/application/timeline_providers.dart';
import 'package:property_os/features/today/application/today_providers.dart';

class TenanciesScreen extends ConsumerWidget {
  const TenanciesScreen({this.initialTenancyId, super.key});

  final String? initialTenancyId;

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    PortfolioTenancy? tenancy,
  }) async {
    final organisation = await ref.read(organisationProvider.future);
    if (!canWriteOrganisation(organisation)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This workspace is view only.')),
        );
      }
      return;
    }
    final properties = await ref.read(propertiesProvider.future);
    if (!context.mounted || organisation == null) return;
    if (properties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a property before a tenancy.')),
      );
      return;
    }
    final input = await showDialog<TenancyInput>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TenancyDialog(
        organisationId: organisation.id,
        properties: properties,
        tenancy: tenancy,
      ),
    );
    if (input == null) return;
    try {
      await ref.read(tenancyRepositoryProvider).save(input);
      _refresh(ref, input.propertyId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(tenancy == null ? 'Tenancy created.' : 'Tenancy updated.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The tenancy could not be saved.')),
        );
      }
    }
  }

  Future<void> _end(
    BuildContext context,
    WidgetRef ref,
    PortfolioTenancy tenancy,
  ) async {
    final organisation = await ref.read(organisationProvider.future);
    if (!canWriteOrganisation(organisation)) return;
    if (!context.mounted) return;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().isBefore(tenancy.startDate)
          ? tenancy.startDate
          : DateTime.now(),
      firstDate: tenancy.startDate,
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Select the actual tenancy end date',
    );
    if (date == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End tenancy?'),
        content: Text(
          'Record ${DateFormat('dd/MM/yyyy').format(date)} as the actual end date for ${tenancy.tenantDisplayName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('End tenancy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(tenancyRepositoryProvider).endTenancy(tenancy.id, date);
      _refresh(ref, tenancy.propertyId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenancy ended.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The tenancy could not be ended.')),
        );
      }
    }
  }

  Future<void> _reopen(
    BuildContext context,
    WidgetRef ref,
    PortfolioTenancy tenancy,
  ) async {
    final organisation = await ref.read(organisationProvider.future);
    if (!canWriteOrganisation(organisation) || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reopen tenancy?'),
        content: Text(
          'Move ${tenancy.tenantDisplayName} back to the current or upcoming register? The change will be recorded in the property timeline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reopen tenancy'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(tenancyRepositoryProvider).reopenTenancy(tenancy.id);
      _refresh(ref, tenancy.propertyId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenancy reopened.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The tenancy could not be reopened.')),
        );
      }
    }
  }

  void _refresh(WidgetRef ref, String propertyId) {
    ref.invalidate(tenanciesProvider);
    ref.invalidate(todayActionsProvider);
    ref.invalidate(propertyTimelineProvider(propertyId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organisation = ref.watch(organisationProvider);
    final canWrite = canWriteOrganisation(organisation.valueOrNull);
    final tenancies = ref.watch(tenanciesProvider);
    return WorkspacePage(
      eyebrow: 'Occupancy register',
      title: 'Tenancies',
      subtitle:
          'Current and historical tenancy dates with privacy-minimised tenant details.',
      action: canWrite
          ? FilledButton.icon(
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add tenancy'),
            )
          : null,
      child: tenancies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorPanel(
          onRetry: () => ref.invalidate(tenanciesProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const SuiteEmptyState(
              icon: Icons.key_outlined,
              title: 'No tenancies yet',
              message: 'Add the first tenancy when a property is occupied.',
            );
          }
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final current = items.where((item) => item.isCurrent(today)).toList();
          final upcoming =
              items.where((item) => item.isUpcoming(today)).toList();
          final historical = items.where((item) => item.isEnded).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TenancySection(
                title: 'Current',
                items: current,
                initialTenancyId: initialTenancyId,
                canWrite: canWrite,
                onEdit: (item) => _openForm(context, ref, tenancy: item),
                onEnd: (item) => _end(context, ref, item),
                onReopen: (_) {},
              ),
              const SizedBox(height: 18),
              _TenancySection(
                title: 'Upcoming',
                items: upcoming,
                initialTenancyId: initialTenancyId,
                canWrite: canWrite,
                onEdit: (item) => _openForm(context, ref, tenancy: item),
                onEnd: (item) => _end(context, ref, item),
                onReopen: (_) {},
              ),
              const SizedBox(height: 18),
              _TenancySection(
                title: 'Historical',
                items: historical,
                initialTenancyId: initialTenancyId,
                canWrite: canWrite,
                onEdit: (item) => _openForm(context, ref, tenancy: item),
                onEnd: (_) {},
                onReopen: (item) => _reopen(context, ref, item),
                historical: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TenancySection extends StatelessWidget {
  const _TenancySection({
    required this.title,
    required this.items,
    required this.initialTenancyId,
    required this.canWrite,
    required this.onEdit,
    required this.onEnd,
    required this.onReopen,
    this.historical = false,
  });

  final String title;
  final List<PortfolioTenancy> items;
  final String? initialTenancyId;
  final bool canWrite;
  final ValueChanged<PortfolioTenancy> onEdit;
  final ValueChanged<PortfolioTenancy> onEnd;
  final ValueChanged<PortfolioTenancy> onReopen;
  final bool historical;

  @override
  Widget build(BuildContext context) => SectionPanel(
        title: '$title (${items.length})',
        subtitle: items.isEmpty ? 'No ${title.toLowerCase()} tenancies' : null,
        child: items.isEmpty
            ? const SizedBox(height: 18)
            : Column(
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    _TenancyTile(
                      tenancy: items[index],
                      selected: items[index].id == initialTenancyId,
                      canWrite: canWrite,
                      onEdit: () => onEdit(items[index]),
                      onEnd: () => onEnd(items[index]),
                      onReopen: () => onReopen(items[index]),
                      historical: historical,
                    ),
                    if (index < items.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
      );
}

class _TenancyTile extends StatelessWidget {
  const _TenancyTile({
    required this.tenancy,
    required this.selected,
    required this.canWrite,
    required this.onEdit,
    required this.onEnd,
    required this.onReopen,
    required this.historical,
  });

  final PortfolioTenancy tenancy;
  final bool selected;
  final bool canWrite;
  final VoidCallback onEdit;
  final VoidCallback onEnd;
  final VoidCallback onReopen;
  final bool historical;

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      'Started ${_displayDate(tenancy.startDate)}',
      if (tenancy.fixedTermEndDate != null)
        'Fixed term ends ${_displayDate(tenancy.fixedTermEndDate!)}',
      if (tenancy.actualEndDate != null)
        'Ended ${_displayDate(tenancy.actualEndDate!)}',
      if (tenancy.monthlyRentPence != null)
        '${NumberFormat.currency(locale: 'en_GB', symbol: '£').format(tenancy.monthlyRentPence! / 100)} monthly',
      if (tenancy.rentDueDay != null) 'Due day ${tenancy.rentDueDay}',
    ];
    return Material(
      color: selected
          ? PropertyOsColours.amber.withValues(alpha: 0.12)
          : Colors.transparent,
      child: ListTile(
        onTap: canWrite ? onEdit : null,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: const CircleAvatar(child: Icon(Icons.key_outlined)),
        title: Text(tenancy.tenantDisplayName),
        subtitle: Text('${tenancy.propertyName}\n${details.join(' · ')}'),
        isThreeLine: true,
        trailing: canWrite
            ? Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Edit tenancy',
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  if (historical)
                    IconButton(
                      tooltip: 'Reopen tenancy',
                      onPressed: onReopen,
                      icon: const Icon(Icons.replay_outlined),
                    )
                  else
                    IconButton(
                      tooltip: 'End tenancy',
                      onPressed: onEnd,
                      icon: const Icon(Icons.event_busy_outlined),
                    ),
                ],
              )
            : null,
      ),
    );
  }
}

class _TenancyDialog extends StatefulWidget {
  const _TenancyDialog({
    required this.organisationId,
    required this.properties,
    this.tenancy,
  });

  final String organisationId;
  final List<Map<String, dynamic>> properties;
  final PortfolioTenancy? tenancy;

  @override
  State<_TenancyDialog> createState() => _TenancyDialogState();
}

class _TenancyDialogState extends State<_TenancyDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _propertyId =
      widget.tenancy?.propertyId ?? widget.properties.first['id'] as String;
  late final _tenant = TextEditingController(
    text: widget.tenancy?.tenantDisplayName,
  );
  late final _rent = TextEditingController(
    text: widget.tenancy?.monthlyRentPence == null
        ? ''
        : (widget.tenancy!.monthlyRentPence! / 100).toStringAsFixed(2),
  );
  late final _rentDay = TextEditingController(
    text: widget.tenancy?.rentDueDay?.toString() ?? '',
  );
  late DateTime _startDate = widget.tenancy?.startDate ?? DateTime.now();
  late DateTime? _fixedEndDate = widget.tenancy?.fixedTermEndDate;
  late DateTime? _actualEndDate = widget.tenancy?.actualEndDate;

  @override
  void dispose() {
    _tenant.dispose();
    _rent.dispose();
    _rentDay.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fixedEndDate ?? _startDate.add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _fixedEndDate = picked);
  }

  Future<void> _pickActualEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _actualEndDate ?? _startDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _actualEndDate = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final rent = _rent.text.trim().isEmpty ? null : double.parse(_rent.text);
    Navigator.pop(
      context,
      TenancyInput(
        tenancyId: widget.tenancy?.id,
        organisationId: widget.organisationId,
        propertyId: _propertyId,
        tenantDisplayName: _tenant.text.trim(),
        startDate: _startDate,
        fixedTermEndDate: _fixedEndDate,
        actualEndDate: _actualEndDate,
        monthlyRentPence: rent == null ? null : (rent * 100).round(),
        rentDueDay:
            _rentDay.text.trim().isEmpty ? null : int.parse(_rentDay.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.tenancy == null ? 'Add tenancy' : 'Edit tenancy'),
        content: SizedBox(
          width: 540,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _propertyId,
                    decoration: const InputDecoration(labelText: 'Property'),
                    items: [
                      for (final property in widget.properties)
                        DropdownMenuItem(
                          value: property['id'] as String,
                          child: Text(_propertyLabel(property)),
                        ),
                    ],
                    onChanged: (value) => _propertyId = value!,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _tenant,
                    decoration: const InputDecoration(
                      labelText: 'Lead tenant display name or initials',
                      helperText: 'Do not enter identity document details.',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter a display name or initials'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _DateField(
                    label: 'Start date',
                    value: _startDate,
                    onPressed: _pickStart,
                  ),
                  if (widget.tenancy?.isEnded == true) ...[
                    const SizedBox(height: 14),
                    _DateField(
                      label: 'Actual end date',
                      value: _actualEndDate,
                      onPressed: _pickActualEnd,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _DateField(
                    label: 'Fixed-term end date (optional)',
                    value: _fixedEndDate,
                    onPressed: _pickEnd,
                    onClear: _fixedEndDate == null
                        ? null
                        : () => setState(() => _fixedEndDate = null),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _rent,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Monthly rent (optional)',
                      prefixText: '£ ',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final amount = double.tryParse(value.trim());
                      return amount == null || amount < 0
                          ? 'Enter a valid GBP amount'
                          : null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _rentDay,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Payment day (optional)',
                      helperText: 'Use a day from 1 to 28.',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final day = int.tryParse(value.trim());
                      return day == null || day < 1 || day > 28
                          ? 'Enter a day from 1 to 28'
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
            onPressed: _save,
            child:
                Text(widget.tenancy == null ? 'Add tenancy' : 'Save changes'),
          ),
        ],
      );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPressed,
    this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(value == null ? 'Not set' : _displayDate(value!)),
            ),
            if (onClear != null)
              IconButton(
                tooltip: 'Clear date',
                onPressed: onClear,
                icon: const Icon(Icons.clear),
              ),
            TextButton(onPressed: onPressed, child: const Text('Choose')),
          ],
        ),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const Expanded(child: Text('Tenancies could not be loaded.')),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}

String _displayDate(DateTime value) => DateFormat('dd/MM/yyyy').format(value);

String _propertyLabel(Map<String, dynamic> property) {
  final displayName = (property['display_name'] as String?)?.trim();
  if (displayName?.isNotEmpty == true) return displayName!;
  final address = property['address_line_1'] as String;
  final postcode = property['postcode'] as String?;
  return postcode == null || postcode.isEmpty ? address : '$address, $postcode';
}
