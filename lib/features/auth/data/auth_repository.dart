import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> requestPasswordReset({required String email}) => _client.auth
      .resetPasswordForEmail(email.trim(), redirectTo: Uri.base.origin);

  Future<void> updatePassword(String password) =>
      _client.auth.updateUser(UserAttributes(password: password));

  Future<void> completeInvitationOnboarding(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
    await _client.rpc<int>('accept_my_organisation_invitations');
    await _client.auth.updateUser(
      UserAttributes(data: {'propertyos_invitation_onboarding': false}),
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
