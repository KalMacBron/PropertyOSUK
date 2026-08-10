import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/auth/data/auth_repository.dart';
import 'package:property_os/features/compliance/presentation/compliance_record_screen.dart';
import 'package:property_os/features/compliance/presentation/compliance_register_screen.dart';
import 'package:property_os/features/expenses/presentation/expenses_screen.dart';
import 'package:property_os/features/ownership/presentation/ownership_entities_screen.dart';
import 'package:property_os/features/properties/presentation/properties_screen.dart';
import 'package:property_os/features/today/presentation/today_screen.dart';

final propertyOsRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    ShellRoute(
      builder: (context, state, child) => _AppShell(child: child),
      routes: [
        GoRoute(
          path: '/today',
          builder: (_, __) => const TodayScreen(),
        ),
        GoRoute(
          path: '/properties',
          builder: (_, __) => const PropertiesScreen(),
        ),
        GoRoute(
          path: '/compliance',
          builder: (_, state) => ComplianceRegisterScreen(
            initialStatus: state.uri.queryParameters['status'],
          ),
        ),
        GoRoute(
          path: '/compliance-record/:propertyId/:requirementId',
          builder: (_, state) => ComplianceRecordScreen(
            propertyId: state.pathParameters['propertyId']!,
            requirementId: state.pathParameters['requirementId']!,
            todaySourceId: state.uri.queryParameters['todaySourceId'],
            todayDueDate: state.uri.queryParameters['todayDueDate'] == null
                ? null
                : DateTime.tryParse(
                    state.uri.queryParameters['todayDueDate']!,
                  ),
          ),
        ),
        GoRoute(
          path: '/expenses',
          builder: (_, state) => ExpensesScreen(
            initialPropertyId: state.uri.queryParameters['propertyId'],
            initialComplianceRecordId:
                state.uri.queryParameters['complianceRecordId'],
            openCreate: state.uri.queryParameters['create'] == 'true',
          ),
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
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final selected =
        _destinations.indexWhere((item) => path.startsWith(item.path));
    void navigate(int index) => context.go(_destinations[index].path);
    return LayoutBuilder(builder: (context, constraints) {
      final desktop = constraints.maxWidth >= 900;
      final content = Column(children: [
        Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    bottom: BorderSide(color: PropertyOsColours.border))),
            child: Row(children: [
              Text(
                  'PropertyOS  /  ${selected < 0 ? 'Workspace' : _destinations[selected].label}',
                  style: const TextStyle(color: PropertyOsColours.muted)),
              const Spacer(),
              IconButton(
                  tooltip: 'Sign out',
                  onPressed: () =>
                      AuthRepository(ref.read(supabaseProvider)).signOut(),
                  icon: const Icon(Icons.logout_outlined)),
            ])),
        Expanded(child: child),
      ]);
      if (desktop) {
        return Scaffold(
            body: Row(children: [
          _DesktopNavigation(selected: selected, onSelected: navigate),
          Expanded(child: content)
        ]));
      }
      return Scaffold(
          appBar: AppBar(
              backgroundColor: PropertyOsColours.deepNavy,
              foregroundColor: Colors.white,
              title: const SuiteBrand(compact: true)),
          drawer: Drawer(
              backgroundColor: PropertyOsColours.deepNavy,
              child: SafeArea(
                  child: _NavigationContent(
                      selected: selected,
                      onSelected: (index) {
                        Navigator.pop(context);
                        navigate(index);
                      }))),
          body: content);
    });
  }
}

const _destinations = [
  (label: 'Today', path: '/today', icon: Icons.schedule_outlined),
  (label: 'Properties', path: '/properties', icon: Icons.home_work_outlined),
  (label: 'Compliance', path: '/compliance', icon: Icons.fact_check_outlined),
  (label: 'Expenses', path: '/expenses', icon: Icons.receipt_long_outlined),
  (
    label: 'Ownership',
    path: '/ownership',
    icon: Icons.account_balance_outlined
  ),
];

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 276,
      child: ColoredBox(
          color: PropertyOsColours.deepNavy,
          child: SafeArea(
              child: _NavigationContent(
                  selected: selected, onSelected: onSelected))));
}

class _NavigationContent extends StatelessWidget {
  const _NavigationContent({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
            padding: EdgeInsets.fromLTRB(10, 0, 10, 22), child: SuiteBrand()),
        const Divider(color: Color(0xFF294656)),
        Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            padding: const EdgeInsets.all(14),
            color: const Color(0xFF102F40),
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ORGANISATION',
                      style: TextStyle(
                          color: Color(0xFF7892A3),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                  SizedBox(height: 8),
                  Text('PropertyOS Alpha',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Portfolio workspace',
                      style: TextStyle(color: Color(0xFF8EA4B2), fontSize: 12))
                ])),
        const Padding(
            padding: EdgeInsets.fromLTRB(12, 4, 0, 8),
            child: Text('PORTFOLIO OPERATIONS',
                style: TextStyle(
                    color: Color(0xFF7892A3),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5))),
        for (var i = 0; i < _destinations.length; i++)
          Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Material(
                  color: i == selected
                      ? PropertyOsColours.selectedNavy
                      : Colors.transparent,
                  child: InkWell(
                      onTap: () => onSelected(i),
                      child: Container(
                          decoration: BoxDecoration(
                              border: Border(
                                  left: BorderSide(
                                      color: i == selected
                                          ? PropertyOsColours.amber
                                          : Colors.transparent,
                                      width: 4))),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 15),
                          child: Row(children: [
                            Icon(_destinations[i].icon,
                                color: const Color(0xFFA9BCC8), size: 20),
                            const SizedBox(width: 16),
                            Text(_destinations[i].label,
                                style: TextStyle(
                                    color: i == selected
                                        ? Colors.white
                                        : const Color(0xFFB2C2CC),
                                    fontWeight: i == selected
                                        ? FontWeight.w700
                                        : FontWeight.w400))
                          ]))))),
        const Spacer(),
        const Divider(color: Color(0xFF294656)),
        const Padding(
            padding: EdgeInsets.all(10),
            child: Text('KAELVAREN SUITE · ALPHA',
                style: TextStyle(
                    color: Color(0xFF7892A3),
                    fontSize: 9,
                    letterSpacing: 1.2))),
      ]));
}
