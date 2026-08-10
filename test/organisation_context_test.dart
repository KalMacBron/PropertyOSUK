import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

void main() {
  const workspaceA = OrganisationSummary(
    id: 'workspace-a',
    name: 'Workspace A',
    role: 'owner',
  );
  const workspaceB = OrganisationSummary(
    id: 'workspace-b',
    name: 'Workspace B',
    role: 'member',
    isActive: true,
  );

  test('sole authorised organisation is selected automatically', () async {
    final container = ProviderContainer(
      overrides: [
        organisationMembershipsProvider.overrideWith(
          (ref) async => [workspaceA],
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(organisationProvider.future), workspaceA);
  });

  test('persisted authorised organisation is restored', () async {
    final container = ProviderContainer(
      overrides: [
        organisationMembershipsProvider.overrideWith(
          (ref) async => [workspaceA, workspaceB],
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(organisationProvider.future), workspaceB);
  });

  test('multiple organisations require explicit selection without preference',
      () async {
    final container = ProviderContainer(
      overrides: [
        organisationMembershipsProvider.overrideWith(
          (ref) async => [
            workspaceA,
            const OrganisationSummary(
              id: 'workspace-b',
              name: 'Workspace B',
              role: 'member',
            )
          ],
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(organisationProvider.future), isNull);
  });

  test('stale selected organisation id is ignored', () async {
    final container = ProviderContainer(
      overrides: [
        organisationMembershipsProvider.overrideWith(
          (ref) async => [workspaceA],
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeOrganisationIdProvider.notifier).state = 'foreign';

    expect(await container.read(organisationProvider.future), workspaceA);
  });
}
