import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/user_admin/data/user_admin_repository.dart';

void main() {
  test('parses active organisation member', () {
    final user = OrganisationUser.fromJson({
      'record_type': 'member',
      'record_id': 'user-1',
      'email': 'owner@example.test',
      'display_name': 'Portfolio Owner',
      'role': 'owner',
      'state': 'active',
      'is_current_user': true,
      'expires_at': null,
    });

    expect(user.type, 'member');
    expect(user.role, 'owner');
    expect(user.isCurrentUser, isTrue);
  });

  test('parses pending invitation expiry', () {
    final user = OrganisationUser.fromJson({
      'record_type': 'invitation',
      'record_id': 'invitation-1',
      'email': 'viewer@example.test',
      'display_name': null,
      'role': 'viewer',
      'state': 'pending',
      'is_current_user': false,
      'expires_at': '2026-08-17T12:00:00Z',
    });

    expect(user.state, 'pending');
    expect(user.expiresAt, DateTime.utc(2026, 8, 17, 12));
  });
}
