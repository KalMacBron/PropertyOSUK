import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/app/theme.dart';
import 'package:property_os/features/auth/presentation/sign_in_screen.dart';

void main() {
  Future<void> renderAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: buildPropertyOsTheme(),
          home: const SignInScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('sign-out landing renders at desktop size', (tester) async {
    await renderAt(tester, const Size(1440, 900));

    expect(tester.takeException(), isNull);
    expect(find.text('PROPERTYOS'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Open property workspace  →'), findsOneWidget);
  });

  testWidgets('sign-out landing renders and scrolls at mobile size',
      (tester) async {
    await renderAt(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('PROPERTYOS'), findsOneWidget);
    expect(find.byType(Scrollable), findsWidgets);
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
    );
    await tester.pump();
    expect(find.text('Open property workspace  →'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
