import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:property_os/app/property_os_app.dart';
import 'package:property_os/app/router.dart';
import 'package:property_os/features/compliance/data/compliance_repository.dart';
import 'package:property_os/features/documents/data/document_repository.dart';
import 'package:property_os/features/documents/domain/compliance_evidence.dart';
import 'package:property_os/features/portfolio/data/portfolio_repository.dart';
import 'package:property_os/features/today/data/today_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  setUpAll(() async {
    if (supabaseUrl.isEmpty || publishableKey.isEmpty) {
      fail(
        'Run TC-000 with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY '
        'dart-defines for a disposable local Supabase instance.',
      );
    }
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: publishableKey,
    );
  });

  tearDownAll(() async {
    await Supabase.instance.client.auth.signOut();
  });

  testWidgets('TC-000 compliance evidence to completed Today action', (
    tester,
  ) async {
    final client = Supabase.instance.client;
    final suffix = DateTime.now().microsecondsSinceEpoch;
    const password = 'Local-TC000-Only-Password-73!';

    await client.auth.signUp(
      email: 'tc000-owner-$suffix@example.test',
      password: password,
    );
    expect(client.auth.currentUser, isNotNull);

    final portfolio = PortfolioRepository(client);
    final organisation =
        await portfolio.createOrganisation('TC-000 disposable owner');
    await portfolio.createOwnershipEntity(
      organisationId: organisation.id,
      entityType: 'individual',
      legalName: 'TC-000 Test Landlord',
    );
    final ownership =
        (await portfolio.listOwnershipEntities(organisation.id)).single;
    await portfolio.createProperty(
      organisationId: organisation.id,
      ownershipEntityId: ownership.id,
      ownershipPercentage: 100,
      addressLine1: '1 Test Boundary Road',
      townOrCity: 'Birmingham',
      postcode: 'B1 1AA',
      displayName: 'TC-000 Test Property',
      propertyType: 'house',
      bedrooms: 2,
    );
    final property = (await portfolio.listProperties(organisation.id)).single;
    final propertyId = property['id'] as String;

    final compliance = ComplianceRepository(client);
    final gas = (await compliance.listRequirements(organisation.id))
        .singleWhere((requirement) => requirement.code == 'gas_safety');
    final today = DateTime.now();
    final expiry = DateTime(today.year, today.month, today.day + 31);
    await compliance.saveRecord(
      organisationId: organisation.id,
      propertyId: propertyId,
      requirementTypeId: gas.id,
      issueDate: DateTime(today.year - 1, today.month, today.day),
      expiryDate: expiry,
      reviewDate: null,
      referenceNumber: 'TC-000-GAS',
      notes: 'Fictional local integration fixture.',
    );
    final record = await client
        .from('property_compliance_records')
        .select('id')
        .eq('property_id', propertyId)
        .eq('requirement_type_id', gas.id)
        .single();
    final recordId = record['id'] as String;

    await DocumentRepository(client).uploadComplianceEvidence(
      organisationId: organisation.id,
      propertyId: propertyId,
      complianceRecordId: recordId,
      file: const EvidenceFile(
        name: 'tc000-gas-safety.pdf',
        mimeType: 'application/pdf',
        bytes: <int>[37, 80, 68, 70, 45, 49, 46, 52, 10, 37, 37, 69, 79, 70],
      ),
    );
    final document = await client
        .from('documents')
        .select('id, storage_path')
        .eq('compliance_record_id', recordId)
        .single();
    final documentId = document['id'] as String;
    final storagePath = document['storage_path'] as String;

    final action = (await TodayRepository(client).fetchActions(organisation.id))
        .singleWhere(
      (candidate) => candidate.sourceId == recordId,
    );
    expect(action.reason, 'due_soon');
    expect(action.dueDate, DateTime(expiry.year, expiry.month, expiry.day));
    expect(action.propertyId, propertyId);
    expect(action.evidenceDocumentId, documentId);

    await tester.pumpWidget(const PropertyOsApp());
    await tester.pumpAndSettle();
    expect(find.text('Review Gas Safety Certificate'), findsOneWidget);
    expect(find.textContaining('Evidence attached'), findsOneWidget);

    await tester.tap(find.text('Review Gas Safety Certificate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('TC-000 Test Property'), findsWidgets);
    expect(find.text('tc000-gas-safety.pdf'), findsOneWidget);
    expect(find.text('Mark complete'), findsOneWidget);

    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();
    expect(find.text('Review Gas Safety Certificate'), findsNothing);

    propertyOsRouter.go('/compliance-record/$propertyId/${gas.id}');
    await tester.pumpAndSettle();
    expect(find.text('Property timeline'), findsOneWidget);
    expect(
        find.text('Gas Safety Certificate action completed'), findsOneWidget);

    final completion = await client
        .from('tasks')
        .select('id')
        .eq('source_type', 'today_compliance')
        .eq('source_id', recordId)
        .single();
    final completionId = completion['id'] as String;

    await client.auth.signOut();
    await client.auth.signUp(
      email: 'tc000-other-$suffix@example.test',
      password: password,
    );
    final otherOrganisation =
        await portfolio.createOrganisation('TC-000 disposable other tenant');
    expect(otherOrganisation.id, isNot(organisation.id));

    expect(
      await client
          .from('property_compliance_records')
          .select('id')
          .eq('id', recordId),
      isEmpty,
    );
    expect(
      await client.from('documents').select('id').eq('id', documentId),
      isEmpty,
    );
    expect(
      await client.from('tasks').select('id').eq('id', completionId),
      isEmpty,
    );
    expect(
      await client
          .from('today_actions')
          .select('source_id')
          .eq('source_id', recordId),
      isEmpty,
    );
    await expectLater(
      () => client.rpc<void>(
        'complete_compliance_today_action',
        params: {
          'target_source_id': recordId,
          'target_due_date':
              '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-'
                  '${expiry.day.toString().padLeft(2, '0')}',
        },
      ),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      () => client.storage
          .from(DocumentRepository.bucket)
          .createSignedUrl(storagePath, 60),
      throwsA(anything),
    );
  });
}
