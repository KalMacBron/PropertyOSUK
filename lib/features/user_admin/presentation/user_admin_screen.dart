import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/user_admin/application/user_admin_providers.dart';
import 'package:property_os/features/user_admin/data/user_admin_repository.dart';

class UserAdminScreen extends ConsumerWidget {
  const UserAdminScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organisation = ref.watch(organisationProvider).valueOrNull;
    if (organisation == null ||
        !['owner', 'admin'].contains(organisation.role)) {
      return const Center(child: Text('Owner or admin access is required.'));
    }
    final users = ref.watch(organisationUsersProvider);
    return SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('User administration',
                      style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 34,
                          color: PropertyOsColours.ink)),
                  SizedBox(height: 6),
                  Text(
                      'Manage who can access this organisation and what they can do.',
                      style: TextStyle(color: PropertyOsColours.muted))
                ])),
            FilledButton.icon(
                onPressed: () =>
                    _invite(context, ref, organisation.id, organisation.role),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Invite user'))
          ]),
          const SizedBox(height: 24),
          users.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Users could not be loaded.'),
              data: (items) => Card(
                      child: Column(children: [
                    for (final item in items)
                      _UserRow(
                          item: item,
                          actorRole: organisation.role,
                          organisationId: organisation.id)
                  ]))),
        ]));
  }

  Future<void> _invite(BuildContext context, WidgetRef ref,
      String organisationId, String actorRole) async {
    final email = TextEditingController();
    var role = 'viewer';
    final submitted = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                    title: const Text('Invite user'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                              labelText: 'Email address')),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: [
                            if (actorRole == 'owner')
                              const DropdownMenuItem(
                                  value: 'admin', child: Text('Admin')),
                            const DropdownMenuItem(
                                value: 'member', child: Text('Member')),
                            const DropdownMenuItem(
                                value: 'viewer', child: Text('Viewer'))
                          ],
                          onChanged: (value) => setState(() => role = value!))
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Send invitation'))
                    ])));
    if (submitted != true || email.text.trim().isEmpty) return;
    try {
      await ref.read(userAdminRepositoryProvider).invite(
          organisationId: organisationId, email: email.text, role: role);
      ref.invalidate(organisationUsersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Invitation sent.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('The invitation could not be sent.')));
      }
    }
  }
}

class _UserRow extends ConsumerWidget {
  const _UserRow(
      {required this.item,
      required this.actorRole,
      required this.organisationId});
  final OrganisationUser item;
  final String actorRole, organisationId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = item.type == 'invitation';
    final manageable = !item.isCurrentUser &&
        (actorRole == 'owner' || !['owner', 'admin'].contains(item.role));
    return ListTile(
        leading: CircleAvatar(
            child: Icon(pending ? Icons.mail_outline : Icons.person_outline)),
        title: Text(item.displayName?.isNotEmpty == true
            ? item.displayName!
            : item.email),
        subtitle: Text('${item.role.toUpperCase()} · ${item.state}'),
        trailing: manageable
            ? PopupMenuButton<String>(
                onSelected: (action) async {
                  final repo = ref.read(userAdminRepositoryProvider);
                  if (action == 'resend') {
                    await repo.invite(
                        organisationId: organisationId,
                        email: item.email,
                        role: item.role);
                  } else if (action == 'remove') {
                    if (pending) {
                      await repo.revoke(item.id);
                    } else {
                      await repo.remove(organisationId, item.id);
                    }
                  } else {
                    await repo.changeRole(organisationId, item.id, action);
                  }
                  ref.invalidate(organisationUsersProvider);
                },
                itemBuilder: (_) => [
                      if (pending)
                        const PopupMenuItem(
                            value: 'resend', child: Text('Resend invitation')),
                      if (!pending) ...[
                        if (actorRole == 'owner')
                          const PopupMenuItem(
                              value: 'admin', child: Text('Make admin')),
                        const PopupMenuItem(
                            value: 'member', child: Text('Make member')),
                        const PopupMenuItem(
                            value: 'viewer', child: Text('Make viewer'))
                      ],
                      PopupMenuItem(
                          value: 'remove',
                          child: Text(
                              pending ? 'Revoke invitation' : 'Remove access'))
                    ])
            : Chip(label: Text(item.role.toUpperCase())));
  }
}
