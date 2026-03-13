class StockGroup {
  final int id;
  final String description;
  final String shortCode;

  const StockGroup({required this.id, required this.description, required this.shortCode});

  factory StockGroup.fromJson(Map<String, dynamic> json) => StockGroup(
        id: (json['stockGroupID'] as int?) ?? 0,
        description: (json['description'] as String?) ?? '',
        shortCode: (json['shortCode'] as String?) ?? '',
      );
}

class StockType {
  final int id;
  final String description;
  final String shortCode;

  const StockType({required this.id, required this.description, required this.shortCode});

  factory StockType.fromJson(Map<String, dynamic> json) => StockType(
        id: (json['stockTypeID'] as int?) ?? 0,
        description: (json['description'] as String?) ?? '',
        shortCode: (json['shortCode'] as String?) ?? '',
      );
}

class StockCategory {
  final int id;
  final String description;
  final String shortCode;

  const StockCategory({required this.id, required this.description, required this.shortCode});

  factory StockCategory.fromJson(Map<String, dynamic> json) => StockCategory(
        id: (json['stockCategoryID'] as int?) ?? 0,
        description: (json['description'] as String?) ?? '',
        shortCode: (json['shortCode'] as String?) ?? '',
      );
}
