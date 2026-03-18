class ShippingMethod {
  final int shippingMethodID;
  final String description;
  final bool isDisabled;

  const ShippingMethod({
    required this.shippingMethodID,
    required this.description,
    this.isDisabled = false,
  });

  factory ShippingMethod.fromJson(Map<String, dynamic> json) => ShippingMethod(
        shippingMethodID: (json['shippingMethodID'] as int?) ?? 0,
        description: (json['description'] as String?) ?? '',
        isDisabled: (json['isDisabled'] as bool?) ?? false,
      );
}
