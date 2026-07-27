import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/today/domain/today_action.dart';

void main() {
  test('Today action parses database output', () {
    final action = TodayAction.fromJson({
      'title': 'Review Gas Safety Certificate',
      'reason': 'due_soon',
      'priority': 'medium',
      'property_id': 'property-id',
      'due_date': '2026-08-27',
    });

    expect(action.title, 'Review Gas Safety Certificate');
    expect(action.dueDate, DateTime(2026, 8, 27));
  });
}

