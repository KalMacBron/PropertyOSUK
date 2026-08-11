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
import 'package:property_os/features/maintenance/presentation/maintenance_screen.dart';
import 'package:property_os/features/ownership/presentation/ownership_entities_screen.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';
import 'package:property_os/features/properties/presentation/properties_screen.dart';
import 'package:property_os/features/property_dashboard/presentation/property_dashboard_screen.dart';
import 'package:property_os/features/tasks/presentation/tasks_screen.dart';
import 'package:property_os/features/tenancies/presentation/tenancies_screen.dart';
import 'package:property_os/features/today/presentation/today_screen.dart';
import 'package:property_os/features/user_admin/presentation/user_admin_screen.dart';

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
          builder: (_, state) => PropertiesScreen(
            initialPropertyId: state.uri.queryParameters['propertyId'],
          ),
        ),
        GoRoute(
          path: '/properties/:propertyId',
          builder: (_, state) => PropertyDashboardScreen(
            propertyId: state.pathParameters['propertyId']!,
          ),
        ),
        GoRoute(
          path: '/compliance',
          builder: (_, state) => ComplianceRegisterScreen(
            initialStatus: state.uri.queryParameters['status'],
            initialPropertyId: state.uri.queryParameters['propertyId'],
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
            initialMaintenanceIssueId:
                state.uri.queryParameters['maintenanceIssueId'],
            openCreate: state.uri.queryParameters['create'] == 'true',
          ),
        ),
        GoRoute(
          path: '/tasks',
          builder: (_, state) => TasksScreen(
            initialFilter: state.uri.queryParameters['filter'],
            initialPropertyId: state.uri.queryParameters['propertyId'],
            initialMaintenanceIssueId:
                state.uri.queryParameters['maintenanceIssueId'],
            openCreate: state.uri.queryParameters['create'] == 'true',
          ),
        ),
        GoRoute(
          path: '/maintenance',
          builder: (_, state) => MaintenanceScreen(
            initialPropertyId: state.uri.queryParameters['propertyId'],
            openCreate: state.uri.queryParameters['create'] == 'true',
          ),
        ),
        GoRoute(
          path: '/maintenance/:issueId',
          builder: (_, state) => MaintenanceScreen(
            initialIssueId: state.pathParameters['issueId'],
          ),
        ),
        GoRoute(
          path: '/tenancies',
          builder: (_, state) => TenanciesScreen(
            initialTenancyId: state.uri.queryParameters['tenancyId'],
            initialPropertyId: state.uri.queryParameters['propertyId'],
            openCreate: state.uri.queryParameters['create'] == 'true',
          ),
        ),
        GoRoute(
          path: '/ownership',
          builder: (_, __) => const OwnershipEntitiesScreen(),
        ),
        GoRoute(
          path: '/settings/users',
          builder: (_, __) => const UserAdminScreen(),
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
    final organisation = ref.watch(organisationProvider).valueOrNull;
    final organisations =
        ref.watch(organisationMembershipsProvider).valueOrNull ?? const [];
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
              if (organisation?.role == 'viewer') ...[
                const SizedBox(width: 16),
                const Chip(label: Text('VIEW ONLY')),
              ],
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
          _DesktopNavigation(
            selected: selected,
            onSelected: navigate,
            organisation: organisation,
            organisations: organisations,
          ),
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
                      organisation: organisation,
                      organisations: organisations,
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
  (label: 'Tasks', path: '/tasks', icon: Icons.task_alt_outlined),
  (
    label: 'Maintenance',
    path: '/maintenance',
    icon: Icons.home_repair_service_outlined
  ),
  (label: 'Tenancies', path: '/tenancies', icon: Icons.key_outlined),
  (label: 'Expenses', path: '/expenses', icon: Icons.receipt_long_outlined),
  (
    label: 'Ownership',
    path: '/ownership',
    icon: Icons.account_balance_outlined
  ),
  (
    label: 'Users',
    path: '/settings/users',
    icon: Icons.manage_accounts_outlined
  ),
];

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.selected,
    required this.onSelected,
    required this.organisation,
    required this.organisations,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final OrganisationSummary? organisation;
  final List<OrganisationSummary> organisations;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 276,
      child: ColoredBox(
          color: PropertyOsColours.deepNavy,
          child: SafeArea(
              child: _NavigationContent(
            selected: selected,
            onSelected: onSelected,
            organisation: organisation,
            organisations: organisations,
          ))));
}

class _NavigationContent extends ConsumerStatefulWidget {
  const _NavigationContent({
    required this.selected,
    required this.onSelected,
    required this.organisation,
    required this.organisations,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final OrganisationSummary? organisation;
  final List<OrganisationSummary> organisations;

  @override
  ConsumerState<_NavigationContent> createState() => _NavigationContentState();
}

class _NavigationContentState extends ConsumerState<_NavigationContent> {
  bool _switching = false;

  Future<void> _switchWorkspace(String? organisationId) async {
    if (organisationId == null || organisationId == widget.organisation?.id) {
      return;
    }
    OrganisationSummary? selected;
    for (final organisation in widget.organisations) {
      if (organisation.id == organisationId) selected = organisation;
    }
    if (selected == null) return;
    setState(() => _switching = true);
    try {
      await selectOrganisation(ref, selected);
      if (mounted) context.go('/today');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The workspace could not be changed.')),
        );
      }
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

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
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ORGANISATION',
                  style: TextStyle(
                      color: Color(0xFF7892A3),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5)),
              SizedBox(height: 8),
              Text(widget.organisation?.name ?? 'PropertyOS',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  widget.organisation == null
                      ? 'Portfolio workspace'
                      : '${widget.organisation!.role.toUpperCase()} · Portfolio workspace',
                  style:
                      const TextStyle(color: Color(0xFF8EA4B2), fontSize: 12))
            ])),
        if (widget.organisations.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: DropdownButtonFormField<String>(
              initialValue: widget.organisation?.id,
              dropdownColor: PropertyOsColours.deepNavy,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                labelText: _switching ? 'Switching…' : 'Workspace',
                labelStyle: const TextStyle(color: Color(0xFFA9BCC8)),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF496575)),
                ),
              ),
              items: [
                for (final organisation in widget.organisations)
                  DropdownMenuItem(
                    value: organisation.id,
                    child: Text(organisation.name),
                  ),
              ],
              onChanged: _switching ? null : _switchWorkspace,
            ),
          ),
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
                  color: i == widget.selected
                      ? PropertyOsColours.selectedNavy
                      : Colors.transparent,
                  child: InkWell(
                      onTap: () => widget.onSelected(i),
                      child: Container(
                          decoration: BoxDecoration(
                              border: Border(
                                  left: BorderSide(
                                      color: i == widget.selected
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
                                    color: i == widget.selected
                                        ? Colors.white
                                        : const Color(0xFFB2C2CC),
                                    fontWeight: i == widget.selected
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
