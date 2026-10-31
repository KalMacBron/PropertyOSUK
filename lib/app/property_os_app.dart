import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/app/router.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/auth/application/auth_state.dart';
import 'package:property_os/features/auth/data/auth_repository.dart';
import 'package:property_os/features/auth/presentation/password_recovery_screen.dart';
import 'package:property_os/features/auth/presentation/invitation_onboarding_screen.dart';
import 'package:property_os/features/auth/presentation/sign_in_screen.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/presentation/workspace_setup_screen.dart';
import 'package:property_os/features/portfolio/presentation/workspace_selection_screen.dart';
import 'package:property_os/features/user_admin/application/user_admin_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PropertyOsApp extends StatelessWidget {
  const PropertyOsApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context) =>
      ProviderScope(child: _AuthenticatedApp(router: router));
}

class _AuthenticatedApp extends ConsumerWidget {
  const _AuthenticatedApp({this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (_, next) {
      if (next.value?.event == AuthChangeEvent.passwordRecovery) {
        ref.read(passwordRecoveryProvider.notifier).state = true;
      }
      if (next.value?.event == AuthChangeEvent.signedIn ||
          next.value?.event == AuthChangeEvent.signedOut) {
        ref.invalidate(activeOrganisationIdProvider);
        ref.invalidate(organisationMembershipsProvider);
      }
    });
    final recoveringPassword = ref.watch(passwordRecoveryProvider);
    if (recoveringPassword) {
      return MaterialApp(
        title: 'PropertyOS',
        debugShowCheckedModeBanner: false,
        theme: buildPropertyOsTheme(),
        home: const PasswordRecoveryScreen(),
      );
    }

    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return MaterialApp(
        title: 'PropertyOS',
        debugShowCheckedModeBanner: false,
        theme: buildPropertyOsTheme(),
        home: const SignInScreen(),
      );
    }
    if (invitationOnboardingRequired(user.userMetadata)) {
      return MaterialApp(
        title: 'PropertyOS',
        debugShowCheckedModeBanner: false,
        theme: buildPropertyOsTheme(),
        home: const InvitationOnboardingScreen(),
      );
    }
    final invitationAcceptance = ref.watch(invitationAcceptanceProvider);
    if (invitationAcceptance.isLoading) {
      return MaterialApp(
        theme: buildPropertyOsTheme(),
        home: const Scaffold(body: SuiteLoading(label: 'Loading PropertyOS')),
      );
    }
    if (invitationAcceptance.hasError) {
      return MaterialApp(
        theme: buildPropertyOsTheme(),
        home: _StartupError(
          message: 'PropertyOS could not check your invitations.',
          onRetry: () => ref.invalidate(invitationAcceptanceProvider),
        ),
      );
    }
    final memberships = ref.watch(organisationMembershipsProvider);
    return memberships.when(
      loading: () => MaterialApp(
        theme: buildPropertyOsTheme(),
        home: const Scaffold(body: SuiteLoading(label: 'Loading PropertyOS')),
      ),
      error: (_, __) => MaterialApp(
        theme: buildPropertyOsTheme(),
        home: _StartupError(
          message: 'PropertyOS could not load your workspace.',
          onRetry: () => ref.invalidate(organisationMembershipsProvider),
        ),
      ),
      data: (organisations) {
        if (organisations.isEmpty) {
          return MaterialApp(
            title: 'PropertyOS',
            debugShowCheckedModeBanner: false,
            theme: buildPropertyOsTheme(),
            home: const WorkspaceSetupScreen(),
          );
        }
        final organisation = ref.watch(organisationProvider);
        return organisation.when(
          loading: () => MaterialApp(
            theme: buildPropertyOsTheme(),
            home: const Scaffold(
              body: SuiteLoading(label: 'Loading your workspace'),
            ),
          ),
          error: (_, __) => MaterialApp(
            theme: buildPropertyOsTheme(),
            home: _StartupError(
              message: 'PropertyOS could not select your workspace.',
              onRetry: () => ref.invalidate(organisationProvider),
            ),
          ),
          data: (value) => value == null
              ? MaterialApp(
                  title: 'PropertyOS',
                  debugShowCheckedModeBanner: false,
                  theme: buildPropertyOsTheme(),
                  home: WorkspaceSelectionScreen(
                    organisations: organisations,
                  ),
                )
              : MaterialApp.router(
                  title: 'PropertyOS',
                  debugShowCheckedModeBanner: false,
                  theme: buildPropertyOsTheme(),
                  routerConfig: router ?? propertyOsRouter,
                ),
        );
      },
    );
  }
}

/// A start-up failure that still lets the user retry or sign out, because the
/// app shell (and its Sign out button) has not loaded.
class _StartupError extends ConsumerWidget {
  const _StartupError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SuiteErrorState(
                message: '$message Check your connection and try again.',
                onRetry: onRetry,
                secondaryAction: TextButton.icon(
                  onPressed: () =>
                      AuthRepository(ref.read(supabaseProvider)).signOut(),
                  icon: const Icon(Icons.logout_outlined),
                  label: const Text('Sign out'),
                ),
              ),
            ),
          ),
        ),
      );
}
