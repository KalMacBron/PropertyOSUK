import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

  test('captures a hash workspace route before authenticated startup', () {
    expect(
      initialWorkspaceLocation(
        Uri.parse('https://alpha.propertyosuk.com/#/ownership'),
      ),
      '/ownership',
    );
    expect(
      initialWorkspaceLocation(
        Uri.parse(
          'https://alpha.propertyosuk.com/#/compliance?status=notRecorded',
        ),
      ),
      '/compliance?status=notRecorded',
    );
  });

  test('ignores non-route fragments such as authentication callbacks', () {
    expect(
      initialWorkspaceLocation(
        Uri.parse('https://alpha.propertyosuk.com/#access_token=secret'),
      ),
      isNull,
    );
  });

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

  testWidgets('explicit web hash route overrides a consumed platform route', (
    tester,
  ) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );
    final router = createPropertyOsRouter(initialLocation: '/ownership');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationMembershipsProvider.overrideWith(
            (_) async => [organisation],
          ),
          organisationProvider.overrideWith((_) async => organisation),
          ownershipEntitiesProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp.router(
          theme: buildPropertyOsTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

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

  Future<GoRouter> pumpShell(WidgetTester tester, Size size,
      {double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final router = createPropertyOsRouter(initialLocation: '/ownership');
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organisationMembershipsProvider.overrideWith(
            (_) async => [organisation],
          ),
          organisationProvider.overrideWith((_) async => organisation),
          ownershipEntitiesProvider.overrideWith((_) async => const []),
        ],
        child: MaterialApp.router(
          theme: buildPropertyOsTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('sidebar scrolls so the last destination is reachable',
      (tester) async {
    final router = await pumpShell(tester, const Size(1280, 520));

    expect(tester.takeException(), isNull);
    final sidebar = find.descendant(
      of: find.byKey(const Key('navigation-destinations')),
      matching: find.byType(Scrollable),
    );
    expect(sidebar, findsOneWidget);
    final export = find.widgetWithText(InkWell, 'Export');
    await tester.scrollUntilVisible(export, 80, scrollable: sidebar);
    await tester.pumpAndSettle();
    await tester.tap(export);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/settings/export');
  });

  testWidgets('shell top bar fits a 320px screen at 200% text', (tester) async {
    await pumpShell(tester, const Size(320, 640), textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Sign out'), findsOneWidget);
    final signOut = tester.getRect(find.byTooltip('Sign out'));
    expect(signOut.right, lessThanOrEqualTo(320));
  });

  testWidgets('current destination is announced as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpShell(tester, const Size(1280, 900));

    final selected = tester
        .widgetList<Semantics>(
          find.ancestor(
            of: find.widgetWithText(InkWell, 'Ownership'),
            matching: find.byType(Semantics),
          ),
        )
        .where((widget) => widget.properties.selected != null);
    expect(selected.single.properties.selected, isTrue);
    final other = tester
        .widgetList<Semantics>(
          find.ancestor(
            of: find.widgetWithText(InkWell, 'Today'),
            matching: find.byType(Semantics),
          ),
        )
        .where((widget) => widget.properties.selected != null);
    expect(other.single.properties.selected, isFalse);
    handle.dispose();
  });
}
