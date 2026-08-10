import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';

OrganisationSummary organisationWithRole(String role) => OrganisationSummary(
      id: 'organisation-id',
      name: 'Test organisation',
      role: role,
    );

void main() {
  group('organisation capabilities', () {
    test('unknown organisation defaults to read only', () {
      expect(canWriteOrganisation(null), isFalse);
    });

    test('viewer is read only', () {
      final organisation = organisationWithRole('viewer');

      expect(organisation.isViewer, isTrue);
      expect(organisation.canWriteOperations, isFalse);
      expect(organisation.canUploadEvidence, isFalse);
      expect(organisation.canDeleteEvidence, isFalse);
      expect(organisation.canManageUsers, isFalse);
      expect(canWriteOrganisation(organisation), isFalse);
    });

    test('member can operate records but cannot administer', () {
      final organisation = organisationWithRole('member');

      expect(organisation.canWriteOperations, isTrue);
      expect(organisation.canUploadEvidence, isTrue);
      expect(organisation.canDeleteEvidence, isFalse);
      expect(organisation.canManageUsers, isFalse);
    });

    for (final role in ['owner', 'admin']) {
      test('$role has operational and administrative capabilities', () {
        final organisation = organisationWithRole(role);

        expect(organisation.canWriteOperations, isTrue);
        expect(organisation.canUploadEvidence, isTrue);
        expect(organisation.canDeleteEvidence, isTrue);
        expect(organisation.canManageUsers, isTrue);
      });
    }
  });
}
