import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/export/presentation/organisation_export_screen.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

void main() {
  testWidgets('viewer is denied the complete portfolio report screen', (
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
    expect(find.text('Download portfolio report'), findsNothing);
  });

  testWidgets('owner sees the friendly Excel portfolio report interface', (
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
        ],
        child: MaterialApp(
          theme: buildPropertyOsTheme(),
          home: const Scaffold(body: OrganisationExportScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Portfolio report'), findsOneWidget);
    expect(find.text('Download portfolio report'), findsOneWidget);
    expect(find.text('Document register'), findsOneWidget);
    expect(find.text('Audit history'), findsOneWidget);
    expect(find.textContaining('formatted Excel workbook'), findsOneWidget);
    expect(find.textContaining('Document contents are never embedded'),
        findsOneWidget);
    expect(find.text('Download organisation JSON'), findsNothing);
    expect(find.byTooltip('Download authorised document'), findsNothing);
  });
}
