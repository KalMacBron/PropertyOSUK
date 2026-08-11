import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/export/application/organisation_export_providers.dart';
import 'package:property_os/features/export/domain/organisation_export_models.dart';
import 'package:property_os/features/export/presentation/organisation_export_screen.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

void main() {
  testWidgets('viewer is denied the complete organisation export screen', (
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
        ],
        child: MaterialApp(
          theme: buildPropertyOsTheme(),
          home: const Scaffold(body: OrganisationExportScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Owner or admin access is required.'), findsOneWidget);
    expect(find.text('Download organisation JSON'), findsNothing);
  });

  testWidgets('owner sees structured export and safe document manifest', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationProvider.overrideWith(
            (_) async => const OrganisationSummary(
              id: 'organisation',
              name: 'Portfolio',
              role: 'owner',
            ),
          ),
          organisationExportDocumentsProvider.overrideWith(
            (_) async => [
              ExportDocument(
                id: 'document',
                propertyId: 'property',
                propertyName: 'Oak House',
                scope: 'compliance',
                documentType: 'compliance_evidence',
                originalFilename: 'gas-safety.pdf',
                mimeType: 'application/pdf',
                sizeBytes: 2048,
                createdAt: DateTime(2026, 8, 11),
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: buildPropertyOsTheme(),
          home: const Scaffold(body: OrganisationExportScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Download organisation JSON'), findsOneWidget);
    expect(find.text('gas-safety.pdf'), findsOneWidget);
    expect(find.textContaining('Oak House'), findsOneWidget);
    expect(find.byTooltip('Download authorised document'), findsOneWidget);
    expect(find.textContaining('Document contents are never embedded'),
        findsOneWidget);
  });

  testWidgets('document search filters filename, property and type', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationProvider.overrideWith(
            (_) async => const OrganisationSummary(
              id: 'organisation',
              name: 'Portfolio',
              role: 'admin',
            ),
          ),
          organisationExportDocumentsProvider.overrideWith(
            (_) async => [
              ExportDocument(
                id: 'one',
                propertyName: 'Oak House',
                scope: 'compliance',
                documentType: 'compliance_evidence',
                originalFilename: 'gas.pdf',
                createdAt: DateTime(2026, 8, 11),
              ),
              ExportDocument(
                id: 'two',
                propertyName: 'Pine House',
                scope: 'maintenance',
                documentType: 'maintenance_evidence',
                originalFilename: 'repair.jpg',
                createdAt: DateTime(2026, 8, 10),
              ),
            ],
          ),
        ],
        child: MaterialApp(
          theme: buildPropertyOsTheme(),
          home: const Scaffold(body: OrganisationExportScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Search filename, property or type'),
      'Pine',
    );
    await tester.pump();

    expect(find.text('repair.jpg'), findsOneWidget);
    expect(find.text('gas.pdf'), findsNothing);
  });
}
