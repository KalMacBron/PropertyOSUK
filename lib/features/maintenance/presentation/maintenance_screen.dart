import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/features/documents/domain/compliance_evidence.dart';
import 'package:property_os/features/maintenance/application/maintenance_providers.dart';
import 'package:property_os/features/maintenance/data/maintenance_repository.dart';
import 'package:property_os/features/maintenance/domain/maintenance_models.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';
import 'package:property_os/features/tasks/domain/task_models.dart';
import 'package:property_os/features/timeline/application/timeline_providers.dart';
import 'package:property_os/features/today/application/today_providers.dart';
import 'package:url_launcher/url_launcher.dart';

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({
    this.initialPropertyId,
    this.initialIssueId,
    this.openCreate = false,
    super.key,
  });

  final String? initialPropertyId;
  final String? initialIssueId;
  final bool openCreate;

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  MaintenanceFilter _filter = MaintenanceFilter.open;
  TaskPriority? _priority;
  final _search = TextEditingController();
  String? _busyIssueId;
  bool _openedInitial = false;
  bool _initialUnavailable = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final issues = ref.watch(maintenanceIssuesProvider);
    final organisation = ref.watch(organisationProvider);
    final canWrite = canWriteOrganisation(organisation.valueOrNull);
    if (!_openedInitial &&
        (widget.openCreate || widget.initialIssueId != null)) {
      _openedInitial = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (widget.openCreate) {
          await _editIssue(null);
        } else {
          final items = await ref.read(maintenanceIssuesProvider.future);
          final match = items.where((item) => item.id == widget.initialIssueId);
          if (!mounted) return;
          if (match.isEmpty) {
            setState(() => _initialUnavailable = true);
          } else {
            await _showDetails(match.single);
          }
        }
      });
    }
    return WorkspacePage(
      eyebrow: 'Property operations',
      title: 'Maintenance',
      subtitle:
          'Record and progress property issues from report to resolution.',
      action: canWrite
          ? FilledButton.icon(
              onPressed: () => _editIssue(null),
              icon: const Icon(Icons.add),
              label: const Text('Report issue'),
            )
          : const Chip(label: Text('VIEW ONLY')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Filters(
            selected: _filter,
            priority: _priority,
            search: _search,
            onFilter: (value) => setState(() => _filter = value),
            onPriority: (value) => setState(() => _priority = value),
            onSearch: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          issues.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => _ErrorPanel(
              onRetry: () => ref.invalidate(maintenanceIssuesProvider),
            ),
            data: (items) {
              if (_initialUnavailable) {
                return const SuiteEmptyState(
                  icon: Icons.lock_outline,
                  title: 'Maintenance issue unavailable',
                  message:
                      'This issue is unavailable in the active organisation.',
                );
              }
              final visible = filterMaintenanceIssues(
                items,
                _filter,
                propertyId: widget.initialPropertyId,
                priority: _priority,
                query: _search.text,
              );
              if (visible.isEmpty) {
                return const SuiteEmptyState(
                  icon: Icons.home_repair_service_outlined,
                  title: 'No maintenance issues in this view',
                  message: 'Change the filters or report a property issue.',
                );
              }
              return Column(
                children: [
                  for (final issue in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _IssueCard(
                        issue: issue,
                        busy: _busyIssueId == issue.id,
                        canWrite: canWrite,
                        onOpen: () => context.go('/maintenance/${issue.id}'),
                        onEdit: canWrite ? () => _editIssue(issue) : null,
                        onState: canWrite
                            ? (state) => _transition(issue, state)
                            : null,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _editIssue(MaintenanceIssue? issue) async {
    final organisation = await ref.read(organisationProvider.future);
    if (!canWriteOrganisation(organisation)) return;
    final properties = await ref.read(propertiesProvider.future);
    final contractors = await ref.read(maintenanceContractorsProvider.future);
    if (!mounted || organisation == null) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _IssueDialog(
        organisationId: organisation.id,
        properties: properties,
        contractors: contractors,
        onSave: (input) => ref.read(maintenanceRepositoryProvider).save(input),
        issue: issue,
        initialPropertyId: widget.initialPropertyId,
      ),
    );
    if (saved == true) _refresh(issue?.propertyId);
  }

  Future<void> _transition(
    MaintenanceIssue issue,
    MaintenanceState state,
  ) async {
    int? actualCost;
    String? completionNotes;
    if (state.isTerminal) {
      final result = await showDialog<({int? cost, String? notes})>(
        context: context,
        builder: (_) => _CompletionDialog(state: state, issue: issue),
      );
      if (result == null) return;
      actualCost = result.cost;
      completionNotes = result.notes;
    } else if (issue.state.isTerminal && state == MaintenanceState.reported) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reopen maintenance issue?'),
          content: const Text(
            'The issue will return to Reported. Earlier resolution history remains on the property timeline.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep closed'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Reopen'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    setState(() => _busyIssueId = issue.id);
    try {
      await ref.read(maintenanceRepositoryProvider).transition(
            issueId: issue.id,
            state: state,
            actualCostPence: actualCost,
            completionNotes: completionNotes,
          );
      _refresh(issue.propertyId);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('The maintenance issue could not be updated.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyIssueId = null);
    }
  }

  Future<void> _showDetails(MaintenanceIssue issue) async {
    final organisation = await ref.read(organisationProvider.future);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _DetailsDialog(
        issue: issue,
        canWrite: canWriteOrganisation(organisation),
        repository: ref.read(maintenanceRepositoryProvider),
        onChanged: () => _refresh(issue.propertyId),
      ),
    );
    if (mounted && widget.initialIssueId != null) context.go('/maintenance');
  }

  void _refresh([String? propertyId]) {
    ref.invalidate(maintenanceIssuesProvider);
    ref.invalidate(todayActionsProvider);
    if (propertyId != null) {
      ref.invalidate(propertyTimelineProvider(propertyId));
    }
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.selected,
    required this.priority,
    required this.search,
    required this.onFilter,
    required this.onPriority,
    required this.onSearch,
  });
  final MaintenanceFilter selected;
  final TaskPriority? priority;
  final TextEditingController search;
  final ValueChanged<MaintenanceFilter> onFilter;
  final ValueChanged<TaskPriority?> onPriority;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => SectionPanel(
        title: 'Maintenance register',
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final filter in MaintenanceFilter.values)
                ChoiceChip(
                  label: Text(filter.label),
                  selected: selected == filter,
                  onSelected: (_) => onFilter(filter),
                ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<TaskPriority?>(
                  isExpanded: true,
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All priorities')),
                    for (final item in TaskPriority.values)
                      DropdownMenuItem(value: item, child: Text(item.label)),
                  ],
                  onChanged: onPriority,
                ),
              ),
              SizedBox(
                width: 300,
                child: TextField(
                  controller: search,
                  onChanged: onSearch,
                  decoration: const InputDecoration(
                    labelText: 'Search title or property',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _IssueCard extends StatelessWidget {
  const _IssueCard({
    required this.issue,
    required this.busy,
    required this.canWrite,
    required this.onOpen,
    required this.onEdit,
    required this.onState,
  });
  final MaintenanceIssue issue;
  final bool busy;
  final bool canWrite;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final ValueChanged<MaintenanceState>? onState;

  @override
  Widget build(BuildContext context) => SectionPanel(
        title: issue.title,
        subtitle: '${issue.propertyName} · ${issue.priority.label} priority',
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  Chip(label: Text(issue.state.label)),
                  Text('Reported ${_date(issue.reportedAt)}'),
                  if (issue.targetDate != null)
                    Text('Target ${_date(issue.targetDate!)}'),
                  if (issue.contractorName != null)
                    Text('Contractor ${issue.contractorName}'),
                  if (issue.estimatedCostPence != null)
                    Text('Estimate ${_money(issue.estimatedCostPence!)}'),
                ],
              ),
              if (issue.description != null) ...[
                const SizedBox(height: 10),
                Text(issue.description!),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open issue'),
                  ),
                  if (onEdit != null)
                    TextButton.icon(
                      onPressed: busy ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  if (onState != null && !issue.state.isTerminal)
                    PopupMenuButton<MaintenanceState>(
                      enabled: !busy,
                      onSelected: onState,
                      itemBuilder: (_) => [
                        for (final state in MaintenanceState.values)
                          if (state != issue.state)
                            PopupMenuItem(
                                value: state, child: Text(state.label)),
                      ],
                      child: const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text('Change status'),
                      ),
                    ),
                  if (onState != null && issue.state.isTerminal)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => onState!(MaintenanceState.reported),
                      child: const Text('Reopen'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _IssueDialog extends StatefulWidget {
  const _IssueDialog({
    required this.organisationId,
    required this.properties,
    required this.contractors,
    required this.onSave,
    this.issue,
    this.initialPropertyId,
  });
  final String organisationId;
  final List<Map<String, dynamic>> properties;
  final List<MaintenanceContractor> contractors;
  final Future<String> Function(MaintenanceInput input) onSave;
  final MaintenanceIssue? issue;
  final String? initialPropertyId;

  @override
  State<_IssueDialog> createState() => _IssueDialogState();
}

class _IssueDialogState extends State<_IssueDialog> {
  final _key = GlobalKey<FormState>();
  late String _propertyId = widget.issue?.propertyId ??
      widget.initialPropertyId ??
      widget.properties.first['id'] as String;
  late String? _contractorId = widget.issue?.contractorId;
  late TaskPriority _priority = widget.issue?.priority ?? TaskPriority.medium;
  late DateTime _reportedDate = widget.issue?.reportedAt ?? DateTime.now();
  late DateTime? _targetDate = widget.issue?.targetDate;
  late final _title = TextEditingController(text: widget.issue?.title);
  late final _description =
      TextEditingController(text: widget.issue?.description);
  late final _estimate = TextEditingController(
    text: widget.issue?.estimatedCostPence == null
        ? ''
        : (widget.issue!.estimatedCostPence! / 100).toStringAsFixed(2),
  );
  late final _notes = TextEditingController(text: widget.issue?.notes);
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _estimate.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(MaintenanceInput(
        issueId: widget.issue?.id,
        organisationId: widget.organisationId,
        propertyId: _propertyId,
        contractorId: _contractorId,
        title: _title.text,
        description: _description.text,
        priority: _priority,
        reportedDate: _reportedDate,
        targetDate: _targetDate,
        estimatedCostPence: _optionalPence(_estimate.text),
        notes: _notes.text,
      ));
      if (mounted) Navigator.pop(context, true);
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('The maintenance issue could not be saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.issue == null
            ? 'Report maintenance issue'
            : 'Edit maintenance issue'),
        content: SizedBox(
          width: 650,
          child: Form(
            key: _key,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _propertyId,
                    decoration: const InputDecoration(labelText: 'Property'),
                    items: [
                      for (final property in widget.properties)
                        DropdownMenuItem(
                          value: property['id'] as String,
                          child: Text(_propertyName(property)),
                        ),
                    ],
                    onChanged: (value) => _propertyId = value!,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _title,
                    maxLength: 160,
                    decoration: const InputDecoration(labelText: 'Issue title'),
                    validator: (value) => value?.trim().isEmpty != false
                        ? 'Enter an issue title.'
                        : null,
                  ),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Description (optional)'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TaskPriority>(
                    initialValue: _priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: [
                      for (final item in TaskPriority.values)
                        DropdownMenuItem(value: item, child: Text(item.label)),
                    ],
                    onChanged: (value) => _priority = value!,
                  ),
                  const SizedBox(height: 12),
                  _DateRow(
                    label: 'Reported date',
                    value: _reportedDate,
                    onChanged: (value) {
                      if (value != null) setState(() => _reportedDate = value);
                    },
                  ),
                  _DateRow(
                    label: 'Target date (optional)',
                    value: _targetDate,
                    allowClear: true,
                    onChanged: (value) => setState(() => _targetDate = value),
                  ),
                  DropdownButtonFormField<String?>(
                    initialValue: _contractorId,
                    decoration: const InputDecoration(
                        labelText: 'Contractor (optional)'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Not assigned')),
                      for (final contractor in widget.contractors)
                        DropdownMenuItem(
                          value: contractor.id,
                          child: Text(
                              '${contractor.name}${contractor.trade == null ? '' : ' · ${contractor.trade}'}'),
                        ),
                    ],
                    onChanged: (value) => _contractorId = value,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _estimate,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Estimated cost (£, optional)'),
                    validator: (value) {
                      try {
                        _optionalPence(value ?? '');
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
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
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save issue')),
        ],
      );
}

class _CompletionDialog extends StatefulWidget {
  const _CompletionDialog({required this.state, required this.issue});
  final MaintenanceState state;
  final MaintenanceIssue issue;
  @override
  State<_CompletionDialog> createState() => _CompletionDialogState();
}

class _CompletionDialogState extends State<_CompletionDialog> {
  late final _cost = TextEditingController(
    text: widget.issue.actualCostPence == null
        ? ''
        : (widget.issue.actualCostPence! / 100).toStringAsFixed(2),
  );
  late final _notes = TextEditingController(text: widget.issue.completionNotes);
  @override
  void dispose() {
    _cost.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.state.label} maintenance issue'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _cost,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Actual cost (£, optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Completion notes (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              try {
                Navigator.pop(context,
                    (cost: _optionalPence(_cost.text), notes: _notes.text));
              } on FormatException catch (error) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(error.message)));
              }
            },
            child: Text(widget.state.label),
          ),
        ],
      );
}

class _DetailsDialog extends ConsumerStatefulWidget {
  const _DetailsDialog({
    required this.issue,
    required this.canWrite,
    required this.repository,
    required this.onChanged,
  });
  final MaintenanceIssue issue;
  final bool canWrite;
  final MaintenanceRepository repository;
  final VoidCallback onChanged;
  @override
  ConsumerState<_DetailsDialog> createState() => _DetailsDialogState();
}

class _DetailsDialogState extends ConsumerState<_DetailsDialog> {
  bool _uploading = false;

  Future<void> _upload() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = picked?.files.single;
    if (file?.bytes == null) return;
    setState(() => _uploading = true);
    try {
      await widget.repository.uploadEvidence(
        issue: widget.issue,
        file: EvidenceFile(
          name: file!.name,
          mimeType: _mimeType(file.extension),
          bytes: file.bytes!,
        ),
      );
      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The evidence could not be uploaded.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.issue.title),
        content: SizedBox(
          width: 680,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    '${widget.issue.propertyName} · ${widget.issue.state.label}'),
                if (widget.issue.description != null) ...[
                  const SizedBox(height: 12),
                  Text(widget.issue.description!),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    Text('Priority: ${widget.issue.priority.label}'),
                    Text('Reported: ${_date(widget.issue.reportedAt)}'),
                    if (widget.issue.targetDate != null)
                      Text('Target: ${_date(widget.issue.targetDate!)}'),
                    if (widget.issue.contractorName != null)
                      Text('Contractor: ${widget.issue.contractorName}'),
                    if (widget.issue.estimatedCostPence != null)
                      Text(
                        'Estimate: ${_money(widget.issue.estimatedCostPence!)}',
                      ),
                    if (widget.issue.actualCostPence != null)
                      Text('Actual: ${_money(widget.issue.actualCostPence!)}'),
                  ],
                ),
                if (widget.issue.notes != null) ...[
                  const SizedBox(height: 12),
                  Text('Notes: ${widget.issue.notes}'),
                ],
                if (widget.issue.completionNotes != null) ...[
                  const SizedBox(height: 8),
                  Text('Completion: ${widget.issue.completionNotes}'),
                ],
                const SizedBox(height: 20),
                Text('Supporting evidence',
                    style: Theme.of(context).textTheme.titleMedium),
                if (widget.issue.evidence.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No supporting evidence has been attached.'),
                  ),
                for (final evidence in widget.issue.evidence)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_file),
                    title: Text(evidence.originalFilename),
                    subtitle: Text(formatEvidenceSize(evidence.sizeBytes)),
                    trailing: const Icon(Icons.open_in_new),
                    onTap: () async {
                      final url = await widget.repository.evidenceUrl(evidence);
                      await launchUrl(Uri.parse(url));
                    },
                  ),
                if (widget.canWrite)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _upload,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(_uploading ? 'Uploading…' : 'Add evidence'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.go(
                              '/tasks?propertyId=${widget.issue.propertyId}&maintenanceIssueId=${widget.issue.id}&create=true');
                        },
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('Create linked task'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          context.go(
                              '/expenses?propertyId=${widget.issue.propertyId}&maintenanceIssueId=${widget.issue.id}&create=true');
                        },
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Record linked expense'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      );
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.allowClear = false,
  });
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool allowClear;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(value == null ? 'Not set' : _date(value!)),
        trailing: Wrap(
          children: [
            if (allowClear && value != null)
              IconButton(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.clear)),
            const Icon(Icons.calendar_today_outlined),
          ],
        ),
        onTap: () async {
          final selected = await showDatePicker(
            context: context,
            firstDate: DateTime(2000),
            lastDate: DateTime.now().add(const Duration(days: 3650)),
            initialDate: value ?? DateTime.now(),
          );
          if (selected != null) onChanged(selected);
        },
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => SectionPanel(
        title: 'Maintenance unavailable',
        child: ListTile(
          title: const Text('The maintenance register could not be loaded.'),
          trailing:
              TextButton(onPressed: onRetry, child: const Text('Try again')),
        ),
      );
}

String _propertyName(Map<String, dynamic> property) {
  final display = (property['display_name'] as String?)?.trim();
  return display?.isNotEmpty == true
      ? display!
      : property['address_line_1'] as String;
}

String _date(DateTime value) => DateFormat('dd/MM/yyyy').format(value);
String _money(int pence) =>
    NumberFormat.currency(locale: 'en_GB', symbol: '£').format(pence / 100);

int? _optionalPence(String value) {
  final cleaned = value.trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  final pounds = double.tryParse(cleaned);
  if (pounds == null || pounds < 0 || pounds.toStringAsFixed(2) != cleaned) {
    if (pounds != null && pounds >= 0 && cleaned == pounds.toString()) {
      return (pounds * 100).round();
    }
    throw const FormatException(
        'Enter a valid non-negative amount in pounds and pence.');
  }
  return (pounds * 100).round();
}

String _mimeType(String? extension) => switch (extension?.toLowerCase()) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => 'application/octet-stream',
    };
