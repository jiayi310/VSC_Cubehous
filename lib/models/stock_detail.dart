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

/// One row from GetStockBalance — total qty per location.
class StockLocationBalance {
  final int stockBalanceID;
  final int locationID;
  final String location;
  final double qty;

  const StockLocationBalance({
    required this.stockBalanceID,
    required this.locationID,
    required this.location,
    required this.qty,
  });

  factory StockLocationBalance.fromJson(Map<String, dynamic> json) =>
      StockLocationBalance(
        stockBalanceID: (json['stockBalanceID'] as int?) ?? 0,
        locationID: (json['locationID'] as int?) ?? 0,
        location: (json['location'] as String?) ?? '',
        qty: _toDouble(json['qty']),
      );
}

/// One row from GetSpecificStockBalance — storage + batch detail.
class StockSpecificBalance {
  final double wmsQty;
  final int? stockBatchID;
  final String? batchNo;
  final String? batchExpiryDate;
  final int locationID;
  final String location;
  final int storageID;
  final String storageCode;

  const StockSpecificBalance({
    required this.wmsQty,
    this.stockBatchID,
    this.batchNo,
    this.batchExpiryDate,
    required this.locationID,
    required this.location,
    required this.storageID,
    required this.storageCode,
  });

  factory StockSpecificBalance.fromJson(Map<String, dynamic> json) =>
      StockSpecificBalance(
        wmsQty: _toDouble(json['wmsQty']),
        stockBatchID: json['stockBatchID'] as int?,
        batchNo: json['batchNo'] as String?,
        batchExpiryDate: json['batchExpiryDate'] as String?,
        locationID: (json['locationID'] as int?) ?? 0,
        location: (json['location'] as String?) ?? '',
        storageID: (json['storageID'] as int?) ?? 0,
        storageCode: (json['storageCode'] as String?) ?? '',
      );
}

class StockHistoryItem {
  final String docType;
  final String docNo;
  final String docDate;
  final String customerSupplierCode;
  final String customerSupplierName;
  final String uom;
  final double qty;
  final double unitPrice;
  final double discount;
  final double total;
  final String? location;

  const StockHistoryItem({
    required this.docType,
    required this.docNo,
    required this.docDate,
    required this.customerSupplierCode,
    required this.customerSupplierName,
    required this.uom,
    required this.qty,
    required this.unitPrice,
    required this.discount,
    required this.total,
    this.location,
  });

  factory StockHistoryItem.fromJson(Map<String, dynamic> json) =>
      StockHistoryItem(
        docType: (json['docType'] as String?) ?? '',
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        customerSupplierCode: (json['customerSupplierCode'] as String?) ?? '',
        customerSupplierName: (json['customerSupplierName'] as String?) ?? '',
        uom: (json['uom'] as String?) ?? '',
        qty: _toDouble(json['qty']),
        unitPrice: _toDouble(json['unitPrice']),
        discount: _toDouble(json['discount']),
        total: _toDouble(json['total']),
        location: json['location'] as String?,
      );
}
