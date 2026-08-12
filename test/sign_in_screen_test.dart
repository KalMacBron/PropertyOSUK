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
    expect(find.text('Create a PropertyOS account'), findsOneWidget);
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

  testWidgets('customer can open signup and receives local validation',
      (tester) async {
    await renderAt(tester, const Size(1440, 900));

    await tester.tap(find.text('Create a PropertyOS account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account'), findsOneWidget);
    expect(find.textContaining('verify your email'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(find.text('Enter your name'), findsOneWidget);
    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Use at least 8 characters'), findsOneWidget);
  });
}
