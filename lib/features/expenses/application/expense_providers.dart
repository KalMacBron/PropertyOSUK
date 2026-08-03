import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/expenses/data/expense_repository.dart';
import 'package:property_os/features/expenses/domain/expense_models.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(supabaseProvider)),
);

final expensePropertiesProvider = FutureProvider<List<ExpenseProperty>>((
  ref,
) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref.watch(expenseRepositoryProvider).listProperties(organisation.id);
});

final expensesProvider = FutureProvider<List<PropertyExpense>>((ref) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref.watch(expenseRepositoryProvider).listExpenses(organisation.id);
});

void refreshExpenses(WidgetRef ref) {
  ref.invalidate(expensesProvider);
  ref.invalidate(expensePropertiesProvider);
}
