import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/app/router.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

void main() {
  const organisation = OrganisationSummary(
    id: 'organisation',
    name: 'Portfolio',
    role: 'owner',
  );

  testWidgets('an authenticated deep link opens ownership directly', (
    tester,
  ) async {
    final router = createPropertyOsRouter(initialLocation: '/ownership');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationMembershipsProvider.overrideWith(
            (_) async => [organisation],
          ),
          organisationProvider.overrideWith((_) async => organisation),
          ownershipEntitiesProvider.overrideWith(
            (_) async => const [
              OwnershipEntity(
                id: 'entity',
                entityType: 'limited_company',
                legalName: 'Test Props Ltd',
                companyNumber: '12345678',
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

    expect(find.text('Ownership entities'), findsOneWidget);
    expect(find.text('Company number: 12345678'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/ownership');
  });

  testWidgets('the bare root redirects to Today', (tester) async {
    final router = createPropertyOsRouter(initialLocation: '/');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationMembershipsProvider.overrideWith(
            (_) async => [organisation],
          ),
          organisationProvider.overrideWith((_) async => organisation),
        ],
        child: MaterialApp.router(
          theme: buildPropertyOsTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, '/today');
  });
}
