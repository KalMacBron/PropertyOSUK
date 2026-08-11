import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/maintenance/application/maintenance_providers.dart';
import 'package:property_os/features/maintenance/domain/maintenance_models.dart';
import 'package:property_os/features/maintenance/presentation/contractor_directory_screen.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

void main() {
  testWidgets('viewer sees contractor details without mutation controls', (
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
          contractorDirectoryProvider.overrideWith(
            (_) async => const [
              MaintenanceContractor(
                id: 'contractor',
                organisationId: 'organisation',
                name: 'Safe Heating Ltd',
                trade: 'Heating',
                email: 'engineer@example.test',
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: buildPropertyOsTheme(),
          home: const Scaffold(body: ContractorDirectoryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Safe Heating Ltd'), findsOneWidget);
    expect(find.textContaining('engineer@example.test'), findsOneWidget);
    expect(find.text('VIEW ONLY'), findsOneWidget);
    expect(find.text('Add contractor'), findsNothing);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('authorised user can open contractor editor', (tester) async {
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
          contractorDirectoryProvider.overrideWith((_) async => []),
        ],
        child: MaterialApp(
          theme: buildPropertyOsTheme(),
          home: const Scaffold(body: ContractorDirectoryScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add contractor'));
    await tester.pumpAndSettle();

    expect(find.text('Contractor or business name'), findsOneWidget);
    expect(find.text('Trade (optional)'), findsOneWidget);
    expect(find.text('Telephone (optional)'), findsOneWidget);
  });
}
