import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/compliance/application/compliance_providers.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/expenses/application/expense_providers.dart';
import 'package:property_os/features/maintenance/application/maintenance_providers.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';
import 'package:property_os/features/properties/presentation/properties_screen.dart';
import 'package:property_os/features/property_dashboard/presentation/property_dashboard_screen.dart';
import 'package:property_os/features/tasks/application/task_providers.dart';
import 'package:property_os/features/tenancies/application/tenancy_providers.dart';
import 'package:property_os/features/timeline/application/timeline_providers.dart';

const property = <String, dynamic>{
  'id': 'property',
  'display_name': 'Oak House',
  'address_line_1': '1 Oak Road',
  'town_or_city': 'London',
  'postcode': 'AA1 1AA',
  'property_type': 'House',
  'bedrooms': 3,
  'status': 'active',
  'property_ownerships': <dynamic>[],
};

void main() {
  testWidgets('property row opens its dashboard route', (tester) async {
    final router = GoRouter(
      initialLocation: '/properties',
      routes: [
        GoRoute(
          path: '/properties',
          builder: (_, __) => const PropertiesScreen(),
        ),
        GoRoute(
          path: '/properties/:propertyId',
          builder: (_, state) => Text(
            'Dashboard ${state.pathParameters['propertyId']}',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationProvider.overrideWith(
            (_) async => const OrganisationSummary(
              id: 'organisation',
              name: 'Test organisation',
              role: 'member',
            ),
          ),
          propertiesProvider.overrideWith((_) async => [property]),
        ],
        child: MaterialApp.router(
          theme: buildPropertyOsTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Oak House'));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard property'), findsOneWidget);
  });

  testWidgets('viewer sees property summaries without create actions',
      (tester) async {
    const requirement = ComplianceRequirement(
      id: 'gas',
      code: 'gas_safety',
      name: 'Gas safety',
      description: '',
      defaultWarningDays: 45,
    );
    final router = GoRouter(
      initialLocation: '/properties/property',
      routes: [
        GoRoute(
          path: '/properties',
          builder: (_, __) => const Text('Properties'),
        ),
        GoRoute(
          path: '/properties/:propertyId',
          builder: (_, state) => PropertyDashboardScreen(
            propertyId: state.pathParameters['propertyId']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.binding.setSurfaceSize(const Size(1400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationProvider.overrideWith(
            (_) async => const OrganisationSummary(
              id: 'organisation',
              name: 'Test organisation',
              role: 'viewer',
            ),
          ),
          propertiesProvider.overrideWith((_) async => [property]),
          complianceRequirementsProvider.overrideWith(
            (_) async => [requirement],
          ),
          compliancePortfolioProvider.overrideWith(
            (_) async => const [
              PropertyCompliance(
                id: 'property',
                name: 'Oak House',
                address: '1 Oak Road',
                postcode: 'AA1 1AA',
                records: [],
              ),
            ],
          ),
          tasksProvider.overrideWith((_) async => []),
          expensesProvider.overrideWith((_) async => []),
          maintenanceIssuesProvider.overrideWith((_) async => []),
          tenanciesProvider.overrideWith((_) async => []),
          propertyTimelineProvider('property').overrideWith((_) async => []),
        ],
        child: MaterialApp.router(
          theme: buildPropertyOsTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Oak House'), findsOneWidget);
    expect(find.text('Property overview'), findsOneWidget);
    expect(find.text('NOT RECORDED'), findsOneWidget);
    expect(find.text('Add expense'), findsNothing);
    expect(find.text('Create task'), findsNothing);
    expect(find.text('Add tenancy'), findsNothing);
    expect(find.text('Report maintenance'), findsNothing);
  });

  testWidgets('unknown property is safely unavailable', (tester) async {
    final router = GoRouter(
      initialLocation: '/properties/missing',
      routes: [
        GoRoute(
            path: '/properties', builder: (_, __) => const Text('Properties')),
        GoRoute(
          path: '/properties/:propertyId',
          builder: (_, state) => PropertyDashboardScreen(
            propertyId: state.pathParameters['propertyId']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [propertiesProvider.overrideWith((_) async => [])],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Property not found'), findsOneWidget);
  });
}
