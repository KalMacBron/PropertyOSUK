import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/features/auth/presentation/sign_in_screen.dart';
import 'package:property_os/features/properties/presentation/properties_screen.dart';
import 'package:property_os/features/today/presentation/today_screen.dart';

final propertyOsRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    GoRoute(
      path: '/sign-in',
      builder: (context, state) => const SignInScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/today',
          builder: (context, state) => const TodayScreen(),
        ),
        GoRoute(
          path: '/properties',
          builder: (context, state) => const PropertiesScreen(),
        ),
      ],
    ),
  ],
);

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PropertyOS')),
      drawer: NavigationDrawer(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(28, 20, 16, 12),
            child: Text('Workspace'),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.today_outlined),
            label: const Text('Today'),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.home_work_outlined),
            label: const Text('Properties'),
          ),
        ],
        onDestinationSelected: (index) {
          Navigator.of(context).pop();
          context.go(index == 0 ? '/today' : '/properties');
        },
      ),
      body: child,
    );
  }
}
