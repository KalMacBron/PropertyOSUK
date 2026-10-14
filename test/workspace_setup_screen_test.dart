import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';
import 'package:property_os/features/portfolio/presentation/workspace_setup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _PortfolioRepository extends PortfolioRepository {
  _PortfolioRepository(super.client);

  int creations = 0;
  String? ownerType;

  @override
  Future<OrganisationSummary> createOrganisation(String name,
      {String? displayName}) async {
    creations++;
    return OrganisationSummary(id: 'workspace', name: name, role: 'owner');
  }

  @override
  Future<String> createOwnershipEntity({
    required String organisationId,
    required String entityType,
    required String legalName,
    String? companyNumber,
  }) async {
    ownerType = entityType;
    return 'owner';
  }
}

void main() {
  test(
      'workspace identifiers satisfy the database rule for names at boundaries',
      () {
    for (final name in [
      'Melanie Holyman',
      ' Melanie Holyman ',
      'Melanie.Holyman',
      "Melanie’s portfolio!",
      '-My portfolio-',
      '!!!',
      '房产',
    ]) {
      expect(organisationSlug(name, 12345),
          matches(RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')),
          reason: name);
    }
    expect(
        organisationSlug(' Melanie Holyman ', 12345), 'melanie-holyman-12345');
    expect(organisationSlug('房产', 12345), 'portfolio-12345');
  });

  testWidgets('individual landlord can reach property setup without a company',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final client = (await tester.runAsync(() async => SupabaseClient(
        'https://example.supabase.co', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false))))!;
    addTearDown(() => tester.runAsync(client.dispose));
    final repository = _PortfolioRepository(client);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        supabaseProvider.overrideWithValue(client),
        portfolioRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: WorkspaceSetupScreen()),
    ));
    expect(find.text('Set up your portfolio'), findsOneWidget);
    expect(find.textContaining('For individual landlords'), findsOneWidget);
    await tester.tap(find.text('Create portfolio'));
    await tester.pump();
    expect(find.text('Enter a portfolio name.'), findsOneWidget);
    expect(repository.creations, 0);

    await tester.enterText(find.byType(TextField), 'x' * 121);
    await tester.tap(find.text('Create portfolio'));
    await tester.pump();
    expect(find.text('Use 120 characters or fewer for the portfolio name.'),
        findsOneWidget);
    expect(repository.creations, 0);

    await tester.enterText(find.byType(TextField), ' My portfolio! ');
    await tester.tap(find.text('Create portfolio'));
    await tester.pumpAndSettle();
    expect(find.text('Who owns the properties?'), findsOneWidget);
    expect(find.text('Company number'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Example Landlord');
    await tester.tap(find.text('Save ownership details'));
    await tester.pumpAndSettle();
    expect(repository.ownerType, 'individual');
    expect(find.text('Add your first property'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
