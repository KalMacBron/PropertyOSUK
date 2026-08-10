import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/compliance/application/compliance_providers.dart';
import 'package:property_os/features/compliance/domain/compliance_models.dart';
import 'package:property_os/features/compliance/presentation/compliance_register_screen.dart';

void main() {
  testWidgets('query status filters the compliance register and can be cleared',
      (tester) async {
    const gas = ComplianceRequirement(
      id: 'gas',
      code: 'gas_safety',
      name: 'Gas safety',
      description: '',
      defaultWarningDays: 45,
    );
    const epc = ComplianceRequirement(
      id: 'epc',
      code: 'epc',
      name: 'EPC',
      description: '',
      defaultWarningDays: 30,
    );
    final portfolio = [
      PropertyCompliance(
        id: 'property-1',
        name: 'Oak House',
        address: '1 Oak Road',
        postcode: 'AA1 1AA',
        records: [
          ComplianceRecord(
            id: 'gas-record',
            propertyId: 'property-1',
            requirementTypeId: 'gas',
            expiryDate: DateTime(2030, 1, 1),
          ),
        ],
      ),
    ];
    final router = GoRouter(
      initialLocation: '/compliance?status=notRecorded',
      routes: [
        GoRoute(
          path: '/compliance',
          builder: (_, state) => ComplianceRegisterScreen(
            initialStatus: state.uri.queryParameters['status'],
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          complianceRequirementsProvider.overrideWith((_) async => [gas, epc]),
          compliancePortfolioProvider.overrideWith((_) async => portfolio),
        ],
        child: MaterialApp.router(
          theme: buildPropertyOsTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Filtered to not recorded items'), findsOneWidget);
    expect(find.text('EPC'), findsOneWidget);
    expect(find.text('Gas safety'), findsNothing);

    await tester.tap(find.text('Show full register'));
    await tester.pumpAndSettle();
    expect(find.text('Gas safety'), findsOneWidget);
    expect(find.text('EPC'), findsOneWidget);
  });
}
