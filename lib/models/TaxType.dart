class TaxType {
  int taxTypeID;
  String? taxCode;
  String? description;
  double? taxRate;
  bool isDisabled;

  TaxType({
    required this.taxTypeID,
    this.taxCode,
    this.description,
    this.taxRate,
    required this.isDisabled,
  });

  factory TaxType.fromJson(Map<String, dynamic> json) {
    return TaxType(
      taxTypeID: json['taxTypeID'] as int,
      taxCode: json['taxCode'] as String?,
      description: json['description'] as String?,
      taxRate: json['taxRate'] != null ? (json['taxRate'] as num).toDouble() : null,
      isDisabled: json['isDisabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taxTypeID': taxTypeID,
      'taxCode': taxCode,
      'description': description,
      'taxRate': taxRate,
      'isDisabled': isDisabled,
    };
  }
}
