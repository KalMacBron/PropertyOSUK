import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/auth/data/auth_repository.dart';
import 'package:property_os/features/compliance/presentation/compliance_register_screen.dart';
import 'package:property_os/features/ownership/presentation/ownership_entities_screen.dart';
import 'package:property_os/features/properties/presentation/properties_screen.dart';
import 'package:property_os/features/today/presentation/today_screen.dart';

final propertyOsRouter = GoRouter(
  initialLocation: '/compliance',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(path: '/today', builder: (_, __) => const TodayScreen()),
        GoRoute(
          path: '/properties',
          builder: (_, __) => const PropertiesScreen(),
        ),
        GoRoute(
          path: '/compliance',
          builder: (_, __) => const ComplianceRegisterScreen(),
        ),
        GoRoute(
          path: '/ownership',
          builder: (_, __) => const OwnershipEntitiesScreen(),
        ),
      ],
    ),
  ],
);

class _AppShell extends ConsumerWidget {
  const _AppShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('PropertyOS'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: () => AuthRepository(ref.read(supabaseProvider)).signOut(),
          icon: const Icon(Icons.logout),
        ),
        const SizedBox(width: 8),
      ],
    ),
    drawer: NavigationDrawer(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 20, 16, 12),
          child: Text('Portfolio'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.today_outlined),
          label: Text('Today'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.home_work_outlined),
          label: Text('Properties'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.fact_check_outlined),
          label: Text('Compliance'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.account_balance_outlined),
          label: Text('Ownership'),
        ),
      ],
      onDestinationSelected: (index) {
        Navigator.of(context).pop();
        context.go(
          ['/today', '/properties', '/compliance', '/ownership'][index],
        );
      },
    ),
    body: child,
  );
}
