import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/auth/data/auth_repository.dart';
import 'package:property_os/features/auth/domain/auth_error_messages.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/user_admin/application/user_admin_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InvitationOnboardingScreen extends ConsumerStatefulWidget {
  const InvitationOnboardingScreen({super.key});

  @override
  ConsumerState<InvitationOnboardingScreen> createState() =>
      _InvitationOnboardingScreenState();
}

class _InvitationOnboardingScreenState
    extends ConsumerState<InvitationOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  Future<void> _complete() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthRepository(ref.read(supabaseProvider))
          .completeInvitationOnboarding(_password.text);
      ref.invalidate(organisationMembershipsProvider);
      ref.invalidate(organisationUsersProvider);
    } on AuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = authErrorMessage(
            code: error.code,
            statusCode: error.statusCode,
            message: error.message,
            fallback: 'Unable to complete your account. Try again.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Your account could not be completed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PropertyOsColours.workspace,
        body: Center(
          child: SizedBox(
            width: 440,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('Complete your account',
                          style: TextStyle(
                              fontSize: 30, color: PropertyOsColours.ink)),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a password to secure your PropertyOS account and join the organisation.',
                        style: TextStyle(color: PropertyOsColours.muted),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'New password',
                          suffixIcon: IconButton(
                            tooltip:
                                _obscure ? 'Show password' : 'Hide password',
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure
                                ? Icons.visibility
                                : Icons.visibility_off),
                          ),
                        ),
                        validator: (value) => value == null || value.length < 8
                            ? 'Use at least 8 characters'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmation,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: const InputDecoration(
                          labelText: 'Confirm new password',
                        ),
                        onFieldSubmitted: (_) => _complete(),
                        validator: (value) => value != _password.text
                            ? 'Passwords do not match'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: _submitting ? null : _complete,
                        child: Text(
                            _submitting ? 'Completing…' : 'Complete account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
