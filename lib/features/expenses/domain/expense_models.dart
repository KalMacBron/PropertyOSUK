class ExpenseCategory {
  const ExpenseCategory(this.code, this.label);
  final String code;
  final String label;
}

const expenseCategories = <ExpenseCategory>[
  ExpenseCategory('compliance_certificates', 'Compliance and certificates'),
  ExpenseCategory('repairs_maintenance', 'Repairs and maintenance'),
  ExpenseCategory('insurance', 'Insurance'),
  ExpenseCategory('utilities_council_tax', 'Utilities and council tax'),
  ExpenseCategory(
    'management_professional_fees',
    'Management and professional fees',
  ),
  ExpenseCategory('mortgage_finance_costs', 'Mortgage and finance costs'),
  ExpenseCategory('improvements', 'Improvements'),
  ExpenseCategory('other', 'Other'),
];

String expenseCategoryLabel(String code) => expenseCategories
    .firstWhere(
      (category) => category.code == code,
      orElse: () => const ExpenseCategory('other', 'Other'),
    )
    .label;

class ExpenseProperty {
  const ExpenseProperty({
    required this.id,
    required this.name,
    required this.postcode,
    required this.owners,
  });

  factory ExpenseProperty.fromJson(Map<String, dynamic> json) {
    final ownerships = json['property_ownerships'] as List<dynamic>? ?? [];
    return ExpenseProperty(
      id: json['id'] as String,
      name: (json['display_name'] as String?)?.trim().isNotEmpty == true
          ? json['display_name'] as String
          : json['address_line_1'] as String,
      postcode: json['postcode'] as String,
      owners: ownerships
          .map((row) => ExpenseOwner.fromJson(row as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String name;
  final String postcode;
  final List<ExpenseOwner> owners;
}

class ExpenseOwner {
  const ExpenseOwner({required this.id, required this.name});

  factory ExpenseOwner.fromJson(Map<String, dynamic> json) {
    final entity = json['ownership_entities'] as Map<String, dynamic>;
    return ExpenseOwner(
      id: entity['id'] as String,
      name: entity['legal_name'] as String,
    );
  }

  final String id;
  final String name;
}

class PropertyExpense {
  const PropertyExpense({
    required this.id,
    required this.organisationId,
    required this.propertyId,
    required this.propertyName,
    required this.ownershipEntityId,
    required this.ownershipEntityName,
    required this.expenseDate,
    required this.description,
    required this.category,
    required this.amountPence,
    required this.vatTreatment,
    required this.paymentStatus,
    required this.createdAt,
    this.supplier,
    this.vatAmountPence,
    this.notes,
    this.complianceRecordId,
    this.complianceRequirement,
    this.certificateReference,
    this.evidence,
  });

  factory PropertyExpense.fromJson(Map<String, dynamic> json) {
    final property = json['properties'] as Map<String, dynamic>;
    final owner = json['ownership_entities'] as Map<String, dynamic>;
    final compliance =
        json['property_compliance_records'] as Map<String, dynamic>?;
    final documents = json['documents'] as List<dynamic>? ?? [];
    return PropertyExpense(
      id: json['id'] as String,
      organisationId: json['organisation_id'] as String,
      propertyId: json['property_id'] as String,
      propertyName:
          (property['display_name'] as String?)?.trim().isNotEmpty == true
              ? property['display_name'] as String
              : property['address_line_1'] as String,
      ownershipEntityId: json['ownership_entity_id'] as String,
      ownershipEntityName: owner['legal_name'] as String,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      supplier: json['supplier'] as String?,
      description: json['description'] as String,
      category: json['category'] as String,
      amountPence: json['amount_pence'] as int,
      vatTreatment: json['vat_treatment'] as String,
      vatAmountPence: json['vat_amount_pence'] as int?,
      paymentStatus: json['payment_status'] as String,
      notes: json['notes'] as String?,
      complianceRecordId: json['compliance_record_id'] as String?,
      complianceRequirement: compliance == null
          ? null
          : (compliance['compliance_requirement_types']
              as Map<String, dynamic>?)?['name'] as String?,
      certificateReference: compliance?['reference_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      evidence: documents.isEmpty
          ? null
          : ExpenseEvidence.fromJson(documents.first as Map<String, dynamic>),
    );
  }

  final String id;
  final String organisationId;
  final String propertyId;
  final String propertyName;
  final String ownershipEntityId;
  final String ownershipEntityName;
  final DateTime expenseDate;
  final String? supplier;
  final String description;
  final String category;
  final int amountPence;
  final String vatTreatment;
  final int? vatAmountPence;
  final String paymentStatus;
  final String? notes;
  final String? complianceRecordId;
  final String? complianceRequirement;
  final String? certificateReference;
  final DateTime createdAt;
  final ExpenseEvidence? evidence;
}

class ExpenseEvidence {
  const ExpenseEvidence({
    required this.id,
    required this.filename,
    required this.bucket,
    required this.path,
  });

  factory ExpenseEvidence.fromJson(Map<String, dynamic> json) =>
      ExpenseEvidence(
        id: json['id'] as String,
        filename: json['original_filename'] as String,
        bucket: json['storage_bucket'] as String,
        path: json['storage_path'] as String,
      );

  final String id;
  final String filename;
  final String bucket;
  final String path;
}

class ExpenseFilters {
  const ExpenseFilters({
    this.propertyId,
    this.ownerId,
    this.category,
    this.paymentStatus,
    this.from,
    this.to,
  });

  final String? propertyId;
  final String? ownerId;
  final String? category;
  final String? paymentStatus;
  final DateTime? from;
  final DateTime? to;

  bool matches(PropertyExpense expense) {
    if (propertyId != null && expense.propertyId != propertyId) return false;
    if (ownerId != null && expense.ownershipEntityId != ownerId) return false;
    if (category != null && expense.category != category) return false;
    if (paymentStatus != null && expense.paymentStatus != paymentStatus) {
      return false;
    }
    final day = DateTime(
      expense.expenseDate.year,
      expense.expenseDate.month,
      expense.expenseDate.day,
    );
    if (from != null && day.isBefore(from!)) return false;
    if (to != null && day.isAfter(to!)) return false;
    return true;
  }
}

int parsePoundsToPence(String input) {
  final value = input.trim();
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
    throw const FormatException(
        'Enter a valid amount with up to two decimals.');
  }
  final parts = value.split('.');
  final pounds = int.parse(parts.first);
  final pennies =
      parts.length == 1 ? 0 : int.parse(parts.last.padRight(2, '0'));
  final result = pounds * 100 + pennies;
  if (result <= 0)
    throw const FormatException('Amount must be greater than £0.');
  return result;
}

String pounds(int pence) => '£${(pence / 100).toStringAsFixed(2)}';

String csvForExpenses(Iterable<PropertyExpense> expenses) {
  String cell(Object? value) {
    var text = value?.toString() ?? '';
    if (RegExp(r'^[=+\-@]').hasMatch(text)) text = "'$text";
    return '"${text.replaceAll('"', '""')}"';
  }

  final rows = <List<Object?>>[
    [
      'Expense date',
      'Property',
      'Ownership entity',
      'Supplier',
      'Description',
      'Category',
      'Net amount',
      'VAT amount',
      'Total amount',
      'Payment status',
      'Compliance requirement',
      'Certificate reference',
      'Notes',
    ],
    ...expenses.map((expense) {
      final vat = expense.vatAmountPence;
      final net = vat == null ? null : expense.amountPence - vat;
      return [
        expense.expenseDate.toIso8601String().substring(0, 10),
        expense.propertyName,
        expense.ownershipEntityName,
        expense.supplier,
        expense.description,
        expenseCategoryLabel(expense.category),
        net == null ? '' : (net / 100).toStringAsFixed(2),
        vat == null ? '' : (vat / 100).toStringAsFixed(2),
        (expense.amountPence / 100).toStringAsFixed(2),
        expense.paymentStatus,
        expense.complianceRequirement,
        expense.certificateReference,
        expense.notes,
      ];
    }),
  ];
  return '\uFEFF${rows.map((row) => row.map(cell).join(',')).join('\r\n')}';
}
