class PropertySummary {
  const PropertySummary({
    required this.id,
    required this.address,
    required this.postcode,
  });

  factory PropertySummary.fromJson(Map<String, dynamic> json) {
    return PropertySummary(
      id: json['id'] as String,
      address: '${json['address_line_1']}, ${json['town_or_city']}',
      postcode: json['postcode'] as String,
    );
  }

  final String id;
  final String address;
  final String postcode;
}

