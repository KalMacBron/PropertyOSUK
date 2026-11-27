import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/auth/presentation/password_recovery_screen.dart';

void main() {
  testWidgets('tells the user an old password cannot be reused',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PasswordRecoveryScreen()),
      ),
    );

    expect(
      find.text(
        'Must be at least 8 characters and different from your current '
        'password.',
      ),
      findsOneWidget,
    );
  });
}
