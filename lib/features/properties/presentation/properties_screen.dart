import 'package:flutter/material.dart';

class PropertiesScreen extends StatelessWidget {
  const PropertiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        Text('Properties', style: TextStyle(fontSize: 30)),
        SizedBox(height: 8),
        Text('Portfolio records will be listed here.'),
      ],
    );
  }
}
