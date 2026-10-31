import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/auth/data/auth_repository.dart';
import 'package:property_os/features/auth/domain/auth_error_messages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerSignupScreen extends ConsumerStatefulWidget {
  const CustomerSignupScreen({super.key, required this.onBackToSignIn});

  final VoidCallback onBackToSignIn;

  @override
  ConsumerState<CustomerSignupScreen> createState() =>
      _CustomerSignupScreenState();
}

class _CustomerSignupScreenState extends ConsumerState<CustomerSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthRepository(ref.read(supabaseProvider)).signUp(
        displayName: _name.text,
        email: _email.text,
        password: _password.text,
      );
      if (mounted) setState(() => _submitted = true);
    } on AuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = authErrorMessage(
            code: error.code,
            statusCode: error.statusCode,
            message: error.message,
            fallback: 'Unable to create the account. Try again.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'PropertyOS could not create the account.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Row(
          children: [
            if (MediaQuery.sizeOf(context).width >= 900)
              const Expanded(
                child: ColoredBox(
                  color: PropertyOsColours.deepNavy,
                  child: Padding(
                    padding: EdgeInsets.all(64),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SuiteBrand(),
                        Spacer(),
                        Text(
                          'Start with one clear view of your portfolio.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Create your secure workspace, then add your ownership details and first property.',
                          style: TextStyle(
                            color: Color(0xFFB7C8D2),
                            fontSize: 18,
                            height: 1.5,
                          ),
                        ),
                        Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _submitted ? _confirmationPanel() : _form(),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _confirmationPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.mark_email_read_outlined,
              size: 56, color: PropertyOsColours.amberText),
          const SizedBox(height: 20),
          const Text('Check your email',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 38, color: PropertyOsColours.ink)),
          const SizedBox(height: 12),
          Text(
            'We sent a confirmation link to ${_email.text.trim()}. Open the newest email to confirm your address and continue setting up PropertyOS.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: PropertyOsColours.muted, height: 1.5),
          ),
          const SizedBox(height: 12),
          const Text(
            'If the link has expired, return here and submit the form again to receive a new email.',
            textAlign: TextAlign.center,
            style: TextStyle(color: PropertyOsColours.muted),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: widget.onBackToSignIn,
            child: const Text('Back to sign in'),
          ),
        ],
      );

  Widget _form() => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Create your account',
                style: TextStyle(fontSize: 40, color: PropertyOsColours.ink)),
            const SizedBox(height: 8),
            const Text('We will verify your email before creating a workspace.',
                style: TextStyle(color: PropertyOsColours.muted)),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Your name'),
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Enter your name'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email address'),
              validator: (value) => value == null || !value.contains('@')
                  ? 'Enter a valid email address'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Show password' : 'Hide password',
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon:
                      Icon(_obscure ? Icons.visibility : Icons.visibility_off),
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
              decoration: const InputDecoration(labelText: 'Confirm password'),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) =>
                  value != _password.text ? 'Passwords do not match' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? 'Creating account…' : 'Create account'),
            ),
            TextButton(
              onPressed: _submitting ? null : widget.onBackToSignIn,
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      );
}
