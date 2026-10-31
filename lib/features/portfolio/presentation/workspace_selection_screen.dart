import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

class WorkspaceSelectionScreen extends ConsumerStatefulWidget {
  const WorkspaceSelectionScreen({
    required this.organisations,
    super.key,
  });

  final List<OrganisationSummary> organisations;

  @override
  ConsumerState<WorkspaceSelectionScreen> createState() =>
      _WorkspaceSelectionScreenState();
}

class _WorkspaceSelectionScreenState
    extends ConsumerState<WorkspaceSelectionScreen> {
  String? _selectingId;
  String? _error;

  Future<void> _select(OrganisationSummary organisation) async {
    setState(() {
      _selectingId = organisation.id;
      _error = null;
    });
    try {
      await selectOrganisation(ref, organisation);
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectingId = null;
          _error = 'PropertyOS could not open that workspace.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PropertyOsColours.workspace,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SuiteBrand(compact: true),
                      const SizedBox(height: 28),
                      const Text(
                        'Choose your workspace',
                        style: TextStyle(
                          fontSize: 32,
                          color: PropertyOsColours.deepNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Your access and portfolio data are kept separate for each organisation.',
                        style: TextStyle(color: PropertyOsColours.muted),
                      ),
                      const SizedBox(height: 24),
                      for (final organisation in widget.organisations)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: OutlinedButton(
                            onPressed: _selectingId == null
                                ? () => _select(organisation)
                                : null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(18),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.business_outlined),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        organisation.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        organisation.role.toUpperCase(),
                                        style: const TextStyle(
                                          color: PropertyOsColours.muted,
                                          fontSize: 11,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_selectingId == organisation.id)
                                  const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                else
                                  const Icon(Icons.arrow_forward),
                              ],
                            ),
                          ),
                        ),
                      if (_error != null)
                        Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
