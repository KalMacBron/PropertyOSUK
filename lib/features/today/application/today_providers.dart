import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:property_os/core/database/supabase_provider.dart';
import 'package:property_os/features/compliance/application/compliance_providers.dart';
import 'package:property_os/features/portfolio/application/portfolio_providers.dart';
import 'package:property_os/features/today/data/today_repository.dart';
import 'package:property_os/features/today/domain/today_action.dart';
import 'package:property_os/features/today/domain/portfolio_summary.dart';

final todayRepositoryProvider = Provider<TodayRepository>(
  (ref) => TodayRepository(ref.watch(supabaseProvider)),
);

final todayActionsProvider = FutureProvider<List<TodayAction>>((ref) async {
  final organisation = await ref.watch(organisationProvider.future);
  if (organisation == null) return [];
  return ref.watch(todayRepositoryProvider).fetchActions(organisation.id);
});

final portfolioSummaryProvider = FutureProvider<PortfolioSummary>((ref) async {
  final requirements = await ref.watch(complianceRequirementsProvider.future);
  final properties = await ref.watch(compliancePortfolioProvider.future);
  return buildPortfolioSummary(
    properties: properties,
    requirements: requirements,
    today: DateTime.now(),
  );
});
