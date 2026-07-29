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
  String? _ownerId;
  String? _category;
  String? _paymentStatus;
  DateTime? _from;
  DateTime? _to;
  bool _openedInitialDialog = false;

  ExpenseFilters get _filters => ExpenseFilters(
        propertyId: _propertyId,
        ownerId: _ownerId,
        category: _category,
        paymentStatus: _paymentStatus,
        from: _from,
        to: _to,
      );

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          '${DateFormat('dd/MM/yyyy').format(expense.expenseDate)} · '
          '${expense.propertyName}\n${expense.description}\n'
          '${pounds(expense.amountPence)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(expenseRepositoryProvider).deleteExpense(expense);
      refreshExpenses(ref);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The expense could not be deleted.')),
      );
    }
  }

  Future<void> _pickEvidence(PropertyExpense expense) async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
    );
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;
    final extension = file.extension?.toLowerCase();
    final mime = switch (extension) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
    try {
      await ref.read(expenseRepositoryProvider).uploadEvidence(
            expense: expense,
            file: EvidenceFile(name: file.name, mimeType: mime, bytes: file.bytes!),
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
    final url =
        await ref.read(expenseRepositoryProvider).evidenceUrl(evidence);
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  }

  Future<void> _removeEvidence(ExpenseEvidence evidence) async {
    await ref.read(expenseRepositoryProvider).deleteEvidence(evidence);
    refreshExpenses(ref);
  }

  Future<void> _export(List<PropertyExpense> expenses) async {
    final csv = csvForExpenses(expenses);
    final uri = Uri.dataFromString(
      csv,
      mimeType: 'text/csv',
      encoding: utf8,
    );
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
    final canDelete = const ['owner', 'admin']
        .contains(organisation.valueOrNull?.role);

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
              final filtered = allExpenses.where(_filters.matches).toList();
              return _ExpenseContent(
                properties: propertyItems,
                allExpenses: allExpenses,
                expenses: filtered,
                filters: _filters,
                canWrite: canWrite,
                canDelete: canDelete,
                onProperty: (value) => setState(() => _propertyId = value),
                onOwner: (value) => setState(() => _ownerId = value),
                onCategory: (value) => setState(() => _category = value),
                onPayment: (value) => setState(() => _paymentStatus = value),
                onFrom: (value) => setState(() => _from = value),
                onTo: (value) => setState(() => _to = value),
                onClear: () => setState(() {
                  _propertyId = null;
                  _ownerId = null;
                  _category = null;
                  _paymentStatus = null;
                  _from = null;
                  _to = null;
                }),
                onEdit: (expense) => _openForm(expense: expense),
                onDelete: _delete,
                onUpload: _pickEvidence,
                onViewEvidence: _viewEvidence,
                onRemoveEvidence: _removeEvidence,
                onExport: () => _export(filtered),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExpenseContent extends StatelessWidget {
  const _ExpenseContent({
    required this.properties,
    required this.allExpenses,
    required this.expenses,
    required this.filters,
    required this.canWrite,
    required this.canDelete,
    required this.onProperty,
    required this.onOwner,
    required this.onCategory,
    required this.onPayment,
    required this.onFrom,
    required this.onTo,
    required this.onClear,
    required this.onEdit,
    required this.onDelete,
    required this.onUpload,
    required this.onViewEvidence,
    required this.onRemoveEvidence,
    required this.onExport,
  });

  final List<ExpenseProperty> properties;
  final List<PropertyExpense> allExpenses;
  final List<PropertyExpense> expenses;
  final ExpenseFilters filters;
  final bool canWrite;
  final bool canDelete;
  final ValueChanged<String?> onProperty;
  final ValueChanged<String?> onOwner;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String?> onPayment;
  final ValueChanged<DateTime?> onFrom;
  final ValueChanged<DateTime?> onTo;
  final VoidCallback onClear;
  final ValueChanged<PropertyExpense> onEdit;
  final ValueChanged<PropertyExpense> onDelete;
  final ValueChanged<PropertyExpense> onUpload;
  final ValueChanged<ExpenseEvidence> onViewEvidence;
  final ValueChanged<ExpenseEvidence> onRemoveEvidence;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return const _Message('Add a property before recording expenses.');
    }
    final owners = <String, String>{};
    for (final property in properties) {
      for (final owner in property.owners) {
        owners[owner.id] = owner.name;
      }
    }
    final total = expenses.fold<int>(0, (sum, item) => sum + item.amountPence);
    final categoryTotals = <String, int>{};
    for (final expense in expenses) {
      categoryTotals.update(
        expense.category,
        (value) => value + expense.amountPence,
        ifAbsent: () => expense.amountPence,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Dropdown(
                  label: 'Property',
                  value: filters.propertyId,
                  allLabel: 'All properties',
                  values: {for (final p in properties) p.id: p.name},
                  onChanged: onProperty,
                ),
                _Dropdown(
                  label: 'Ownership entity',
                  value: filters.ownerId,
                  allLabel: 'All entities',
                  values: owners,
                  onChanged: onOwner,
                ),
                _Dropdown(
                  label: 'Category',
                  value: filters.category,
                  allLabel: 'All categories',
                  values: {
                    for (final category in expenseCategories)
                      category.code: category.label,
                  },
                  onChanged: onCategory,
                ),
                _Dropdown(
                  label: 'Payment status',
                  value: filters.paymentStatus,
                  allLabel: 'All statuses',
                  values: const {
                    'paid': 'Paid',
                    'unpaid': 'Unpaid',
                    'reimbursed': 'Reimbursed',
                  },
                  onChanged: onPayment,
                ),
                _DateFilter(label: 'From', value: filters.from, changed: onFrom),
                _DateFilter(label: 'To', value: filters.to, changed: onTo),
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Clear filters'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Summary(label: 'Total expenditure', value: pounds(total)),
            _Summary(label: 'Expenses', value: '${expenses.length}'),
            ...categoryTotals.entries.map(
              (entry) => _Summary(
                label: expenseCategoryLabel(entry.key),
                value: pounds(entry.value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: expenses.isEmpty ? null : onExport,
            icon: const Icon(Icons.download_outlined),
            label: const Text('Export filtered CSV'),
          ),
        ),
        const SizedBox(height: 12),
        if (expenses.isEmpty)
          const _Message('No expenses match these filters.')
        else
          ...expenses.map(
            (expense) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ExpansionTile(
                  leading: CircleAvatar(
                    child: Text('£', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  title: Text(
                    '${expense.description} · ${pounds(expense.amountPence)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${expense.propertyName} · '
                    '${DateFormat('dd/MM/yyyy').format(expense.expenseDate)} · '
                    '${expenseCategoryLabel(expense.category)}',
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Owner: ${expense.ownershipEntityName}'),
                          Text('Status: ${expense.paymentStatus}'),
                          if (expense.supplier != null)
                            Text('Supplier: ${expense.supplier}'),
                          if (expense.complianceRequirement != null)
                            Text(
                              'Compliance: ${expense.complianceRequirement}',
                            ),
                          if (expense.evidence == null && canWrite)
                            TextButton.icon(
                              onPressed: () => onUpload(expense),
                              icon: const Icon(Icons.attach_file),
                              label: const Text('Add evidence'),
                            ),
                          if (expense.evidence != null) ...[
                            TextButton.icon(
                              onPressed: () =>
                                  onViewEvidence(expense.evidence!),
                              icon: const Icon(Icons.open_in_new),
                              label: Text(expense.evidence!.filename),
                            ),
                            if (canDelete)
                              TextButton(
                                onPressed: () =>
                                    onRemoveEvidence(expense.evidence!),
                                child: const Text('Remove evidence'),
                              ),
                          ],
                          if (canWrite)
                            TextButton(
                              onPressed: () => onEdit(expense),
                              child: const Text('Edit'),
                            ),
                          if (canDelete)
                            TextButton(
                              onPressed: () => onDelete(expense),
                              child: const Text('Delete'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
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
  }
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
  late String _propertyId =
      widget.expense?.propertyId ??
      widget.initialPropertyId ??
      widget.properties.first.id;
  late String _ownerId = widget.expense?.ownershipEntityId ??
      _ownersFor(widget.expense?.propertyId ??
              widget.initialPropertyId ??
              widget.properties.first.id)
          .first
          .id;
  late DateTime _date = widget.expense?.expenseDate ?? DateTime.now();
  late String _category = widget.expense?.category ??
      (widget.initialComplianceRecordId == null
          ? 'repairs_maintenance'
          : 'compliance_certificates');
  late String _vatTreatment =
      widget.expense?.vatTreatment ?? 'not_specified';
  late String _paymentStatus = widget.expense?.paymentStatus ?? 'paid';
  late String? _complianceId =
      widget.expense?.complianceRecordId ?? widget.initialComplianceRecordId;
  late final _supplier =
      TextEditingController(text: widget.expense?.supplier);
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
      final vat = _vat.text.trim().isEmpty ? null : parsePoundsToPence(_vat.text);
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
  Widget build(BuildContext context) => AlertDialog(
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
                    decoration:
                        const InputDecoration(labelText: 'Ownership entity'),
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
                    decoration:
                        const InputDecoration(labelText: 'Supplier (optional)'),
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        const InputDecoration(labelText: 'Total amount (£)'),
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
                    decoration:
                        const InputDecoration(labelText: 'VAT treatment'),
                    items: const [
                      DropdownMenuItem(
                        value: 'not_specified',
                        child: Text('Not specified'),
                      ),
                      DropdownMenuItem(
                        value: 'included',
                        child: Text('VAT included'),
                      ),
                      DropdownMenuItem(
                        value: 'excluded',
                        child: Text('VAT excluded'),
                      ),
                    ],
                    onChanged: (value) => _vatTreatment = value!,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _vat,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        const InputDecoration(labelText: 'VAT amount (optional)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _paymentStatus,
                    decoration:
                        const InputDecoration(labelText: 'Payment status'),
                    items: const [
                      DropdownMenuItem(value: 'paid', child: Text('Paid')),
                      DropdownMenuItem(value: 'unpaid', child: Text('Unpaid')),
                      DropdownMenuItem(
                        value: 'reimbursed',
                        child: Text('Reimbursed'),
                      ),
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
                    decoration:
                        const InputDecoration(labelText: 'Notes (optional)'),
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

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.allLabel,
    required this.values,
    required this.onChanged,
  });
  final String label;
  final String? value;
  final String allLabel;
  final Map<String, String> values;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 220,
        child: DropdownButtonFormField<String?>(
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(allLabel)),
            ...values.entries.map((entry) => DropdownMenuItem<String?>(
                  value: entry.key,
                  child: Text(entry.value, overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: onChanged,
        ),
      );
}

class _DateFilter extends StatelessWidget {
  const _DateFilter({
    required this.label,
    required this.value,
    required this.changed,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> changed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () async {
          final selected = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            initialDate: value ?? DateTime.now(),
          );
          if (selected != null) changed(selected);
        },
        icon: const Icon(Icons.date_range_outlined),
        label: Text(
          value == null ? label : '$label ${DateFormat('dd/MM/yy').format(value!)}',
        ),
      );
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
