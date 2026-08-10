import 'package:supabase_flutter/supabase_flutter.dart';

class OrganisationUser {
  const OrganisationUser(
      {required this.type,
      required this.id,
      required this.email,
      required this.role,
      required this.state,
      required this.isCurrentUser,
      this.displayName,
      this.expiresAt});
  factory OrganisationUser.fromJson(Map<String, dynamic> json) =>
      OrganisationUser(
        type: json['record_type'] as String,
        id: json['record_id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String?,
        role: json['role'] as String,
        state: json['state'] as String,
        isCurrentUser: json['is_current_user'] as bool? ?? false,
        expiresAt: json['expires_at'] == null
            ? null
            : DateTime.parse(json['expires_at'] as String),
      );
  final String type, id, email, role, state;
  final String? displayName;
  final bool isCurrentUser;
  final DateTime? expiresAt;
}

class UserAdminRepository {
  const UserAdminRepository(this._client);
  final SupabaseClient _client;

  Future<List<OrganisationUser>> list(String organisationId) async {
    final rows = await _client.rpc<List<dynamic>>('list_organisation_users',
        params: {'target_organisation_id': organisationId});
    return rows
        .cast<Map<String, dynamic>>()
        .map(OrganisationUser.fromJson)
        .toList();
  }

  Future<void> invite(
      {required String organisationId,
      required String email,
      required String role}) async {
    final response = await _client.functions.invoke('invite-organisation-user',
        body: {
          'organisationId': organisationId,
          'email': email.trim(),
          'role': role
        });
    if (response.status < 200 || response.status >= 300) {
      throw Exception('invitation_failed');
    }
  }

  Future<void> changeRole(String organisationId, String userId, String role) =>
      _client.rpc<void>('change_organisation_member_role', params: {
        'target_organisation_id': organisationId,
        'target_user_id': userId,
        'target_role': role
      });
  Future<void> remove(String organisationId, String userId) =>
      _client.rpc<void>('remove_organisation_member', params: {
        'target_organisation_id': organisationId,
        'target_user_id': userId
      });
  Future<void> revoke(String invitationId) =>
      _client.rpc<void>('revoke_organisation_invitation',
          params: {'target_invitation_id': invitationId});
  Future<int> acceptMine() async =>
      await _client.rpc<int>('accept_my_organisation_invitations');
}
