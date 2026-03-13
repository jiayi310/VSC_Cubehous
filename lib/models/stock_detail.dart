double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class StockBarcodeDto {
  final int stockBarcodeID;
  final String barcode;
  final String description;

  const StockBarcodeDto({
    required this.stockBarcodeID,
    required this.barcode,
    required this.description,
  });

  factory StockBarcodeDto.fromJson(Map<String, dynamic> json) => StockBarcodeDto(
        stockBarcodeID: (json['stockBarcodeID'] as int?) ?? 0,
        barcode: (json['barcode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
      );
}

class StockUOMDto {
  final int stockUOMID;
  final String uom;
  final double shelf;
  final double rate;
  final double price1;
  final double price2;
  final double price3;
  final double price4;
  final double price5;
  final double price6;
  final double cost;
  final double minSalePrice;
  final double maxSalePrice;
  final double reorderLevel;
  final double reorderQty;
  final List<StockBarcodeDto> stockBarcodeDtoList;

  const StockUOMDto({
    required this.stockUOMID,
    required this.uom,
    required this.shelf,
    required this.rate,
    required this.price1,
    required this.price2,
    required this.price3,
    required this.price4,
    required this.price5,
    required this.price6,
    required this.cost,
    required this.minSalePrice,
    required this.maxSalePrice,
    required this.reorderLevel,
    required this.reorderQty,
    required this.stockBarcodeDtoList,
  });

  factory StockUOMDto.fromJson(Map<String, dynamic> json) => StockUOMDto(
        stockUOMID: (json['stockUOMID'] as int?) ?? 0,
        uom: (json['uom'] as String?) ?? '',
        shelf: _toDouble(json['shelf']),
        rate: _toDouble(json['rate']),
        price1: _toDouble(json['price']), // API field is 'price'
        price2: _toDouble(json['price2']),
        price3: _toDouble(json['price3']),
        price4: _toDouble(json['price4']),
        price5: _toDouble(json['price5']),
        price6: _toDouble(json['price6']),
        cost: _toDouble(json['cost']),
        minSalePrice: _toDouble(json['minSalePrice']),
        maxSalePrice: _toDouble(json['maxSalePrice']),
        reorderLevel: _toDouble(json['reorderLevel']),
        reorderQty: _toDouble(json['reorderQty']),
        stockBarcodeDtoList: (json['stockBarcodeDtoList'] as List<dynamic>?)
                ?.map((e) => StockBarcodeDto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

}

class StockBatchDto {
  final int stockBatchID;
  final String batchNo;
  final String manufacturedDateOnly;
  final String expiryDateOnly;

  const StockBatchDto({
    required this.stockBatchID,
    required this.batchNo,
    required this.manufacturedDateOnly,
    required this.expiryDateOnly,
  });

  factory StockBatchDto.fromJson(Map<String, dynamic> json) => StockBatchDto(
        stockBatchID: (json['stockBatchID'] as int?) ?? 0,
        batchNo: (json['batchNo'] as String?) ?? '',
        manufacturedDateOnly: (json['manufacturedDateOnly'] as String?) ?? '',
        expiryDateOnly: (json['expiryDateOnly'] as String?) ?? '',
      );
}

class StockDetail {
  final int stockID;
  final String stockCode;
  final String description;
  final String desc2;
  final String? image;
  final String baseUOM;
  final String salesUOM;
  final bool hasBatch;
  final bool isActive;
  final String stockGroup;
  final String stockType;
  final String stockCategory;
  final String taxCode;
  final String supplierCode;
  final double taxRate;
  final List<StockUOMDto> stockUOMDtoList;
  final List<StockBatchDto> stockBatchDtoList;

  const StockDetail({
    required this.stockID,
    required this.stockCode,
    required this.description,
    required this.desc2,
    this.image,
    required this.baseUOM,
    required this.salesUOM,
    required this.hasBatch,
    required this.isActive,
    required this.stockGroup,
    required this.stockType,
    required this.stockCategory,
    required this.taxCode,
    required this.supplierCode,
    required this.taxRate,
    required this.stockUOMDtoList,
    required this.stockBatchDtoList,
  });

  factory StockDetail.fromJson(Map<String, dynamic> json) => StockDetail(
        stockID: (json['stockID'] as int?) ?? 0,
        stockCode: (json['stockCode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        desc2: (json['desc2'] as String?) ?? '',
        image: json['image'] as String?,
        baseUOM: (json['baseUOM'] as String?) ?? '',
        salesUOM: (json['salesUOM'] as String?) ?? '',
        hasBatch: (json['hasBatch'] as bool?) ?? false,
        isActive: (json['isActive'] as bool?) ?? true,
        stockGroup: (json['stockGroup'] as String?) ?? '',
        stockType: (json['stockType'] as String?) ?? '',
        stockCategory: (json['stockCategory'] as String?) ?? '',
        taxCode: (json['taxCode'] as String?) ?? '',
        supplierCode: (json['supplierCode'] as String?) ?? '',
        taxRate: _toDouble(json['taxRate']),
        stockUOMDtoList: (json['stockUOMDtoList'] as List<dynamic>?)
                ?.map((e) => StockUOMDto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        stockBatchDtoList: (json['stockBatchDtoList'] as List<dynamic>?)
                ?.map((e) => StockBatchDto.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class StockSpecificBalance {
  final String batchNo;
  final String storageCode;
  final String storageName;
  final double qty;

  const StockSpecificBalance({
    required this.batchNo,
    required this.storageCode,
    required this.storageName,
    required this.qty,
  });

  factory StockSpecificBalance.fromJson(Map<String, dynamic> json) =>
      StockSpecificBalance(
        batchNo: (json['batchNo'] as String?) ?? '',
        storageCode: (json['storageCode'] as String?) ?? '',
        storageName: (json['storageName'] as String?) ?? '',
        qty: _toDouble(json['qty']),
      );
}
