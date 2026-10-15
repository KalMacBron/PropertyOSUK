import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/auth/application/auth_state.dart';
import 'package:property_os/features/user_admin/data/user_admin_repository.dart';

void main() {
  test('maps invitation email rate limits to a specific failure', () {
    expect(
      invitationFailureFor(429, {'error': 'email_rate_limit_reached'}),
      InvitationFailure.rateLimited,
    );
    expect(
      invitationFailureFor(409, {'error': 'invitation_email_failed'}),
      InvitationFailure.generic,
    );
    expect(
      invitationFailureMessage(InvitationFailure.rateLimited),
      contains('limit'),
    );
  });

  test('requires onboarding only for tagged invitation sessions', () {
    expect(
      invitationOnboardingRequired(
        {'propertyos_invitation_onboarding': true},
      ),
      isTrue,
    );
    expect(invitationOnboardingRequired({}), isFalse);
    expect(invitationOnboardingRequired(null), isFalse);
  });

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
