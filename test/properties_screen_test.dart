import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';
import 'package:property_os/features/properties/presentation/properties_screen.dart';

class _FakePortfolioRepository implements PortfolioRepository {
  _FakePortfolioRepository({required this.failuresBeforeSuccess});

  int failuresBeforeSuccess;
  final createdAddresses = <String>[];

  @override
  Future<void> createProperty({
    required String organisationId,
    required String ownershipEntityId,
    required double ownershipPercentage,
    required String addressLine1,
    required String townOrCity,
    required String postcode,
    String? displayName,
    String? propertyType,
    int? bedrooms,
  }) async {
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw Exception('offline');
    }
    createdAddresses.add(addressLine1);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _owner = OrganisationSummary(
  id: 'organisation',
  name: 'Portfolio',
  role: 'owner',
);

Future<void> _pump(
  WidgetTester tester, {
  required PortfolioRepository repository,
  List<Map<String, dynamic>> properties = const [],
  List<OwnershipEntity> owners = const [
    OwnershipEntity(id: 'owner', legalName: 'Jo Bloggs', entityType: 'person'),
  ],
  String? initialPropertyId,
}) async {
  tester.view.physicalSize = const Size(1280, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(
    initialLocation: '/properties',
    routes: [
      GoRoute(
        path: '/properties',
        builder: (_, __) => Scaffold(
          body: PropertiesScreen(initialPropertyId: initialPropertyId),
        ),
      ),
      GoRoute(
        path: '/ownership',
        builder: (_, __) => const Scaffold(body: Text('Ownership page')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        organisationProvider.overrideWith((_) async => _owner),
        ownershipEntitiesProvider.overrideWith((_) async => owners),
        propertiesProvider.overrideWith((_) async => properties),
        portfolioRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(
        theme: buildPropertyOsTheme(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _fillAndSave(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Address line 1'),
    '1 Test Street',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Town or city'),
    'Testville',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Postcode'),
    'TE1 1ST',
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Add property').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a failed save keeps the values and reopens the form',
      (tester) async {
    final repository = _FakePortfolioRepository(failuresBeforeSuccess: 1);
    await _pump(tester, repository: repository);

    await tester.tap(find.widgetWithText(FilledButton, 'Add property'));
    await tester.pumpAndSettle();
    await _fillAndSave(tester);

    expect(
      find.text('Property not added. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('1 Test Street'), findsOneWidget);
    expect(find.text('TE1 1ST'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Add property').last);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Property added'), findsOneWidget);
    expect(repository.createdAddresses, ['1 Test Street']);
  });

  testWidgets('empty register offers the next step', (tester) async {
    await _pump(
      tester,
      repository: _FakePortfolioRepository(failuresBeforeSuccess: 0),
    );

    expect(find.text('No properties yet'), findsOneWidget);
    expect(find.textContaining('onboard'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add owner'));
    await tester.pumpAndSettle();
    expect(find.text('Ownership page'), findsOneWidget);
  });

  testWidgets('selected property is marked with the selected state',
      (tester) async {
    await _pump(
      tester,
      repository: _FakePortfolioRepository(failuresBeforeSuccess: 0),
      initialPropertyId: 'b',
      properties: const [
        {
          'id': 'a',
          'address_line_1': '1 First Road',
          'town_or_city': 'Testville',
          'postcode': 'TE1 1AA',
        },
        {
          'id': 'b',
          'address_line_1': '2 Second Road',
          'town_or_city': 'Testville',
          'postcode': 'TE1 1AB',
        },
      ],
    );

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles.map((tile) => tile.selected), [false, true]);
  });
}
