import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/app/router.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/auth/application/auth_state.dart';
import 'package:property_os/features/auth/presentation/password_recovery_screen.dart';
import 'package:property_os/features/auth/presentation/sign_in_screen.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/presentation/workspace_setup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PropertyOsApp extends StatelessWidget {
  const PropertyOsApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const ProviderScope(child: _AuthenticatedApp());
}

class _AuthenticatedApp extends ConsumerWidget {
  const _AuthenticatedApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateProvider, (_, next) {
      if (next.value?.event == AuthChangeEvent.passwordRecovery) {
        ref.read(passwordRecoveryProvider.notifier).state = true;
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
    final organisation = ref.watch(organisationProvider);
    return organisation.when(
      loading: () => MaterialApp(
        theme: buildPropertyOsTheme(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (_, __) => MaterialApp(
        theme: buildPropertyOsTheme(),
        home: const Scaffold(
          body: Center(
            child: Text('PropertyOS could not load your workspace.'),
          ),
        ),
      ),
      data: (value) => value == null
          ? MaterialApp(
              title: 'PropertyOS',
              debugShowCheckedModeBanner: false,
              theme: buildPropertyOsTheme(),
              home: const WorkspaceSetupScreen(),
            )
          : MaterialApp.router(
              title: 'PropertyOS',
              debugShowCheckedModeBanner: false,
              theme: buildPropertyOsTheme(),
              routerConfig: propertyOsRouter,
            ),
    );
  }
}
