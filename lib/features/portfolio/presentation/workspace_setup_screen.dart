import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';

class WorkspaceSetupScreen extends ConsumerStatefulWidget {
  const WorkspaceSetupScreen({super.key});
  @override
  ConsumerState<WorkspaceSetupScreen> createState() =>
      _WorkspaceSetupScreenState();
}

class _WorkspaceSetupScreenState extends ConsumerState<WorkspaceSetupScreen> {
  final _name = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(portfolioRepositoryProvider)
          .createOrganisation(_name.text);
      ref.invalidate(organisationProvider);
    } catch (error) {
      setState(
        () => _error = 'We could not create your workspace. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SizedBox(
        width: 480,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Set up PropertyOS',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Create the private workspace that will hold your portfolio.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Workspace name',
                    hintText: 'Horvath Property Portfolio',
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: Text(_saving ? 'Creating…' : 'Create workspace'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
