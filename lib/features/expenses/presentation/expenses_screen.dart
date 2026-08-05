import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:property_os/features/documents/domain/compliance_evidence.dart';
import 'package:property_os/features/expenses/application/expense_providers.dart';
import 'package:property_os/features/expenses/data/expense_repository.dart';
import 'package:property_os/features/expenses/domain/expense_models.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> showExpenseDeleteConfirmation(
  BuildContext context,
  PropertyExpense expense,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete expense?'),
      content: Text(
        '${DateFormat('dd/MM/yyyy').format(expense.expenseDate)} · '
        '${expense.propertyName}\n${expense.description}\n'
        '${pounds(expense.amountPence)}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({
    this.initialPropertyId,
    this.initialComplianceRecordId,
    this.openCreate = false,
    super.key,
  });

  final String? initialPropertyId;
  final String? initialComplianceRecordId;
  final bool openCreate;

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  late String? _propertyId = widget.initialPropertyId;
  bool _openedInitialDialog = false;
  bool _deleting = false;

  Future<void> _openForm({
    PropertyExpense? expense,
    String? propertyId,
    String? complianceRecordId,
  }) async {
    final organisation = await ref.read(organisationProvider.future);
    final properties = await ref.read(expensePropertiesProvider.future);
    if (!mounted || organisation == null || properties.isEmpty) return;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ExpenseDialog(
        organisationId: organisation.id,
        properties: properties,
        expense: expense,
        initialPropertyId: propertyId,
        initialComplianceRecordId: complianceRecordId,
        repository: ref.read(expenseRepositoryProvider),
      ),
    );

    if (saved == true) refreshExpenses(ref);
  }

  Future<void> _delete(PropertyExpense expense) async {
    final confirmed = await showExpenseDeleteConfirmation(context, expense);

    if (!confirmed) return;
    setState(() => _deleting = true);
    try {
      await ref.read(expenseRepositoryProvider).deleteExpense(expense);
      refreshExpenses(ref);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted.')),
        );
      }
    } on ExpenseValidationException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The expense could not be deleted.')),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _pickEvidence(PropertyExpense expense) async {
    final picked = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;

    final mime = switch (file.extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };

    try {
      await ref.read(expenseRepositoryProvider).uploadEvidence(
            expense: expense,
            file: EvidenceFile(
              name: file.name,
              mimeType: mime,
              bytes: file.bytes!,
            ),
          );
      refreshExpenses(ref);
    } on ExpenseValidationException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The evidence could not be uploaded.')),
      );
    }
  }

  Future<void> _viewEvidence(ExpenseEvidence evidence) async {
    final url = await ref.read(expenseRepositoryProvider).evidenceUrl(evidence);
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  }

  Future<void> _removeEvidence(ExpenseEvidence evidence) async {
    await ref.read(expenseRepositoryProvider).deleteEvidence(evidence);
    refreshExpenses(ref);
  }

  Future<void> _export(List<PropertyExpense> expenses) async {
    final csv = csvForExpenses(expenses);
    final uri = Uri.dataFromString(csv, mimeType: 'text/csv', encoding: utf8);
    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The CSV export could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final organisation = ref.watch(organisationProvider);
    final properties = ref.watch(expensePropertiesProvider);
    final expenses = ref.watch(expensesProvider);
    final canWrite = organisation.valueOrNull?.role != 'viewer';
    final canDelete =
        const ['owner', 'admin'].contains(organisation.valueOrNull?.role);

    if (widget.openCreate && !_openedInitialDialog) {
      _openedInitialDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openForm(
            propertyId: widget.initialPropertyId,
            complianceRecordId: widget.initialComplianceRecordId,
          ));
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Property expenses',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
                ),
                Text('Track what each property costs to operate. GBP only.'),
              ],
            ),
            if (canWrite)
              FilledButton.icon(
                onPressed: () => _openForm(propertyId: _propertyId),
                icon: const Icon(Icons.add),
                label: const Text('Record expense'),
              ),
          ],
        ),
        if (_deleting) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 24),
        properties.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _Message('Properties could not be loaded.'),
          data: (propertyItems) => expenses.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => _Message(
              'Expenses could not be loaded.',
              action: TextButton(
                onPressed: () => ref.invalidate(expensesProvider),
                child: const Text('Try again'),
              ),
            ),
            data: (allExpenses) {
              final filtered = _propertyId == null
                  ? allExpenses
                  : allExpenses
                      .where((expense) => expense.propertyId == _propertyId)
                      .toList();
              final total = filtered.fold<int>(
                0,
                (sum, expense) => sum + expense.amountPence,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Filters(
                    properties: propertyItems,
                    selectedPropertyId: _propertyId,
                    onPropertyChanged: (value) =>
                        setState(() => _propertyId = value),
                    onClear: () => setState(() => _propertyId = null),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _Summary(label: 'Total expenditure', value: pounds(total)),
                      _Summary(label: 'Expenses', value: '${filtered.length}'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: filtered.isEmpty ? null : () => _export(filtered),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export filtered CSV'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    const _Message('No expenses match these filters.')
                  else
                    ...filtered.map(
                      (expense) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExpenseCard(
                          expense: expense,
                          canWrite: canWrite,
                          canDelete: canDelete,
                          deleting: _deleting,
                          onEdit: () => _openForm(expense: expense),
                          onDelete: () => _delete(expense),
                          onUpload: () => _pickEvidence(expense),
                          onViewEvidence: expense.evidence == null
                              ? null
                              : () => _viewEvidence(expense.evidence!),
                          onRemoveEvidence: expense.evidence == null
                              ? null
                              : () => _removeEvidence(expense.evidence!),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Categories are organisational labels only. PropertyOS does not '
                    'determine tax deductibility or produce accounts.',
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.properties,
    required this.selectedPropertyId,
    required this.onPropertyChanged,
    required this.onClear,
  });

  final List<ExpenseProperty> properties;
  final String? selectedPropertyId;
  final ValueChanged<String?> onPropertyChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String?>(
                  initialValue: selectedPropertyId,
                  decoration: const InputDecoration(labelText: 'Property'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All properties'),
                    ),
                    ...properties.map(
                      (property) => DropdownMenuItem<String?>(
                        value: property.id,
                        child: Text(property.name),
                      ),
                    ),
                  ],
                  onChanged: onPropertyChanged,
                ),
              ),
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('Clear filters'),
              ),
            ],
          ),
        ),
      );
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.canWrite,
    required this.canDelete,
    required this.deleting,
    required this.onEdit,
    required this.onDelete,
    required this.onUpload,
    required this.onViewEvidence,
    required this.onRemoveEvidence,
  });

  final PropertyExpense expense;
  final bool canWrite;
  final bool canDelete;
  final bool deleting;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUpload;
  final VoidCallback? onViewEvidence;
  final VoidCallback? onRemoveEvidence;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    child: Text('£', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${expense.description} · ${pounds(expense.amountPence)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${expense.propertyName} · '
                          '${DateFormat('dd/MM/yyyy').format(expense.expenseDate)} · '
                          '${expenseCategoryLabel(expense.category)}',
                        ),
                      ],
                    ),
                  ),
                  if (canWrite)
                    IconButton(
                      tooltip: 'Edit expense',
                      onPressed: deleting ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (canDelete)
                    IconButton(
                      tooltip: 'Delete expense',
                      onPressed: deleting ? null : onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Owner: ${expense.ownershipEntityName}'),
                  Text('Status: ${expense.paymentStatus}'),
                  if (expense.supplier != null) Text('Supplier: ${expense.supplier}'),
                  if (expense.complianceRequirement != null)
                    Text('Compliance: ${expense.complianceRequirement}'),
                  if (expense.evidence == null && canWrite)
                    TextButton.icon(
                      onPressed: onUpload,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Add evidence'),
                    ),
                  if (expense.evidence != null) ...[
                    TextButton.icon(
                      onPressed: onViewEvidence,
                      icon: const Icon(Icons.open_in_new),
                      label: Text(expense.evidence!.filename),
                    ),
                    if (canDelete)
                      TextButton(
                        onPressed: onRemoveEvidence,
                        child: const Text('Remove evidence'),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog({
    required this.organisationId,
    required this.properties,
    required this.repository,
    this.expense,
    this.initialPropertyId,
    this.initialComplianceRecordId,
  });

  final String organisationId;
  final List<ExpenseProperty> properties;
  final ExpenseRepository repository;
  final PropertyExpense? expense;
  final String? initialPropertyId;
  final String? initialComplianceRecordId;

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _key = GlobalKey<FormState>();

  late String _propertyId = widget.expense?.propertyId ??
      widget.initialPropertyId ??
      widget.properties.first.id;
  late String _ownerId = widget.expense?.ownershipEntityId ??
      _ownersFor(_propertyId).first.id;
  late DateTime _date = widget.expense?.expenseDate ?? DateTime.now();
  late String _category = widget.expense?.category ??
      (widget.initialComplianceRecordId == null
          ? 'repairs_maintenance'
          : 'compliance_certificates');
  late String _vatTreatment = widget.expense?.vatTreatment ?? 'not_specified';
  late String _paymentStatus = widget.expense?.paymentStatus ?? 'paid';
  late String? _complianceId =
      widget.expense?.complianceRecordId ?? widget.initialComplianceRecordId;

  late final _supplier = TextEditingController(text: widget.expense?.supplier);
  late final _description =
      TextEditingController(text: widget.expense?.description);
  late final _amount = TextEditingController(
    text: widget.expense == null
        ? ''
        : (widget.expense!.amountPence / 100).toStringAsFixed(2),
  );
  late final _vat = TextEditingController(
    text: widget.expense?.vatAmountPence == null
        ? ''
        : (widget.expense!.vatAmountPence! / 100).toStringAsFixed(2),
  );
  late final _notes = TextEditingController(text: widget.expense?.notes);

  List<Map<String, dynamic>> _compliance = const [];
  bool _saving = false;

  List<ExpenseOwner> _ownersFor(String id) =>
      widget.properties.firstWhere((property) => property.id == id).owners;

  @override
  void initState() {
    super.initState();
    _loadCompliance();
  }

  @override
  void dispose() {
    _supplier.dispose();
    _description.dispose();
    _amount.dispose();
    _vat.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadCompliance() async {
    final rows = await widget.repository
        .listComplianceRecords(widget.organisationId, _propertyId);
    if (mounted) setState(() => _compliance = rows);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final total = parsePoundsToPence(_amount.text);
      final vat =
          _vat.text.trim().isEmpty ? null : parsePoundsToPence(_vat.text);
      if (vat != null && vat > total) {
        throw const FormatException('VAT cannot exceed the total amount.');
      }
      await widget.repository.saveExpense(
        id: widget.expense?.id,
        organisationId: widget.organisationId,
        propertyId: _propertyId,
        ownershipEntityId: _ownerId,
        expenseDate: _date,
        supplier: _supplier.text,
        description: _description.text,
        category: _category,
        amountPence: total,
        vatTreatment: _vatTreatment,
        vatAmountPence: vat,
        paymentStatus: _paymentStatus,
        complianceRecordId: _complianceId,
        notes: _notes.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The expense could not be saved.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ownersFor(_propertyId).isEmpty) {
      return const AlertDialog(
        title: Text('Record expense'),
        content: Text('This property needs an ownership entity before expenses can be recorded.'),
      );
    }

    return AlertDialog(
      title: Text(widget.expense == null ? 'Record expense' : 'Edit expense'),
      content: SizedBox(
        width: 620,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _propertyId,
                  decoration: const InputDecoration(labelText: 'Property'),
                  items: widget.properties
                      .map((item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _propertyId = value;
                      _ownerId = _ownersFor(value).first.id;
                      _complianceId = null;
                      _compliance = const [];
                    });
                    _loadCompliance();
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey('owner-$_propertyId'),
                  initialValue: _ownerId,
                  decoration: const InputDecoration(labelText: 'Ownership entity'),
                  items: _ownersFor(_propertyId)
                      .map((owner) => DropdownMenuItem(
                            value: owner.id,
                            child: Text(owner.name),
                          ))
                      .toList(),
                  onChanged: (value) => _ownerId = value!,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Expense date'),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(_date)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _date,
                    );
                    if (selected != null) setState(() => _date = selected);
                  },
                ),
                TextFormField(
                  controller: _supplier,
                  decoration: const InputDecoration(labelText: 'Supplier (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: expenseCategories
                      .map((category) => DropdownMenuItem(
                            value: category.code,
                            child: Text(category.label),
                          ))
                      .toList(),
                  onChanged: (value) => _category = value!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Total amount (£)'),
                  validator: (value) {
                    try {
                      parsePoundsToPence(value ?? '');
                      return null;
                    } on FormatException catch (error) {
                      return error.message;
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _vatTreatment,
                  decoration: const InputDecoration(labelText: 'VAT treatment'),
                  items: const [
                    DropdownMenuItem(value: 'not_specified', child: Text('Not specified')),
                    DropdownMenuItem(value: 'included', child: Text('VAT included')),
                    DropdownMenuItem(value: 'excluded', child: Text('VAT excluded')),
                  ],
                  onChanged: (value) => _vatTreatment = value!,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vat,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      const InputDecoration(labelText: 'VAT amount (optional)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentStatus,
                  decoration: const InputDecoration(labelText: 'Payment status'),
                  items: const [
                    DropdownMenuItem(value: 'paid', child: Text('Paid')),
                    DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                    DropdownMenuItem(value: 'reimbursed', child: Text('Reimbursed')),
                  ],
                  onChanged: (value) => _paymentStatus = value!,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  key: ValueKey('compliance-$_propertyId-${_compliance.length}'),
                  initialValue: _complianceId,
                  decoration: const InputDecoration(
                    labelText: 'Compliance record (optional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Not linked'),
                    ),
                    ..._compliance.map((record) {
                      final requirement = record['compliance_requirement_types']
                          as Map<String, dynamic>;
                      final reference = record['reference_number'] as String?;
                      return DropdownMenuItem<String?>(
                        value: record['id'] as String,
                        child: Text(
                          '${requirement['name']}'
                          '${reference == null ? '' : ' · $reference'}',
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) => _complianceId = value,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save expense'),
        ),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Row(
            children: [
              Expanded(child: Text(text)),
              if (action != null) action!,
            ],
          ),
        ),
      );
}
