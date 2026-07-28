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

  Future<void> requestPasswordReset({required String email}) =>
      _client.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: Uri.base.origin,
      );

  Future<void> updatePassword(String password) =>
      _client.auth.updateUser(UserAttributes(password: password));

  Future<void> signOut() => _client.auth.signOut();
}
