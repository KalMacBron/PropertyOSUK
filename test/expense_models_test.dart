import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/expenses/domain/expense_models.dart';

void main() {
  test('parses GBP exactly to pence', () {
    expect(parsePoundsToPence('125'), 12500);
    expect(parsePoundsToPence('125.4'), 12540);
    expect(parsePoundsToPence('125.40'), 12540);
  });

  test('rejects zero, negatives and excessive decimals', () {
    expect(() => parsePoundsToPence('0'), throwsFormatException);
    expect(() => parsePoundsToPence('-1'), throwsFormatException);
    expect(() => parsePoundsToPence('1.234'), throwsFormatException);
  });

  test('combined expense filters match consistently', () {
    final expense = PropertyExpense(
      id: 'expense',
      organisationId: 'organisation',
      propertyId: 'property',
      propertyName: 'Alpha House',
      ownershipEntityId: 'owner',
      ownershipEntityName: 'Karl',
      expenseDate: DateTime(2026, 7, 29),
      description: 'Gas certificate',
      category: 'compliance_certificates',
      amountPence: 9500,
      vatTreatment: 'included',
      paymentStatus: 'paid',
      createdAt: DateTime(2026, 7, 29),
    );
    final filters = ExpenseFilters(
      propertyId: 'property',
      ownerId: 'owner',
      category: 'compliance_certificates',
      paymentStatus: 'paid',
      from: DateTime(2026, 7, 1),
      to: DateTime(2026, 7, 31),
    );
    expect(filters.matches(expense), isTrue);
    expect(
      ExpenseFilters(propertyId: 'other').matches(expense),
      isFalse,
    );
  });

  test('CSV preserves pence and escapes spreadsheet values', () {
    final expense = PropertyExpense(
      id: 'expense',
      organisationId: 'organisation',
      propertyId: 'property',
      propertyName: 'Alpha, House',
      ownershipEntityId: 'owner',
      ownershipEntityName: 'Karl',
      expenseDate: DateTime(2026, 7, 29),
      supplier: 'Gas "R" Us',
      description: 'Certificate',
      category: 'compliance_certificates',
      amountPence: 9999,
      vatTreatment: 'included',
      vatAmountPence: 1667,
      paymentStatus: 'paid',
      createdAt: DateTime(2026, 7, 29),
    );
    final csv = csvForExpenses([expense]);
    expect(csv, contains('"Alpha, House"'));
    expect(csv, contains('"Gas ""R"" Us"'));
    expect(csv, contains('"99.99"'));
    expect(csv, contains('"16.67"'));
  });
}
