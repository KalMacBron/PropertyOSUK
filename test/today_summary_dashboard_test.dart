import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/today/application/today_providers.dart';
import 'package:property_os/features/today/domain/portfolio_summary.dart';
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
}
