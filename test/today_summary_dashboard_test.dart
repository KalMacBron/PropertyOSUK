import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/tasks/application/task_providers.dart';
import 'package:property_os/features/tasks/domain/task_models.dart';
import 'package:property_os/features/today/application/today_providers.dart';
import 'package:property_os/features/today/domain/portfolio_summary.dart';
import 'package:property_os/features/today/domain/today_action.dart';
import 'package:property_os/features/today/presentation/today_screen.dart';

void main() {
  test('portfolio summary counts every tracked property requirement', () {
    final requirements = [
      const ComplianceRequirement(
        id: 'gas',
        code: 'gas_safety',
        name: 'Gas safety',
        description: '',
        defaultWarningDays: 45,
      ),
      const ComplianceRequirement(
        id: 'epc',
        code: 'epc',
        name: 'EPC',
        description: '',
        defaultWarningDays: 30,
      ),
    ];
    final properties = [
      PropertyCompliance(
        id: 'property-1',
        name: 'Oak House',
        address: '1 Oak Road',
        postcode: 'AA1 1AA',
        records: [
          ComplianceRecord(
            id: 'record-1',
            propertyId: 'property-1',
            requirementTypeId: 'gas',
            expiryDate: DateTime(2026, 9, 1),
          ),
        ],
      ),
    ];

    final summary = buildPortfolioSummary(
      properties: properties,
      requirements: requirements,
      today: DateTime(2026, 8, 10),
    );

    expect(summary.propertyCount, 1);
    expect(summary.dueSoon, 1);
    expect(summary.notRecorded, 1);
    expect(summary.complianceChecks, 2);
  });

  testWidgets('not recorded tile opens the compliance workspace',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
        GoRoute(
          path: '/compliance',
          builder: (_, __) => const Scaffold(body: Text('Compliance target')),
        ),
        GoRoute(
          path: '/properties',
          builder: (_, __) => const Scaffold(body: Text('Properties target')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioSummaryProvider.overrideWith(
            (_) async => const PortfolioSummary(
              propertyCount: 2,
              compliant: 0,
              dueSoon: 0,
              overdue: 0,
              notRecorded: 10,
            ),
          ),
          todayActionsProvider.overrideWith((_) async => []),
          propertiesProvider.overrideWith((_) async => []),
          tasksProvider.overrideWith((_) async => []),
        ],
        child: MaterialApp.router(
          theme: buildPropertyOsTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10'), findsOneWidget);
    await tester.tap(find.text('NOT RECORDED'));
    await tester.pumpAndSettle();
    expect(find.text('Compliance target'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/compliance?status=notRecorded',
    );
  });

  testWidgets('overdue task summary opens the filtered Tasks workspace',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
        GoRoute(
          path: '/tasks',
          builder: (_, __) => const Scaffold(body: Text('Tasks target')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioSummaryProvider.overrideWith(
            (_) async => const PortfolioSummary(
              propertyCount: 1,
              compliant: 1,
              dueSoon: 0,
              overdue: 0,
              notRecorded: 0,
            ),
          ),
          todayActionsProvider.overrideWith((_) async => []),
          propertiesProvider.overrideWith((_) async => []),
          tasksProvider.overrideWith(
            (_) async => [
              PortfolioTask(
                id: 'task-1',
                organisationId: 'org-1',
                propertyId: 'property-1',
                propertyName: 'Oak House',
                title: 'Arrange inspection',
                priority: TaskPriority.high,
                state: TaskState.open,
                dueDate: DateTime.now().subtract(const Duration(days: 1)),
                sourceType: 'manual',
                createdAt: DateTime.now(),
              ),
            ],
          ),
        ],
        child: MaterialApp.router(
          theme: buildPropertyOsTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('OVERDUE TASKS'));
    await tester.pumpAndSettle();
    expect(find.text('Tasks target'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/tasks?filter=overdue',
    );
  });

  testWidgets('tenancy Today prompt opens the tenancy workspace',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
        GoRoute(
          path: '/tenancies',
          builder: (_, __) => const Scaffold(body: Text('Tenancy target')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioSummaryProvider.overrideWith(
            (_) async => const PortfolioSummary(
              propertyCount: 1,
              compliant: 0,
              dueSoon: 0,
              overdue: 0,
              notRecorded: 0,
            ),
          ),
          todayActionsProvider.overrideWith(
            (_) async => [
              TodayAction(
                sourceType: 'tenancy',
                sourceId: 'tenancy-1',
                propertyId: 'property-1',
                title: 'Review tenancy ending soon',
                reason: 'fixed_term_ending',
                priority: 'medium',
                dueDate: DateTime(2026, 9, 30),
              ),
            ],
          ),
          propertiesProvider.overrideWith(
            (_) async => [
              {
                'id': 'property-1',
                'display_name': 'Oak House',
                'address_line_1': '1 Oak Road',
              },
            ],
          ),
          tasksProvider.overrideWith((_) async => []),
        ],
        child: MaterialApp.router(
          theme: buildPropertyOsTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review tenancy ending soon'));
    await tester.pumpAndSettle();
    expect(find.text('Tenancy target'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/tenancies?tenancyId=tenancy-1',
    );
  });

  testWidgets('maintenance Today prompt opens the issue detail',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: '/today',
      routes: [
        GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
        GoRoute(
          path: '/maintenance/:issueId',
          builder: (_, state) => Scaffold(
            body: Text('Maintenance ${state.pathParameters['issueId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          portfolioSummaryProvider.overrideWith(
            (_) async => const PortfolioSummary(
              propertyCount: 1,
              compliant: 0,
              dueSoon: 0,
              overdue: 0,
              notRecorded: 0,
            ),
          ),
          todayActionsProvider.overrideWith(
            (_) async => const [
              TodayAction(
                sourceType: 'maintenance',
                sourceId: 'issue-1',
                propertyId: 'property-1',
                title: 'Urgent boiler repair',
                reason: 'open_reported',
                priority: 'urgent',
              ),
            ],
          ),
          propertiesProvider.overrideWith((_) async => const []),
          tasksProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp.router(
          theme: buildPropertyOsTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Urgent boiler repair'));
    await tester.pumpAndSettle();
    expect(find.text('Maintenance issue-1'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/maintenance/issue-1',
    );
  });
}
