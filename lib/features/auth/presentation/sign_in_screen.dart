import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/auth/data/auth_repository.dart';
import 'package:property_os/features/auth/domain/auth_error_messages.dart';
import 'package:property_os/features/auth/presentation/customer_signup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _scrollController = ScrollController();
  bool _submitting = false;
  bool _obscure = true;
  bool _creatingAccount = false;
  String? _error;
  String? _notice;

  Future<void> _signIn() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });
    try {
      await AuthRepository(
        ref.read(supabaseProvider),
      ).signIn(email: _email.text.trim(), password: _password.text);
    } on AuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = authErrorMessage(
            code: error.code,
            statusCode: error.statusCode,
            message: error.message,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'PropertyOS could not contact the sign-in service. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestPasswordReset() async {
    if (_submitting) return;
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email address first.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _notice = null;
    });
    try {
      await AuthRepository(
        ref.read(supabaseProvider),
      ).requestPasswordReset(email: email);
      if (mounted) {
        setState(
          () => _notice =
              'Password reset email sent. Use the newest link in your inbox.',
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = authErrorMessage(
            code: error.code,
            statusCode: error.statusCode,
            message: error.message,
            fallback: 'Unable to send the reset email. Try again.',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'PropertyOS could not send the reset email.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_creatingAccount) {
      return CustomerSignupScreen(
        onBackToSignIn: () => setState(() => _creatingAccount = false),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 900;
        final form = Container(
          padding: EdgeInsets.symmetric(
            horizontal: narrow ? 16 : 70,
            vertical: narrow ? 24 : 60,
          ),
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _SignInCard(
              formKey: _formKey,
              email: _email,
              password: _password,
              obscure: _obscure,
              submitting: _submitting,
              error: _error,
              notice: _notice,
              onTogglePassword: () => setState(() => _obscure = !_obscure),
              onSignIn: _signIn,
              onResetPassword: _requestPasswordReset,
              onCreateAccount: () => setState(() => _creatingAccount = true),
            ),
          ),
        );
        if (narrow) {
          // On small screens the form comes first so it is visible without
          // scrolling; the product introduction follows it.
          return SingleChildScrollView(
            controller: _scrollController,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: PropertyOsColours.deepNavy,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    alignment: Alignment.centerLeft,
                    child: const SuiteBrand(),
                  ),
                  form,
                  const _SignInHero(narrow: true),
                ],
              ),
            ),
          );
        }
        // The wide layout fills the window but scrolls when the window is too
        // short (or the text too large) for the form to fit.
        return SingleChildScrollView(
          controller: _scrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(flex: 3, child: _SignInHero(narrow: false)),
                  Expanded(flex: 2, child: form),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SignInHero extends StatelessWidget {
  const _SignInHero({required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(narrow ? 24 : 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PropertyOsColours.deepNavy,
            PropertyOsColours.navy,
            Color(0xFF123E56),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!narrow) const SuiteBrand(),
          if (!narrow) const SizedBox(height: 40),
          if (!narrow) const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: const Color(0xFFFFF4D8),
            child: Text(
              'Private Alpha · Property operations'.toUpperCase(),
              style: const TextStyle(
                color: PropertyOsColours.amberText,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Semantics(
            header: true,
            child: Text(
              'Every property.\nEvery obligation.\nOne clear view.',
              style: TextStyle(
                color: Colors.white,
                fontSize: narrow ? 34 : 52,
                height: 1.08,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Coordinate compliance, costs, ownership and daily actions across your portfolio.',
            style: TextStyle(
              color: const Color(0xFFB7C8D2),
              fontSize: narrow ? 16 : 18,
              height: 1.6,
            ),
          ),
          if (narrow) const SizedBox(height: 32),
          if (!narrow) const SizedBox(height: 40),
          if (!narrow) const Spacer(),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF173D52),
              border: Border(
                left: BorderSide(color: PropertyOsColours.amber, width: 4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today'.toUpperCase(),
                  style: const TextStyle(
                    color: PropertyOsColours.amber,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your operational priorities, traced to confirmed portfolio records.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.obscure,
    required this.submitting,
    required this.error,
    required this.notice,
    required this.onTogglePassword,
    required this.onSignIn,
    required this.onResetPassword,
    required this.onCreateAccount,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final bool submitting;
  final String? error;
  final String? notice;
  final VoidCallback onTogglePassword;
  final VoidCallback onSignIn;
  final VoidCallback onResetPassword;
  final VoidCallback onCreateAccount;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(26),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in to continue to your PropertyOS workspace.',
                style: TextStyle(color: PropertyOsColours.muted),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email address'),
                validator: (value) => value == null || !value.contains('@')
                    ? 'Enter a valid email address'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: password,
                obscureText: obscure,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'Show password' : 'Hide password',
                    onPressed: onTogglePassword,
                    icon:
                        Icon(obscure ? Icons.visibility : Icons.visibility_off),
                  ),
                ),
                onFieldSubmitted: (_) => onSignIn(),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your password'
                    : null,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ),
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      notice!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              // The button stays enabled while signing in so keyboard focus is
              // not lost; the screen ignores repeated presses instead.
              FilledButton(
                onPressed: onSignIn,
                child: Text(
                    submitting ? 'Please wait…' : 'Open property workspace  →'),
              ),
              TextButton(
                onPressed: submitting ? null : onResetPassword,
                child: const Text('Forgot password?'),
              ),
              const Divider(height: 28),
              OutlinedButton(
                onPressed: submitting ? null : onCreateAccount,
                child: const Text('Create a PropertyOS account'),
              ),
            ],
          ),
        ),
      );
}
