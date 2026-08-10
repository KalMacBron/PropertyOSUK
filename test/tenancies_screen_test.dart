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

Widget appForRole(String role) => ProviderScope(
      overrides: [
        organisationProvider.overrideWith(
          (_) async => OrganisationSummary(
            id: 'organisation',
            name: 'Test organisation',
            role: role,
          ),
        ),
        tenanciesProvider.overrideWith((_) async => [tenancy]),
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
    expect(find.byTooltip('Edit tenancy'), findsOneWidget);
    expect(find.byTooltip('End tenancy'), findsOneWidget);
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
