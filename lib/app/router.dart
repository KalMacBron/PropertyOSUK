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
import 'package:property_os/features/export/presentation/organisation_export_screen.dart';
import 'package:property_os/features/maintenance/presentation/maintenance_screen.dart';
import 'package:property_os/features/maintenance/presentation/contractor_directory_screen.dart';
import 'package:property_os/features/ownership/presentation/ownership_entities_screen.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';
import 'package:property_os/features/properties/presentation/properties_screen.dart';
import 'package:property_os/features/property_dashboard/presentation/property_dashboard_screen.dart';
import 'package:property_os/features/tasks/presentation/tasks_screen.dart';
import 'package:property_os/features/tenancies/presentation/tenancies_screen.dart';
import 'package:property_os/features/today/presentation/today_screen.dart';
import 'package:property_os/features/user_admin/presentation/user_admin_screen.dart';

final propertyOsRouter = createPropertyOsRouter();

String? initialWorkspaceLocation(Uri browserUri) {
  final fragment = browserUri.fragment;
  return fragment.startsWith('/') ? fragment : null;
}

GoRouter createPropertyOsRouter({String? initialLocation}) => GoRouter(
      initialLocation: initialLocation,
      overridePlatformDefaultLocation: initialLocation != null,
      routes: [
        GoRoute(path: '/', redirect: (_, __) => '/today'),
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
              path: '/maintenance-contractors',
              builder: (_, __) => const ContractorDirectoryScreen(),
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
            GoRoute(
              path: '/settings/export',
              builder: (_, __) => const OrganisationExportScreen(),
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
            constraints: const BoxConstraints(minHeight: 72),
            padding: EdgeInsets.symmetric(horizontal: desktop ? 28 : 16),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                    bottom: BorderSide(color: PropertyOsColours.border))),
            child: Row(children: [
              Expanded(
                child: Text(
                    'PropertyOS  /  ${selected < 0 ? 'Workspace' : _destinations[selected].label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: PropertyOsColours.muted)),
              ),
              if (organisation?.role == 'viewer') ...[
                const SizedBox(width: 16),
                Chip(label: Text('View only'.toUpperCase())),
              ],
              const SizedBox(width: 8),
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
  (
    label: 'Today',
    path: '/today',
    icon: Icons.schedule_outlined,
    selectedIcon: Icons.schedule,
  ),
  (
    label: 'Properties',
    path: '/properties',
    icon: Icons.home_work_outlined,
    selectedIcon: Icons.home_work,
  ),
  (
    label: 'Compliance',
    path: '/compliance',
    icon: Icons.fact_check_outlined,
    selectedIcon: Icons.fact_check,
  ),
  (
    label: 'Tasks',
    path: '/tasks',
    icon: Icons.task_alt_outlined,
    selectedIcon: Icons.task_alt,
  ),
  (
    label: 'Maintenance',
    path: '/maintenance',
    icon: Icons.home_repair_service_outlined,
    selectedIcon: Icons.home_repair_service,
  ),
  (
    label: 'Tenancies',
    path: '/tenancies',
    icon: Icons.key_outlined,
    selectedIcon: Icons.key,
  ),
  (
    label: 'Expenses',
    path: '/expenses',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  ),
  (
    label: 'Ownership',
    path: '/ownership',
    icon: Icons.account_balance_outlined,
    selectedIcon: Icons.account_balance,
  ),
  (
    label: 'Users',
    path: '/settings/users',
    icon: Icons.manage_accounts_outlined,
    selectedIcon: Icons.manage_accounts,
  ),
  (
    label: 'Export',
    path: '/settings/export',
    icon: Icons.download_outlined,
    selectedIcon: Icons.download,
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
  Widget build(BuildContext context) {
    const sectionLabel = TextStyle(
        color: PropertyOsColours.sidebarLabel,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2);
    // The brand and workspace card stay fixed; the destinations scroll so
    // every item stays reachable on short windows and at large text sizes.
    return Padding(
        padding: const EdgeInsets.all(18),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(10, 0, 10, 22), child: SuiteBrand()),
          const Divider(color: Color(0xFF294656)),
          Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.all(14),
              color: const Color(0xFF102F40),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Workspace'.toUpperCase(), style: sectionLabel),
                    const SizedBox(height: 8),
                    Text(widget.organisation?.name ?? 'PropertyOS',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                        widget.organisation == null
                            ? 'Portfolio workspace'
                            : '${_roleLabel(widget.organisation!.role)} · Portfolio workspace',
                        style: const TextStyle(
                            color: Color(0xFF9DB1BF), fontSize: 12))
                  ])),
          if (widget.organisations.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
              child: DropdownButtonFormField<String>(
                initialValue: widget.organisation?.id,
                isExpanded: true,
                dropdownColor: PropertyOsColours.deepNavy,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  labelText: _switching ? 'Switching…' : 'Switch workspace',
                  labelStyle: const TextStyle(color: Color(0xFFA9BCC8)),
                  fillColor: PropertyOsColours.deepNavy,
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: Color(0xFF496575)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide:
                        BorderSide(color: PropertyOsColours.amber, width: 2),
                  ),
                ),
                items: [
                  for (final organisation in widget.organisations)
                    DropdownMenuItem(
                      value: organisation.id,
                      child: Text(
                        organisation.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _switching ? null : _switchWorkspace,
              ),
            ),
          Expanded(
            child: ListView(
              key: const Key('navigation-destinations'),
              padding: EdgeInsets.zero,
              children: [
                Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 0, 8),
                    child: Text('Portfolio operations'.toUpperCase(),
                        style: sectionLabel)),
                for (var i = 0; i < _destinations.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _NavigationItem(
                      label: _destinations[i].label,
                      icon: i == widget.selected
                          ? _destinations[i].selectedIcon
                          : _destinations[i].icon,
                      selected: i == widget.selected,
                      onTap: () => widget.onSelected(i),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF294656)),
          Padding(
              padding: const EdgeInsets.all(10),
              child: Text('KaelVaren Suite · Alpha'.toUpperCase(),
                  style: const TextStyle(
                      color: PropertyOsColours.sidebarLabel,
                      fontSize: 12,
                      letterSpacing: 1.2))),
        ]));
  }
}

class _NavigationItem extends StatefulWidget {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<_NavigationItem> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? PropertyOsColours.selectedNavy : Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (value) => setState(() => _focused = value),
          hoverColor: Colors.white.withValues(alpha: 0.08),
          focusColor: Colors.white.withValues(alpha: 0.12),
          splashColor: Colors.white.withValues(alpha: 0.16),
          highlightColor: Colors.white.withValues(alpha: 0.08),
          child: Container(
            foregroundDecoration: _focused
                ? BoxDecoration(
                    border:
                        Border.all(color: PropertyOsColours.amber, width: 2),
                  )
                : null,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color:
                      selected ? PropertyOsColours.amber : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            child: Row(children: [
              Icon(widget.icon,
                  color: selected ? Colors.white : const Color(0xFFA9BCC8),
                  size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(widget.label,
                    style: TextStyle(
                        color:
                            selected ? Colors.white : const Color(0xFFB2C2CC),
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

String _roleLabel(String role) =>
    role.isEmpty ? role : '${role[0].toUpperCase()}${role.substring(1)}';
