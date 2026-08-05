import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/expenses/domain/expense_models.dart';
import 'package:property_os/features/expenses/presentation/expenses_screen.dart';

void main() {
  testWidgets('expense delete confirmation closes its root dialog only', (
    tester,
  ) async {
    bool? confirmed;
    final expense = PropertyExpense(
      id: 'expense',
      organisationId: 'organisation',
      propertyId: 'property',
      propertyName: 'Alpha House',
      ownershipEntityId: 'owner',
      ownershipEntityName: 'Owner',
      expenseDate: DateTime(2026, 8, 5),
      description: 'Gas certificate',
      category: 'compliance_certificates',
      amountPence: 9500,
      vatTreatment: 'not_specified',
      paymentStatus: 'paid',
      createdAt: DateTime(2026, 8, 5),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (nestedContext) => Scaffold(
              body: Column(
                children: [
                  const Text('Expenses route'),
                  FilledButton(
                    onPressed: () async {
                      confirmed = await showExpenseDeleteConfirmation(
                        nestedContext,
                        expense,
                      );
                    },
                    child: const Text('Open confirmation'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open confirmation'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.text('Expenses route'), findsOneWidget);
    expect(find.text('Delete expense?'), findsNothing);
  });
}
