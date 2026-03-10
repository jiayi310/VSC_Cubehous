class CompanySelection {
  final int userMappingID;
  final int companyID;
  final String companyName;
  final int userTypeID;
  final String? type;

  const CompanySelection({
    required this.userMappingID,
    required this.companyID,
    required this.companyName,
    required this.userTypeID,
    this.type,
  });

  factory CompanySelection.fromJson(Map<String, dynamic> json) {
    return CompanySelection(
      userMappingID: (json['userMappingID'] as int?) ?? 0,
      companyID: (json['companyID'] as int?) ?? 0,
      companyName: (json['companyName'] as String?) ?? '',
      userTypeID: (json['userTypeID'] as int?) ?? 0,
      type: json['type'] as String?,
    );
  }
}
