import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

class PortfolioWorkbookBuilder {
  const PortfolioWorkbookBuilder();

  Uint8List build(Map<String, dynamic> payload) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Summary');
    final report = _ReportData(payload);
    final tables = <_TableSpec>[
      report.summary,
      report.properties,
      report.ownership,
      report.compliance,
      report.tenancies,
      report.maintenance,
      report.contractors,
      report.tasks,
      report.expenses,
      report.users,
      report.documents,
      report.auditHistory,
    ];

    for (final table in tables) {
      final sheet = excel[table.name];
      _writeTable(sheet, table, report);
    }
    excel.setDefaultSheet('Summary');
    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('portfolio_report_not_created');
    }
    return _addWorksheetControls(Uint8List.fromList(bytes), tables);
  }

  void _writeTable(Sheet sheet, _TableSpec table, _ReportData report) {
    final lastColumn = _columnName(table.columns.length - 1);
    sheet.merge(
      CellIndex.indexByString('A1'),
      CellIndex.indexByString('${lastColumn}1'),
      customValue: TextCellValue(table.title),
    );
    sheet.merge(
      CellIndex.indexByString('A2'),
      CellIndex.indexByString('${lastColumn}2'),
      customValue: TextCellValue(
        '${report.organisationName} · Exported ${_displayTimestamp(report.exportedAt)}',
      ),
    );
    sheet.cell(CellIndex.indexByString('A1')).cellStyle = _titleStyle;
    sheet.cell(CellIndex.indexByString('A2')).cellStyle = _subtitleStyle;
    sheet.setRowHeight(0, 30);
    sheet.setRowHeight(1, 22);

    sheet.appendRow(List<CellValue?>.filled(table.columns.length, null));
    sheet.appendRow(
      table.columns.map((column) => TextCellValue(column.label)).toList(),
    );
    for (final cell in sheet.row(3)) {
      cell?.cellStyle = _headerStyle;
    }
    sheet.setRowHeight(3, 25);

    if (table.rows.isEmpty) {
      sheet.appendRow([
        TextCellValue('No records in this section.'),
        ...List<CellValue?>.filled(table.columns.length - 1, null),
      ]);
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 4))
          .cellStyle = _emptyStyle;
    } else {
      for (final row in table.rows) {
        sheet.appendRow([
          for (var index = 0; index < table.columns.length; index++)
            _cellValue(row[index], table.columns[index].kind),
        ]);
      }
    }

    for (var rowIndex = 4; rowIndex < sheet.maxRows; rowIndex++) {
      for (var columnIndex = 0;
          columnIndex < table.columns.length;
          columnIndex++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(
            columnIndex: columnIndex,
            rowIndex: rowIndex,
          ),
        );
        cell.cellStyle = _bodyStyle(table.columns[columnIndex].kind);
      }
    }

    for (var columnIndex = 0;
        columnIndex < table.columns.length;
        columnIndex++) {
      sheet.setColumnWidth(
        columnIndex,
        _widthFor(table, columnIndex),
      );
    }
  }
}

class _ReportData {
  _ReportData(this.payload)
      : data = _map(payload['data']),
        recordCounts = _map(payload['record_counts']),
        organisation = _map(payload['organisation']);

  final Map<String, dynamic> payload;
  final Map<String, dynamic> data;
  final Map<String, dynamic> recordCounts;
  final Map<String, dynamic> organisation;

  String get organisationName => _text(organisation['name']) ?? 'Organisation';
  DateTime get exportedAt =>
      _dateTime(payload['exported_at']) ?? DateTime.now().toUtc();

  List<Map<String, dynamic>> rows(String key) => _rows(data[key]);

  Map<String, Map<String, dynamic>> index(String key) => {
        for (final row in rows(key))
          if (_text(row['id']) case final id?) id: row,
      };

  _TableSpec get summary {
    final expenses = rows('expenses');
    final totalExpenses = expenses.fold<int>(
      0,
      (sum, row) => sum + (_integer(row['amount_pence']) ?? 0),
    );
    return _TableSpec(
      name: 'Summary',
      title: 'Portfolio summary',
      columns: const [
        _Column('Measure'),
        _Column('Count', _CellKind.number),
        _Column('Amount', _CellKind.currency),
      ],
      rows: [
        ['Properties', _integer(recordCounts['properties']) ?? 0, null],
        [
          'Compliance records',
          _integer(recordCounts['compliance_records']) ?? 0,
          null,
        ],
        ['Tenancies', _integer(recordCounts['tenancies']) ?? 0, null],
        [
          'Open maintenance issues',
          _openCount(rows('maintenance_issues'), 'state'),
          null,
        ],
        ['Open tasks', _openCount(rows('tasks'), 'state'), null],
        ['Expenses', _integer(recordCounts['expenses']) ?? 0, null],
        ['Total recorded expenses', null, totalExpenses / 100],
        ['Documents', _integer(recordCounts['documents']) ?? 0, null],
        [
          'Users and invitations',
          (_integer(recordCounts['members']) ?? 0) +
              (_integer(recordCounts['invitations']) ?? 0),
          null,
        ],
      ],
    );
  }

  _TableSpec get properties => _TableSpec(
        name: 'Properties',
        title: 'Properties',
        columns: const [
          _Column('Property'),
          _Column('Address line 1'),
          _Column('Address line 2'),
          _Column('Town or city'),
          _Column('County'),
          _Column('Postcode'),
          _Column('Property type'),
          _Column('Bedrooms', _CellKind.number),
          _Column('Status'),
          _Column('Notes'),
          _Column('Created', _CellKind.dateTime),
        ],
        rows: [
          for (final row in rows('properties'))
            [
              _text(row['display_name']) ?? _text(row['address_line_1']),
              row['address_line_1'],
              row['address_line_2'],
              row['town_or_city'],
              row['county'],
              row['postcode'],
              _label(row['property_type']),
              row['bedrooms'],
              _label(row['status']),
              row['notes'],
              row['created_at'],
            ],
        ],
      );

  _TableSpec get ownership {
    final propertyById = index('properties');
    final entityById = index('ownership_entities');
    return _TableSpec(
      name: 'Ownership',
      title: 'Property ownership',
      columns: const [
        _Column('Property'),
        _Column('Ownership entity'),
        _Column('Entity type'),
        _Column('Company number'),
        _Column('Ownership', _CellKind.percentage),
        _Column('Started', _CellKind.date),
        _Column('Ended', _CellKind.date),
      ],
      rows: [
        for (final row in rows('property_ownerships'))
          [
            _propertyName(propertyById[_text(row['property_id'])]),
            _text(entityById[_text(row['ownership_entity_id'])]?['legal_name']),
            _label(
                entityById[_text(row['ownership_entity_id'])]?['entity_type']),
            entityById[_text(row['ownership_entity_id'])]?['company_number'],
            (_number(row['ownership_percentage']) ?? 0) / 100,
            row['ownership_started_on'],
            row['ownership_ended_on'],
          ],
      ],
    );
  }

  _TableSpec get compliance {
    final propertyById = index('properties');
    final requirementById = index('compliance_requirement_types');
    return _TableSpec(
      name: 'Compliance',
      title: 'Compliance register',
      columns: const [
        _Column('Property'),
        _Column('Requirement'),
        _Column('Status'),
        _Column('Issue date', _CellKind.date),
        _Column('Completion date', _CellKind.date),
        _Column('Expiry date', _CellKind.date),
        _Column('Review date', _CellKind.date),
        _Column('Reference'),
        _Column('Notes'),
      ],
      rows: [
        for (final row in rows('compliance_records'))
          [
            _propertyName(propertyById[_text(row['property_id'])]),
            _text(requirementById[_text(row['requirement_type_id'])]?['name']),
            _complianceStatus(row),
            row['issue_date'],
            row['completion_date'],
            row['expiry_date'],
            row['review_date'],
            row['reference_number'],
            row['notes'],
          ],
      ],
    );
  }

  _TableSpec get tenancies {
    final propertyById = index('properties');
    final tenantById = index('tenants');
    final links = rows('tenancy_tenants');
    return _TableSpec(
      name: 'Tenancies',
      title: 'Tenancies',
      columns: const [
        _Column('Property'),
        _Column('Tenants'),
        _Column('Lead tenant'),
        _Column('Start date', _CellKind.date),
        _Column('Fixed-term end', _CellKind.date),
        _Column('Actual end', _CellKind.date),
        _Column('Monthly rent', _CellKind.currency),
        _Column('Rent due day', _CellKind.number),
        _Column('Status'),
        _Column('Notes'),
      ],
      rows: [
        for (final row in rows('tenancies'))
          [
            _propertyName(propertyById[_text(row['property_id'])]),
            _tenantNames(row, links, tenantById, leadOnly: false),
            _tenantNames(row, links, tenantById, leadOnly: true),
            row['start_date'],
            row['fixed_term_end_date'],
            row['actual_end_date'],
            (_integer(row['monthly_rent_pence']) ?? 0) / 100,
            row['rent_due_day'],
            _label(row['status']),
            row['notes'],
          ],
      ],
    );
  }

  _TableSpec get maintenance {
    final propertyById = index('properties');
    final contractorById = index('contractors');
    return _TableSpec(
      name: 'Maintenance',
      title: 'Maintenance register',
      columns: const [
        _Column('Property'),
        _Column('Issue'),
        _Column('Description'),
        _Column('Priority'),
        _Column('Status'),
        _Column('Contractor'),
        _Column('Reported', _CellKind.dateTime),
        _Column('Target date', _CellKind.date),
        _Column('Resolved', _CellKind.dateTime),
        _Column('Estimated cost', _CellKind.currency),
        _Column('Actual cost', _CellKind.currency),
        _Column('Notes'),
      ],
      rows: [
        for (final row in rows('maintenance_issues'))
          [
            _propertyName(propertyById[_text(row['property_id'])]),
            row['title'],
            row['description'],
            _label(row['priority']),
            _label(row['state']),
            contractorById[_text(row['contractor_id'])]?['name'],
            row['reported_at'],
            row['target_date'],
            row['resolved_at'],
            _pounds(row['estimated_cost_pence']),
            _pounds(row['actual_cost_pence']),
            row['notes'],
          ],
      ],
    );
  }

  _TableSpec get contractors => _TableSpec(
        name: 'Contractors',
        title: 'Contractor directory',
        columns: const [
          _Column('Contractor'),
          _Column('Trade'),
          _Column('Email'),
          _Column('Phone'),
          _Column('Status'),
          _Column('Notes'),
          _Column('Created', _CellKind.dateTime),
        ],
        rows: [
          for (final row in rows('contractors'))
            [
              row['name'],
              row['trade'],
              row['email'],
              row['phone'],
              _label(row['status']),
              row['notes'],
              row['created_at'],
            ],
        ],
      );

  _TableSpec get tasks {
    final propertyById = index('properties');
    return _TableSpec(
      name: 'Tasks',
      title: 'Tasks',
      columns: const [
        _Column('Property'),
        _Column('Task'),
        _Column('Description'),
        _Column('Priority'),
        _Column('Status'),
        _Column('Due date', _CellKind.date),
        _Column('Source'),
        _Column('Completed', _CellKind.dateTime),
        _Column('Created', _CellKind.dateTime),
      ],
      rows: [
        for (final row in rows('tasks'))
          [
            _propertyName(propertyById[_text(row['property_id'])]),
            row['title'],
            row['description'],
            _label(row['priority']),
            _label(row['state']),
            row['due_date'],
            _label(row['source_type']),
            row['completed_at'],
            row['created_at'],
          ],
      ],
    );
  }

  _TableSpec get expenses {
    final propertyById = index('properties');
    final entityById = index('ownership_entities');
    return _TableSpec(
      name: 'Expenses',
      title: 'Property expenses',
      columns: const [
        _Column('Expense date', _CellKind.date),
        _Column('Property'),
        _Column('Ownership entity'),
        _Column('Supplier'),
        _Column('Description'),
        _Column('Category'),
        _Column('Amount', _CellKind.currency),
        _Column('VAT amount', _CellKind.currency),
        _Column('VAT treatment'),
        _Column('Payment status'),
        _Column('Notes'),
      ],
      rows: [
        for (final row in rows('expenses'))
          [
            row['expense_date'],
            _propertyName(propertyById[_text(row['property_id'])]),
            entityById[_text(row['ownership_entity_id'])]?['legal_name'],
            row['supplier'],
            row['description'],
            _label(row['category']),
            _pounds(row['amount_pence']),
            _pounds(row['vat_amount_pence']),
            _label(row['vat_treatment']),
            _label(row['payment_status']),
            row['notes'],
          ],
      ],
    );
  }

  _TableSpec get users => _TableSpec(
        name: 'Users',
        title: 'Users and invitations',
        columns: const [
          _Column('Type'),
          _Column('Name'),
          _Column('Email'),
          _Column('Role'),
          _Column('Status'),
          _Column('Created', _CellKind.dateTime),
          _Column('Expires', _CellKind.dateTime),
        ],
        rows: [
          for (final row in rows('members'))
            [
              'User',
              row['display_name'],
              row['email'],
              _label(row['role']),
              'Active',
              row['created_at'],
              null,
            ],
          for (final row in rows('invitations'))
            [
              'Invitation',
              null,
              row['email'],
              _label(row['role']),
              _label(row['status'] ?? row['state'] ?? 'pending'),
              row['created_at'],
              row['expires_at'],
            ],
        ],
      );

  _TableSpec get documents {
    final propertyById = index('properties');
    return _TableSpec(
      name: 'Document Register',
      title: 'Document register',
      columns: const [
        _Column('File name'),
        _Column('Property'),
        _Column('Scope'),
        _Column('Document type'),
        _Column('File type'),
        _Column('Size', _CellKind.number),
        _Column('Status'),
        _Column('Confirmed', _CellKind.dateTime),
        _Column('Created', _CellKind.dateTime),
      ],
      rows: [
        for (final row in rows('documents'))
          [
            row['original_filename'],
            _propertyName(propertyById[_text(row['property_id'])]),
            _label(row['scope']),
            _label(row['document_type']),
            row['mime_type'],
            row['size_bytes'],
            _label(row['state']),
            row['confirmed_at'],
            row['created_at'],
          ],
      ],
    );
  }

  _TableSpec get auditHistory => _TableSpec(
        name: 'Audit History',
        title: 'Organisation audit history',
        columns: const [
          _Column('Occurred', _CellKind.dateTime),
          _Column('Event'),
          _Column('Title'),
          _Column('Description'),
          _Column('Source type'),
        ],
        rows: [
          for (final row in rows('audit_events'))
            [
              row['occurred_at'],
              _label(row['event_type']),
              row['title'],
              row['description'],
              _label(row['source_type']),
            ],
        ],
      );
}

enum _CellKind { text, number, currency, percentage, date, dateTime }

class _Column {
  const _Column(this.label, [this.kind = _CellKind.text]);
  final String label;
  final _CellKind kind;
}

class _TableSpec {
  const _TableSpec({
    required this.name,
    required this.title,
    required this.columns,
    required this.rows,
  });

  final String name;
  final String title;
  final List<_Column> columns;
  final List<List<dynamic>> rows;
}

final _navy = ExcelColor.fromHexString('FF082333');
final _blue = ExcelColor.fromHexString('FF174A65');
final _gold = ExcelColor.fromHexString('FFF5B521');
final _pale = ExcelColor.fromHexString('FFF3F6F7');
final _muted = ExcelColor.fromHexString('FF6D8190');
final _border = Border(
  borderStyle: BorderStyle.Thin,
  borderColorHex: ExcelColor.fromHexString('FFDCE4E8'),
);

final _titleStyle = CellStyle(
  backgroundColorHex: _navy,
  fontColorHex: ExcelColor.white,
  fontFamily: getFontFamily(FontFamily.Arial),
  fontSize: 18,
  bold: true,
  verticalAlign: VerticalAlign.Center,
);
final _subtitleStyle = CellStyle(
  backgroundColorHex: _navy,
  fontColorHex: _gold,
  fontFamily: getFontFamily(FontFamily.Arial),
  fontSize: 10,
  verticalAlign: VerticalAlign.Center,
);
final _headerStyle = CellStyle(
  backgroundColorHex: _blue,
  fontColorHex: ExcelColor.white,
  fontFamily: getFontFamily(FontFamily.Arial),
  bold: true,
  verticalAlign: VerticalAlign.Center,
  textWrapping: TextWrapping.WrapText,
  bottomBorder: _border,
);
final _emptyStyle = CellStyle(
  fontColorHex: _muted,
  fontFamily: getFontFamily(FontFamily.Arial),
  italic: true,
);

CellStyle _bodyStyle(_CellKind kind) => CellStyle(
      backgroundColorHex: _pale,
      fontFamily: getFontFamily(FontFamily.Arial),
      verticalAlign: VerticalAlign.Top,
      textWrapping: TextWrapping.WrapText,
      bottomBorder: _border,
      horizontalAlign: switch (kind) {
        _CellKind.number ||
        _CellKind.currency ||
        _CellKind.percentage =>
          HorizontalAlign.Right,
        _ => HorizontalAlign.Left,
      },
      numberFormat: switch (kind) {
        _CellKind.currency =>
          const CustomNumericNumFormat(formatCode: '£#,##0.00'),
        _CellKind.percentage =>
          const CustomNumericNumFormat(formatCode: '0.00%'),
        _CellKind.date =>
          const CustomDateTimeNumFormat(formatCode: 'dd/mm/yyyy'),
        _CellKind.dateTime =>
          const CustomDateTimeNumFormat(formatCode: 'dd/mm/yyyy hh:mm'),
        _CellKind.number => const CustomNumericNumFormat(formatCode: '#,##0'),
        _ => NumFormat.standard_0,
      },
    );

CellValue? _cellValue(dynamic value, _CellKind kind) {
  if (value == null || value == '') return null;
  switch (kind) {
    case _CellKind.date:
      final date = _dateTime(value);
      return date == null
          ? TextCellValue(value.toString())
          : DateCellValue(year: date.year, month: date.month, day: date.day);
    case _CellKind.dateTime:
      final date = _dateTime(value)?.toLocal();
      return date == null
          ? TextCellValue(value.toString())
          : DateTimeCellValue.fromDateTime(date);
    case _CellKind.number:
    case _CellKind.currency:
    case _CellKind.percentage:
      final number = _number(value);
      if (number == null) return TextCellValue(value.toString());
      if (number == number.roundToDouble() && kind == _CellKind.number) {
        return IntCellValue(number.toInt());
      }
      return DoubleCellValue(number.toDouble());
    case _CellKind.text:
      return TextCellValue(value.toString());
  }
}

Uint8List _addWorksheetControls(Uint8List bytes, List<_TableSpec> tables) {
  final decoded = ZipDecoder().decodeBytes(bytes);
  final rebuilt = Archive();
  for (final file in decoded.files) {
    var content = file.content as List<int>;
    final match =
        RegExp(r'^xl/worksheets/sheet(\d+)\.xml$').firstMatch(file.name);
    if (match != null) {
      final sheetIndex = int.parse(match.group(1)!) - 1;
      if (sheetIndex >= 0 && sheetIndex < tables.length) {
        var xml = utf8.decode(content);
        xml = xml.replaceFirstMapped(
          RegExp(r'<sheetView([^>]*)/>'),
          (match) =>
              '<sheetView${match.group(1)}><pane ySplit="4" topLeftCell="A5" activePane="bottomLeft" state="frozen"/></sheetView>',
        );
        final table = tables[sheetIndex];
        if (table.rows.isNotEmpty) {
          final lastColumn = _columnName(table.columns.length - 1);
          final lastRow = table.rows.length + 4;
          xml = xml.replaceFirst(
            '</sheetData>',
            '</sheetData><autoFilter ref="A4:$lastColumn$lastRow"/>',
          );
        }
        content = utf8.encode(xml);
      }
    }
    final copy = ArchiveFile(file.name, content.length, content)
      ..compress = file.compress
      ..mode = file.mode
      ..lastModTime = file.lastModTime;
    rebuilt.addFile(copy);
  }
  return Uint8List.fromList(ZipEncoder().encode(rebuilt)!);
}

double _widthFor(_TableSpec table, int columnIndex) {
  final values = <String>[
    table.columns[columnIndex].label,
    for (final row in table.rows)
      if (columnIndex < row.length && row[columnIndex] != null)
        row[columnIndex].toString(),
  ];
  final longest = values.fold<int>(
      0, (max, value) => value.length > max ? value.length : max);
  return (longest + 3).clamp(11, 34).toDouble();
}

String _columnName(int index) {
  var value = index + 1;
  var result = '';
  while (value > 0) {
    value--;
    result = String.fromCharCode(65 + value % 26) + result;
    value ~/= 26;
  }
  return result;
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
List<Map<String, dynamic>> _rows(dynamic value) => value is List
    ? value.whereType<Map>().map((row) => row.cast<String, dynamic>()).toList()
    : <Map<String, dynamic>>[];
String? _text(dynamic value) => value?.toString();
num? _number(dynamic value) => value is num ? value : num.tryParse('$value');
int? _integer(dynamic value) => _number(value)?.toInt();
double? _pounds(dynamic pence) =>
    _integer(pence) == null ? null : _integer(pence)! / 100;
DateTime? _dateTime(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());
String _label(dynamic value) => (value?.toString() ?? '')
    .replaceAll('_', ' ')
    .split(' ')
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
String _propertyName(Map<String, dynamic>? property) =>
    _text(property?['display_name']) ??
    _text(property?['address_line_1']) ??
    'Organisation';
String _displayTimestamp(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

int _openCount(List<Map<String, dynamic>> rows, String field) => rows
    .where((row) =>
        !const {'completed', 'resolved', 'cancelled'}.contains(row[field]))
    .length;

String _tenantNames(
  Map<String, dynamic> tenancy,
  List<Map<String, dynamic>> links,
  Map<String, Map<String, dynamic>> tenantById, {
  required bool leadOnly,
}) {
  final tenancyId = _text(tenancy['id']);
  return links
      .where((link) =>
          _text(link['tenancy_id']) == tenancyId &&
          (!leadOnly || link['is_lead'] == true))
      .map((link) =>
          _text(tenantById[_text(link['tenant_id'])]?['display_name']))
      .whereType<String>()
      .join(', ');
}

String _complianceStatus(Map<String, dynamic> row) {
  final override = _text(row['state_override']);
  if (override != null) return _label(override);
  final expiry = _dateTime(row['expiry_date']);
  if (expiry == null) return 'Recorded';
  final today = DateTime.now();
  final date = DateTime(expiry.year, expiry.month, expiry.day);
  final start = DateTime(today.year, today.month, today.day);
  if (date.isBefore(start)) return 'Expired';
  if (!date.isAfter(start.add(const Duration(days: 45)))) return 'Due soon';
  return 'Current';
}
