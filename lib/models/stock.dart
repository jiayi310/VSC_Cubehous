import 'pagination.dart';

class Stock {
  final int stockID;
  final String stockCode;
  final String description;
  final String desc2;
  final String baseUOM;
  final double baseUOMPrice1;
  final bool hasBatch;
  final int stockGroupID;
  final int stockTypeID;
  final int stockCategoryID;
  final int taxTypeID;
  final bool isActive;
  final String? image; // base64 string from API

  const Stock({
    this.stockID = 0,
    required this.stockCode,
    required this.description,
    this.desc2 = '',
    required this.baseUOM,
    this.baseUOMPrice1 = 0.0,
    this.hasBatch = false,
    this.stockGroupID = 0,
    this.stockTypeID = 0,
    this.stockCategoryID = 0,
    this.taxTypeID = 0,
    this.isActive = true,
    this.image,
  });

  factory Stock.fromJson(Map<String, dynamic> json) => Stock(
        stockID: (json['stockID'] as int?) ?? 0,
        stockCode: (json['stockCode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        desc2: (json['desc2'] as String?) ?? '',
        baseUOM: (json['baseUOM'] as String?) ?? '',
        baseUOMPrice1: ((json['baseUOMPrice1'] as num?) ?? 0).toDouble(),
        hasBatch: (json['hasBatch'] as bool?) ?? false,
        stockGroupID: (json['stockGroupID'] as int?) ?? 0,
        stockTypeID: (json['stockTypeID'] as int?) ?? 0,
        stockCategoryID: (json['stockCategoryID'] as int?) ?? 0,
        taxTypeID: (json['taxTypeID'] as int?) ?? 0,
        isActive: (json['isActive'] as bool?) ?? true,
        image: json['image'] as String?,
      );
}

class StockResponse {
  final List<Stock>? data;
  final Pagination? pagination;

  const StockResponse({this.data, this.pagination});

  factory StockResponse.fromJson(Map<String, dynamic> json) => StockResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) => Stock.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}
