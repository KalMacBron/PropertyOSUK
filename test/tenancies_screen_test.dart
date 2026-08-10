import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';
import 'package:property_os/features/tenancies/application/tenancy_providers.dart';
import 'package:property_os/features/tenancies/domain/tenancy_models.dart';
import 'package:property_os/features/tenancies/presentation/tenancies_screen.dart';

final tenancy = PortfolioTenancy(
  id: 'tenancy',
  organisationId: 'organisation',
  propertyId: 'property',
  propertyName: 'Oak House',
  tenantDisplayName: 'A. Tenant',
  startDate: DateTime(2026, 1, 1),
  fixedTermEndDate: DateTime(2027, 1, 1),
  monthlyRentPence: 125000,
  rentDueDay: 5,
  status: 'active',
);

final historicalTenancy = PortfolioTenancy(
  id: 'historical-tenancy',
  organisationId: 'organisation',
  propertyId: 'property',
  propertyName: 'Oak House',
  tenantDisplayName: 'B. Tenant',
  startDate: DateTime(2025, 1, 1),
  actualEndDate: DateTime(2025, 12, 31),
  status: 'archived',
);

final upcomingTenancy = PortfolioTenancy(
  id: 'upcoming-tenancy',
  organisationId: 'organisation',
  propertyId: 'property',
  propertyName: 'Oak House',
  tenantDisplayName: 'C. Tenant',
  startDate: DateTime(2030, 1, 1),
  status: 'active',
);

Widget appForRole(String role) => ProviderScope(
      overrides: [
        organisationProvider.overrideWith(
          (_) async => OrganisationSummary(
            id: 'organisation',
            name: 'Test organisation',
            role: role,
          ),
        ),
        tenanciesProvider.overrideWith(
          (_) async => [tenancy, upcomingTenancy, historicalTenancy],
        ),
        propertiesProvider.overrideWith(
          (_) async => [
            {
              'id': 'property',
              'display_name': 'Oak House',
              'address_line_1': '1 Test Street',
              'postcode': 'SW1A 1AA',
            },
          ],
        ),
      ],
      child: MaterialApp(
        theme: buildPropertyOsTheme(),
        home: const Scaffold(body: TenanciesScreen()),
      ),
    );

void main() {
  testWidgets('member sees tenancy write controls', (tester) async {
    await tester.pumpWidget(appForRole('member'));
    await tester.pumpAndSettle();

    expect(find.text('A. Tenant'), findsOneWidget);
    expect(find.text('Add tenancy'), findsOneWidget);
    expect(find.byTooltip('Edit tenancy'), findsNWidgets(3));
    expect(find.byTooltip('End tenancy'), findsNWidgets(2));
    expect(find.byTooltip('Reopen tenancy'), findsOneWidget);
  });

  testWidgets('historical tenancy row opens correction form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(appForRole('member'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('B. Tenant'));
    await tester.tap(find.text('B. Tenant'));
    await tester.pumpAndSettle();

    expect(find.text('Edit tenancy'), findsOneWidget);
    expect(find.text('Actual end date'), findsOneWidget);
  });

  testWidgets('viewer sees tenancy data without write controls',
      (tester) async {
    await tester.pumpWidget(appForRole('viewer'));
    await tester.pumpAndSettle();

    expect(find.text('A. Tenant'), findsOneWidget);
    expect(find.text('Add tenancy'), findsNothing);
    expect(find.byTooltip('Edit tenancy'), findsNothing);
    expect(find.byTooltip('End tenancy'), findsNothing);
  });
}
