import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/tasks/application/task_providers.dart';
import 'package:property_os/features/tasks/domain/task_models.dart';
import 'package:property_os/features/timeline/application/timeline_providers.dart';
import 'package:property_os/features/today/application/today_providers.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({this.initialFilter, super.key});

  final String? initialFilter;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  late TaskFilter _filter;
  TaskPriority? _priority;
  String? _busyTaskId;

  @override
  void initState() {
    super.initState();
    _filter = TaskFilter.values.firstWhere(
      (filter) => filter.name == widget.initialFilter,
      orElse: () => TaskFilter.all,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    return ColoredBox(
      color: PropertyOsColours.workspace,
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(tasksProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            _Header(onCreate: _showCreateTask),
            const SizedBox(height: 24),
            tasks.when(
              data: (items) => _buildContent(items),
              loading: () => const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ErrorPanel(
                message: 'Tasks could not be loaded.',
                onRetry: () => ref.invalidate(tasksProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<PortfolioTask> tasks) {
    final counts = {
      for (final filter in TaskFilter.values)
        filter: _applyFilter(tasks, filter, null).length,
    };
    final visible = _applyFilter(tasks, _filter, _priority);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final filter in TaskFilter.values)
              _SummaryCard(
                label: filter.label,
                count: counts[filter]!,
                selected: _filter == filter,
                onTap: () => _selectFilter(filter),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Text('${visible.length} tasks',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            DropdownButton<TaskPriority?>(
              value: _priority,
              hint: const Text('All priorities'),
              onChanged: (value) => setState(() => _priority = value),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('All priorities')),
                for (final priority in TaskPriority.values)
                  DropdownMenuItem(
                      value: priority, child: Text(priority.label)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          const _EmptyPanel()
        else
          for (final task in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskCard(
                task: task,
                busy: _busyTaskId == task.id,
                onEdit: () => _showTaskDialog(task),
                onComplete: task.isOpen
                    ? () => _transition(task, TaskState.completed)
                    : null,
                onCancel: task.isOpen
                    ? () => _transition(task, TaskState.cancelled)
                    : null,
                onReopen: task.state == TaskState.completed ||
                        task.state == TaskState.cancelled
                    ? () => _transition(task, TaskState.open)
                    : null,
                onOpenSource: () => _openSource(task),
              ),
            ),
      ],
    );
  }

  List<PortfolioTask> _applyFilter(
    List<PortfolioTask> tasks,
    TaskFilter filter,
    TaskPriority? priority,
  ) =>
      tasks.where((task) {
        if (priority != null && task.priority != priority) return false;
        return switch (filter) {
          TaskFilter.all => true,
          TaskFilter.overdue => task.isOverdue,
          TaskFilter.upcoming => task.isOpen && !task.isOverdue,
          TaskFilter.completed => task.state == TaskState.completed,
          TaskFilter.cancelled => task.state == TaskState.cancelled,
        };
      }).toList();

  void _selectFilter(TaskFilter filter) {
    setState(() => _filter = filter);
    final uri =
        filter == TaskFilter.all ? '/tasks' : '/tasks?filter=${filter.name}';
    context.go(uri);
  }

  Future<void> _transition(PortfolioTask task, TaskState state) async {
    setState(() => _busyTaskId = task.id);
    try {
      await ref.read(taskRepositoryProvider).transitionTask(task.id, state);
      ref.invalidate(tasksProvider);
      ref.invalidate(todayActionsProvider);
      if (task.propertyId != null) {
        ref.invalidate(propertyTimelineProvider(task.propertyId!));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${task.title} ${state == TaskState.open ? 'reopened' : state.label.toLowerCase()}')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('The task could not be updated. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyTaskId = null);
    }
  }

  void _openSource(PortfolioTask task) {
    if (task.complianceRecordId != null &&
        task.propertyId != null &&
        task.requirementTypeId != null) {
      context.go(
        '/compliance-record/${task.propertyId}/${task.requirementTypeId}',
      );
    } else {
      context.go('/properties?propertyId=${task.propertyId ?? ''}');
    }
  }

  Future<void> _showCreateTask() => _showTaskDialog(null);

  Future<void> _showTaskDialog(PortfolioTask? task) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TaskDialog(task: task),
    );
    if (saved == true) {
      ref.invalidate(tasksProvider);
      ref.invalidate(todayActionsProvider);
      if (task?.propertyId != null) {
        ref.invalidate(propertyTimelineProvider(task!.propertyId!));
      }
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 16,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tasks', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 6),
              const Text('Plan and track actions across every property.'),
            ],
          ),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('New task'),
          ),
        ],
      );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color:
                  selected ? PropertyOsColours.amber : PropertyOsColours.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text('$count', style: Theme.of(context).textTheme.headlineMedium),
            ],
          ),
        ),
      );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.busy,
    required this.onEdit,
    required this.onComplete,
    required this.onCancel,
    required this.onReopen,
    required this.onOpenSource,
  });
  final PortfolioTask task;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback? onComplete;
  final VoidCallback? onCancel;
  final VoidCallback? onReopen;
  final VoidCallback onOpenSource;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: PropertyOsColours.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 5),
                      Text(task.propertyName ?? 'Portfolio task'),
                    ],
                  ),
                ),
                _Badge(
                    label: task.priority.label,
                    urgent: task.priority == TaskPriority.urgent),
                const SizedBox(width: 8),
                _Badge(label: task.state.label),
              ],
            ),
            if (task.description?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(task.description!),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(task.dueDate == null
                    ? 'No due date'
                    : 'Due ${_formatDate(task.dueDate!)}'),
                TextButton(
                    onPressed: onOpenSource, child: const Text('Open source')),
                OutlinedButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                if (busy)
                  const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                if (!busy && onComplete != null)
                  FilledButton(
                      onPressed: onComplete, child: const Text('Complete')),
                if (!busy && onCancel != null)
                  OutlinedButton(
                      onPressed: onCancel, child: const Text('Cancel')),
                if (!busy && onReopen != null)
                  OutlinedButton(
                      onPressed: onReopen, child: const Text('Reopen')),
              ],
            ),
          ],
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.urgent = false});
  final String label;
  final bool urgent;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        color: urgent ? const Color(0xFFFDE8E8) : PropertyOsColours.workspace,
        child: Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class _TaskDialog extends ConsumerStatefulWidget {
  const _TaskDialog({this.task});

  final PortfolioTask? task;

  @override
  ConsumerState<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends ConsumerState<_TaskDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String? _propertyId;
  late TaskPriority _priority;
  late DateTime? _dueDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title);
    _description = TextEditingController(text: task?.description);
    _propertyId = task?.propertyId;
    _priority = task?.priority ?? TaskPriority.medium;
    _dueDate = task?.dueDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final properties = ref.watch(propertiesProvider);
    return AlertDialog(
      title: Text(widget.task == null ? 'New task' : 'Edit task'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Task title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a task title'
                    : null,
              ),
              const SizedBox(height: 14),
              properties.when(
                data: (items) => DropdownButtonFormField<String>(
                  initialValue: _propertyId,
                  decoration: const InputDecoration(labelText: 'Property'),
                  items: [
                    for (final item in items)
                      DropdownMenuItem(
                        value: item['id'] as String,
                        child: Text(item['address_line_1'] as String),
                      ),
                  ],
                  onChanged: (value) => setState(() => _propertyId = value),
                  validator: (value) =>
                      value == null ? 'Choose a property' : null,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Properties could not be loaded.'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  for (final priority in TaskPriority.values)
                    DropdownMenuItem(
                        value: priority, child: Text(priority.label)),
                ],
                onChanged: (value) =>
                    setState(() => _priority = value ?? TaskPriority.medium),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _description,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
                maxLines: 3,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                      child: Text(_dueDate == null
                          ? 'No due date'
                          : 'Due ${_formatDate(_dueDate!)}')),
                  TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: const Text('Choose date'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving
                ? 'Saving…'
                : widget.task == null
                    ? 'Create task'
                    : 'Save changes')),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date != null) setState(() => _dueDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final organisation = await ref.read(organisationProvider.future);
    if (organisation == null) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(taskRepositoryProvider);
      if (widget.task == null) {
        await repository.createTask(
          CreateTaskInput(
            organisationId: organisation.id,
            propertyId: _propertyId!,
            title: _title.text.trim(),
            description: _description.text.trim(),
            priority: _priority,
            dueDate: _dueDate,
          ),
        );
      } else {
        await repository.updateTask(
          UpdateTaskInput(
            taskId: widget.task!.id,
            propertyId: _propertyId!,
            title: _title.text.trim(),
            description: _description.text.trim(),
            priority: _priority,
            dueDate: _dueDate,
          ),
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.task == null
              ? 'The task could not be created.'
              : 'The task could not be updated.'),
        ));
        setState(() => _saving = false);
      }
    }
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(40),
        color: Colors.white,
        child: const Column(
          children: [
            Icon(Icons.task_alt, size: 36),
            SizedBox(height: 12),
            Text('No tasks match this view.'),
          ],
        ),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          children: [
            Text(message),
            TextButton(onPressed: onRetry, child: const Text('Try again'))
          ],
        ),
      );
}

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';
