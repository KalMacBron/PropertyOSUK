import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/tasks/application/task_providers.dart';
import 'package:property_os/features/tasks/domain/task_models.dart';
import 'package:property_os/features/tasks/presentation/tasks_screen.dart';

void main() {
  testWidgets('Tasks workspace filters overdue and completed tasks',
      (tester) async {
    final tasks = [
      PortfolioTask(
        id: 'overdue',
        organisationId: 'org',
        propertyId: 'property',
        propertyName: 'Oak House',
        title: 'Overdue inspection',
        priority: TaskPriority.high,
        state: TaskState.open,
        dueDate: DateTime.now().subtract(const Duration(days: 2)),
        sourceType: 'manual',
        createdAt: DateTime.now(),
      ),
      PortfolioTask(
        id: 'complete',
        organisationId: 'org',
        propertyId: 'property',
        propertyName: 'Oak House',
        title: 'Completed inspection',
        priority: TaskPriority.medium,
        state: TaskState.completed,
        dueDate: DateTime.now(),
        sourceType: 'manual',
        createdAt: DateTime.now(),
      ),
    ];
    final router = GoRouter(
      initialLocation: '/tasks',
      routes: [
        GoRoute(
          path: '/tasks',
          builder: (_, state) => Scaffold(
            body: TasksScreen(
              initialFilter: state.uri.queryParameters['filter'],
            ),
          ),
        ),
        GoRoute(
          path: '/properties',
          builder: (_, __) => const Scaffold(body: Text('Properties')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksProvider.overrideWith((_) async => tasks),
          propertiesProvider.overrideWith(
            (_) async => [
              {
                'id': 'property',
                'address_line_1': 'Oak House',
              },
            ],
          ),
        ],
        child: MaterialApp.router(
          theme: buildPropertyOsTheme(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overdue inspection'), findsOneWidget);
    expect(find.text('Completed inspection'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save changes'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller
          ?.text,
      'Overdue inspection',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('OVERDUE'));
    await tester.pumpAndSettle();

    expect(find.text('Overdue inspection'), findsOneWidget);
    expect(find.text('Completed inspection'), findsNothing);
    expect(
      router.routeInformationProvider.value.uri.toString(),
      '/tasks?filter=overdue',
    );
  });
}
