class CustomerType {
  final int customerTypeID;
  final String customerType;
  final bool isActive;

  const CustomerType({
    required this.customerTypeID,
    required this.customerType,
    required this.isActive,
  });

  factory CustomerType.fromJson(Map<String, dynamic> json) => CustomerType(
        customerTypeID: (json['customerTypeID'] as int?) ?? 0,
        customerType: (json['description'] as String?) ?? '',
        isActive: !((json['isDisabled'] as bool?) ?? false),
      );
}
