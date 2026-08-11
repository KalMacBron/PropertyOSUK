import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:property_os/features/export/application/portfolio_workbook_builder.dart';

void main() {
  test('builds a readable multi-sheet workbook with typed values', () {
    final bytes = const PortfolioWorkbookBuilder().build(_payload);
    final workbook = Excel.decodeBytes(bytes);

    expect(workbook.tables.keys, [
      'Summary',
      'Properties',
      'Ownership',
      'Compliance',
      'Tenancies',
      'Maintenance',
      'Contractors',
      'Tasks',
      'Expenses',
      'Users',
      'Document Register',
      'Audit History',
    ]);
    expect(_text(workbook['Properties'], 'A5'), 'Oak House');
    expect(_text(workbook['Compliance'], 'B5'), 'Gas safety');
    expect(_text(workbook['Tenancies'], 'B5'), 'Alex Tenant');
    expect(_text(workbook['Document Register'], 'A5'), 'gas-safety.pdf');
    expect(
      workbook['Expenses'].cell(CellIndex.indexByString('G5')).value,
      anyOf(isA<DoubleCellValue>(), isA<IntCellValue>()),
    );
    expect(
      workbook['Expenses'].cell(CellIndex.indexByString('A5')).value,
      isA<DateCellValue>(),
    );
    expect(
      workbook['Ownership'].cell(CellIndex.indexByString('E5')).value,
      anyOf(isA<DoubleCellValue>(), isA<IntCellValue>()),
    );
  });

  test('adds frozen headings and filters without leaking storage paths', () {
    final bytes = const PortfolioWorkbookBuilder().build(_payload);
    final archive = ZipDecoder().decodeBytes(bytes);
    final workbookText = archive.files
        .where((file) => file.name.endsWith('.xml'))
        .map((file) => utf8.decode(file.content as List<int>))
        .join('\n');

    expect(workbookText, contains('state="frozen"'));
    expect(workbookText, contains('<autoFilter ref="A4:'));
    expect(workbookText, isNot(contains('private/storage/path')));
    expect(workbookText, isNot(contains('extracted_data')));
  });

  test('writes a clear empty row for datasets with no records', () {
    final payload = Map<String, dynamic>.from(_payload);
    payload['data'] = <String, dynamic>{};
    payload['record_counts'] = <String, dynamic>{};
    final workbook = Excel.decodeBytes(
      const PortfolioWorkbookBuilder().build(payload),
    );

    expect(_text(workbook['Properties'], 'A5'), 'No records in this section.');
    expect(_text(workbook['Expenses'], 'A5'), 'No records in this section.');
  });
}

String? _text(Sheet sheet, String address) =>
    (sheet.cell(CellIndex.indexByString(address)).value as TextCellValue?)
        ?.value
        .toString();

final _payload = <String, dynamic>{
  'schema_version': 'propertyos-alpha-export-v1',
  'exported_at': '2026-08-11T15:00:00Z',
  'currency': 'GBP',
  'organisation': {
    'id': 'organisation',
    'name': 'PropertyOS Alpha',
  },
  'record_counts': {
    'members': 1,
    'invitations': 1,
    'properties': 1,
    'ownership_entities': 1,
    'property_ownerships': 1,
    'tenants': 1,
    'tenancies': 1,
    'compliance_records': 1,
    'contractors': 1,
    'maintenance_issues': 1,
    'tasks': 1,
    'expenses': 1,
    'documents': 1,
    'audit_events': 1,
  },
  'data': {
    'properties': [
      {
        'id': 'property',
        'display_name': 'Oak House',
        'address_line_1': '1 Oak Road',
        'town_or_city': 'York',
        'postcode': 'YO1 1AA',
        'bedrooms': 3,
        'status': 'active',
        'created_at': '2026-01-01T10:00:00Z',
      }
    ],
    'ownership_entities': [
      {
        'id': 'entity',
        'legal_name': 'Oak Holdings Ltd',
        'entity_type': 'limited_company',
        'company_number': '12345678',
      }
    ],
    'property_ownerships': [
      {
        'property_id': 'property',
        'ownership_entity_id': 'entity',
        'ownership_percentage': 100,
        'ownership_started_on': '2025-01-01',
      }
    ],
    'compliance_requirement_types': [
      {'id': 'gas', 'name': 'Gas safety'}
    ],
    'compliance_records': [
      {
        'id': 'compliance',
        'property_id': 'property',
        'requirement_type_id': 'gas',
        'issue_date': '2026-01-02',
        'expiry_date': '2027-01-02',
        'reference_number': 'GAS-1',
      }
    ],
    'tenants': [
      {'id': 'tenant', 'display_name': 'Alex Tenant'}
    ],
    'tenancies': [
      {
        'id': 'tenancy',
        'property_id': 'property',
        'start_date': '2026-02-01',
        'monthly_rent_pence': 125000,
        'rent_due_day': 1,
        'status': 'active',
      }
    ],
    'tenancy_tenants': [
      {
        'tenancy_id': 'tenancy',
        'tenant_id': 'tenant',
        'is_lead': true,
      }
    ],
    'contractors': [
      {
        'id': 'contractor',
        'name': 'Safe Gas Ltd',
        'trade': 'Gas engineer',
        'status': 'active',
      }
    ],
    'maintenance_issues': [
      {
        'id': 'maintenance',
        'property_id': 'property',
        'contractor_id': 'contractor',
        'title': 'Boiler service',
        'priority': 'medium',
        'state': 'reported',
        'reported_at': '2026-08-01T09:00:00Z',
        'estimated_cost_pence': 15000,
      }
    ],
    'tasks': [
      {
        'property_id': 'property',
        'title': 'Book engineer',
        'priority': 'high',
        'state': 'open',
        'due_date': '2026-08-15',
        'source_type': 'maintenance',
      }
    ],
    'expenses': [
      {
        'property_id': 'property',
        'ownership_entity_id': 'entity',
        'expense_date': '2026-08-01',
        'supplier': 'Safe Gas Ltd',
        'description': 'Annual boiler service',
        'category': 'repairs_maintenance',
        'amount_pence': 15000,
        'vat_amount_pence': 2500,
        'vat_treatment': 'included',
        'payment_status': 'paid',
      }
    ],
    'members': [
      {
        'email': 'owner@example.com',
        'display_name': 'Owner',
        'role': 'owner',
        'created_at': '2026-01-01T10:00:00Z',
      }
    ],
    'invitations': [
      {
        'email': 'admin@example.com',
        'role': 'admin',
        'state': 'pending',
        'created_at': '2026-08-10T10:00:00Z',
      }
    ],
    'documents': [
      {
        'id': 'document',
        'property_id': 'property',
        'original_filename': 'gas-safety.pdf',
        'scope': 'compliance',
        'document_type': 'compliance_evidence',
        'mime_type': 'application/pdf',
        'size_bytes': 2048,
        'state': 'confirmed',
        'created_at': '2026-08-01T10:00:00Z',
      }
    ],
    'audit_events': [
      {
        'event_type': 'organisation_data_exported',
        'title': 'Organisation data exported',
        'source_type': 'organisation_export',
        'occurred_at': '2026-08-11T15:00:00Z',
      }
    ],
  },
};
