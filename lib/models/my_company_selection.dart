class CompanySelection {
  final int userMappingID;
  final String userType;
  final int companyID;
  final String companyName;
  final int licenseID;
  final String licenseCode;
  final bool isDeletedTemporarily;

  const CompanySelection({
    required this.userMappingID,
    required this.userType,
    required this.companyID,
    required this.companyName,
    required this.licenseID,
    required this.licenseCode,
    required this.isDeletedTemporarily
  });

  factory CompanySelection.fromJson(Map<String, dynamic> json) {
    return CompanySelection(
      userMappingID: (json['userMappingID'] as int?) ?? 0,
      userType: (json['userType'] as String?) ?? '',
      companyID: (json['companyID'] as int?) ?? 0,
      companyName: (json['companyName'] as String?) ?? '',
      licenseID: (json['licenseID'] as int?) ?? 0,
      licenseCode: (json['licenseCode'] as String?) ?? '',
      isDeletedTemporarily: (json['isDeletedTemporarily'] as bool?) ?? false,
    );
  }
}
