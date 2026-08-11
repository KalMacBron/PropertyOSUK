import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/maintenance/application/maintenance_providers.dart';
import 'package:property_os/features/maintenance/domain/maintenance_models.dart';
import 'package:property_os/features/maintenance/presentation/maintenance_screen.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';
import 'package:property_os/features/tasks/domain/task_models.dart';

void main() {
  testWidgets('viewer can inspect maintenance but sees no mutation actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationProvider.overrideWith(
            (_) async => const OrganisationSummary(
              id: 'organisation',
              name: 'Portfolio',
              role: 'viewer',
            ),
          ),
          maintenanceIssuesProvider.overrideWith(
            (_) async => [_issue('issue')],
          ),
        ],
        child: MaterialApp(
          theme: buildPropertyOsTheme(),
          home: const Scaffold(body: MaintenanceScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boiler pressure loss'), findsOneWidget);
    expect(find.text('VIEW ONLY'), findsOneWidget);
    expect(find.text('Report issue'), findsNothing);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Change status'), findsNothing);
  });

  testWidgets('property quick action opens a preselected issue form', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationProvider.overrideWith(
            (_) async => const OrganisationSummary(
              id: 'organisation',
              name: 'Portfolio',
              role: 'member',
            ),
          ),
          maintenanceIssuesProvider.overrideWith((_) async => []),
          maintenanceContractorsProvider.overrideWith((_) async => []),
          propertiesProvider.overrideWith(
            (_) async => [
              {
                'id': 'property',
                'display_name': 'Oak House',
                'address_line_1': '1 Oak Road',
              },
            ],
          ),
        ],
        child: MaterialApp(
          theme: buildPropertyOsTheme(),
          home: const Scaffold(
            body: MaintenanceScreen(
              initialPropertyId: 'property',
              openCreate: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Report maintenance issue'), findsOneWidget);
    final propertyField = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).first,
    );
    expect(propertyField.initialValue, 'property');
  });

  testWidgets('unknown issue is safely unavailable', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationProvider.overrideWith(
            (_) async => const OrganisationSummary(
              id: 'organisation',
              name: 'Portfolio',
              role: 'member',
            ),
          ),
          maintenanceIssuesProvider.overrideWith((_) async => []),
        ],
        child: MaterialApp(
          theme: buildPropertyOsTheme(),
          home: const Scaffold(
            body: MaintenanceScreen(initialIssueId: 'missing'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Maintenance issue unavailable'), findsOneWidget);
  });
}

MaintenanceIssue _issue(String id) => MaintenanceIssue(
      id: id,
      organisationId: 'organisation',
      propertyId: 'property',
      propertyName: 'Oak House',
      title: 'Boiler pressure loss',
      priority: TaskPriority.urgent,
      state: MaintenanceState.reported,
      reportedAt: DateTime(2026, 8, 11),
      targetDate: DateTime(2026, 8, 13),
      createdAt: DateTime(2026, 8, 11),
      updatedAt: DateTime(2026, 8, 11),
    );
