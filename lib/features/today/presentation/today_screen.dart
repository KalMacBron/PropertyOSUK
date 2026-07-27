import 'package:flutter/material.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        Text('Good morning', style: TextStyle(fontSize: 30)),
        SizedBox(height: 8),
        Text('Here is what needs your attention today.'),
        SizedBox(height: 24),
        Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'The database-backed daily briefing and recommended actions '
              'will be rendered here.',
            ),
          ),
        ),
      ],
    );
  }
}
