import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/app/suite_ui.dart';
import 'package:property_os/app/theme.dart';

void main() {
  Future<void> render(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPropertyOsTheme(),
        home: const Scaffold(
          body: WorkspacePage(
            eyebrow: 'Portfolio register',
            title: 'Properties',
            subtitle: 'Your active portfolio.',
            action: FilledButton(onPressed: null, child: Text('Add property')),
            child: SuiteEmptyState(
              icon: Icons.home_work_outlined,
              title: 'No properties yet',
              message: 'Add your first property.',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('workspace page renders at desktop width', (tester) async {
    await render(tester, const Size(1440, 900));
    expect(tester.takeException(), isNull);
    expect(find.text('PORTFOLIO REGISTER'), findsOneWidget);
    expect(find.text('No properties yet'), findsOneWidget);
  });

  testWidgets('workspace page wraps safely at mobile width', (tester) async {
    await render(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.text('Add property'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
  });
}
