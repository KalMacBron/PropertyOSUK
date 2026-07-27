import 'package:flutter/material.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 420,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('PropertyOS', style: TextStyle(fontSize: 30)),
                  SizedBox(height: 12),
                  Text(
                    'Invitation-only Alpha sign-in will be implemented here.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
