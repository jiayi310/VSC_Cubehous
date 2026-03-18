import 'tax_type.dart';
import 'suppplier.dart';

class Stock {
  int? stockID;
  String? stockCode;
  String? description;
  String? desc2;
  String? image;
  String? baseUOM;
  String? salesUOM;
  bool? hasBatch;
  bool? isActive;
  String? lastModifiedDateTime;
  int? lastModifiedUserID;
  String? createdDateTime;
  int? createdUserID;
  int? stockGroupID;
  String? stockGroupDescription;
  int? stockTypeID;
  String? stockTypeDescription;
  int? stockCategoryID;
  String? stockCategoryDescription;
  int? taxTypeID;
  String? taxCode;
  int? companyID;
  double? baseUOMPrice1;
  String? batchNo;
  double? baseUOMCost;

  List<dynamic>? paginationOpt;

  Stock(
      {this.stockID,
      this.stockCode,
      this.description,
      this.desc2,
      this.image,
      this.baseUOM,
      this.salesUOM,
      this.hasBatch,
      this.isActive,
      this.lastModifiedDateTime,
      this.lastModifiedUserID,
      this.createdDateTime,
      this.createdUserID,
      this.stockGroupID,
      this.stockGroupDescription,
      this.stockTypeID,
      this.stockTypeDescription,
      this.stockCategoryID,
      this.stockCategoryDescription,
      this.taxTypeID,
      this.taxCode,
      this.companyID,
      this.baseUOMPrice1,
      this.batchNo,
      this.baseUOMCost});

  // Method to convert StockItem to Stock
  static Stock fromStockItem(StockItem stockItem) {
    return Stock(
        stockID: stockItem.stockID,
        stockCode: stockItem.stockCode,
        description: stockItem.description,
        desc2: stockItem.desc2,
        image: stockItem.image,
        baseUOM: stockItem.baseUOM,
        salesUOM: stockItem.salesUOM,
        hasBatch: stockItem.hasBatch,
        isActive: stockItem.isActive,
        lastModifiedDateTime: stockItem.lastModifiedDateTime.toIso8601String(),
        lastModifiedUserID: stockItem.lastModifiedUserID,
        createdDateTime: stockItem.createdDateTime.toIso8601String(),
        createdUserID: stockItem.createdUserID,
        stockGroupID: stockItem.stockGroupID,
        stockGroupDescription: stockItem.stockGroup,
        stockTypeID: stockItem.stockTypeID,
        stockTypeDescription: stockItem.stockType,
        stockCategoryID: stockItem.stockCategoryID,
        stockCategoryDescription: stockItem.stockCategory,
        taxTypeID: stockItem.taxTypeID,
        taxCode: stockItem.taxType,
        companyID: stockItem.companyID,
        baseUOMPrice1: stockItem.baseUOMPrice1,
        batchNo: '',
        baseUOMCost: stockItem.baseUOMCost);
  }

  // Method to create Stock instance from JSON
  // Stock.fromJson(Map<String, dynamic> json) {
  //   if (json['paginationOpt'] != null) {
  //     paginationOpt = <PaginationOpt>[];
  //     json['paginationOpt'].forEach((v) {
  //       paginationOpt!.add(new PaginationOpt.fromJson(v));
  //     });
  //   }
  //   if (json['data'] != null) {
  //     stockID = json['stockID'];
  //     stockCode = json['stockCode'];
  //     description = json['description'];
  //     desc2 = json['desc2'];
  //     image = json['image'];
  //     baseUOM = json['baseUOM'];
  //     salesUOM = json['salesUOM'];
  //     hasBatch = json['hasBatch'];
  //     isActive = json['isActive'];
  //     lastModifiedDateTime = json['lastModifiedDateTime'];
  //     lastModifiedUserID = json['lastModifiedUserID'];
  //     createdDateTime = json['createdDateTime'];
  //     createdUserID = json['createdUserID'];
  //     stockGroupID = json['stockGroupID'];
  //     stockGroupDescription = json['stockGroupDescription'];
  //     stockTypeID = json['stockTypeID'];
  //     stockTypeDescription = json['stockTypeDescription'];
  //     stockCategoryID = json['stockCategoryID'];
  //     stockCategoryDescription = json['stockCategoryDescription'];
  //     taxTypeID = json['taxTypeID'];
  //     taxCode = json['taxCode'];
  //     companyID = json['companyID'];
  //     baseUOMPrice1 = json['baseUOMPrice1'];
  //   }
  // }

  // Convert Stock instance to JSON

  Stock.fromJson(Map<String, dynamic> json) {
    stockID = json['stockID'];
    stockCode = json['stockCode'];
    description = json['description'];
    desc2 = json['desc2'];
    image = json['image'];
    baseUOM = json['baseUOM'];
    salesUOM = json['salesUOM'];
    hasBatch = json['hasBatch'];
    isActive = json['isActive'];
    lastModifiedDateTime = json['lastModifiedDateTime'];
    lastModifiedUserID = json['lastModifiedUserID'];
    createdDateTime = json['createdDateTime'];
    createdUserID = json['createdUserID'];
    stockGroupID = json['stockGroupID'];
    stockGroupDescription = json['stockGroupDescription'];
    stockTypeID = json['stockTypeID'];
    stockTypeDescription = json['stockTypeDescription'];
    stockCategoryID = json['stockCategoryID'];
    stockCategoryDescription = json['stockCategoryDescription'];
    taxTypeID = json['taxTypeID'];
    taxCode = json['taxCode'];
    baseUOMPrice1 = json['baseUOMPrice1']?.toDouble();
    baseUOMCost = json['baseUOMCost']?.toDouble();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (paginationOpt != null) {
      data['PaginationOpt'] =
          paginationOpt!.map((v) => v.toJson()).toList();
    }
    data['stockID'] = stockID;
    data['stockCode'] = stockCode;
    data['description'] = description;
    data['desc2'] = desc2;
    data['image'] = image;
    data['baseUOM'] = baseUOM;
    data['salesUOM'] = salesUOM;
    data['hasBatch'] = hasBatch;
    data['isActive'] = isActive;
    data['lastModifiedDateTime'] = lastModifiedDateTime;
    data['lastModifiedUserID'] = lastModifiedUserID;
    data['createdDateTime'] = createdDateTime;
    data['createdUserID'] = createdUserID;
    data['stockGroupID'] = stockGroupID;
    data['stockGroupDescription'] = stockGroupDescription;
    data['stockTypeID'] = stockTypeID;
    data['stockTypeDescription'] = stockTypeDescription;
    data['stockCategoryID'] = stockCategoryID;
    data['stockCategoryDescription'] = stockCategoryDescription;
    data['taxTypeID'] = taxTypeID;
    data['taxCode'] = taxCode;
    data['companyID'] = companyID;
    data['baseUOMPrice1'] = baseUOMPrice1;
    data['batchNo'] = batchNo;
    data['baseUOMCost'] = baseUOMCost;
    return data;
  }
}

class StockDetail {
  int? stockID;
  String? stockCode;
  String? description;
  String? desc2;
  String? image;
  String? baseUOM;
  String? salesUOM;
  bool? hasBatch;
  bool? isActive;
  String? lastModifiedDateTime;
  int? lastModifiedUserID;
  String? createdDateTime;
  int? createdUserID;
  int? stockGroupID;
  StockGroup? stockGroup;
  int? stockTypeID;
  StockType? stockType;
  int? stockCategoryID;
  StockCategory? stockCategory;
  int? taxTypeID;
  TaxType? taxType;
  int? supplierID;
  Supplier? supplier;
  List<StockUOMDtoList>? stockUOMDtoList;
  List<StockBatchDtoList>? stockBatchDtoList;
  double? baseUOMPrice1;

  StockDetail(
      {this.stockID,
      this.stockCode,
      this.description,
      this.desc2,
      this.image,
      this.baseUOM,
      this.salesUOM,
      this.hasBatch,
      this.isActive,
      this.lastModifiedDateTime,
      this.lastModifiedUserID,
      this.createdDateTime,
      this.createdUserID,
      this.stockGroupID,
      this.stockGroup,
      this.stockTypeID,
      this.stockType,
      this.stockCategoryID,
      this.stockCategory,
      this.taxTypeID,
      this.taxType,
      this.supplierID,
      this.supplier,
      this.stockUOMDtoList,
      this.stockBatchDtoList,
      this.baseUOMPrice1});

  StockDetail.fromJson(Map<String, dynamic> json) {
    stockID = json['stockID'];
    stockCode = json['stockCode'];
    description = json['description'];
    desc2 = json['desc2'];
    image = json['image'];
    baseUOM = json['baseUOM'];
    salesUOM = json['salesUOM'];
    hasBatch = json['hasBatch'];
    isActive = json['isActive'];
    lastModifiedDateTime = json['lastModifiedDateTime'];
    lastModifiedUserID = json['lastModifiedUserID'];
    createdDateTime = json['createdDateTime'];
    createdUserID = json['createdUserID'];
    stockGroupID = json['stockGroupID'];
    stockGroup = json['stockGroup'] != null
        ? StockGroup.fromJson(json['stockGroup'])
        : null;
    stockTypeID = json['stockTypeID'];
    stockType = json['stockType'] != null
        ? StockType.fromJson(json['stockType'])
        : null;
    stockCategoryID = json['stockCategoryID'];
    stockCategory = json['stockCategory'] != null
        ? StockCategory.fromJson(json['stockCategory'])
        : null;
    taxTypeID = json['taxTypeID'];
    taxType =
        json['taxType'] != null ? TaxType.fromJson(json['taxType']) : null;
    supplierID = json['supplierID'];
    supplier = json['supplier'] != null
        ? Supplier.fromJson(json['supplier'])
        : null;
    if (json['stockUOMDtoList'] != null) {
      stockUOMDtoList = <StockUOMDtoList>[];
      json['stockUOMDtoList'].forEach((v) {
        stockUOMDtoList!.add(StockUOMDtoList.fromJson(v));
      });
    }
    if (json['stockBatchDtoList'] != null) {
      stockBatchDtoList = <StockBatchDtoList>[];
      json['stockBatchDtoList'].forEach((v) {
        stockBatchDtoList!.add(StockBatchDtoList.fromJson(v));
      });
    }
    baseUOMPrice1 = json['baseUOMPrice1'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['stockID'] = stockID;
    data['stockCode'] = stockCode;
    data['description'] = description;
    data['desc2'] = desc2;
    data['image'] = image;
    data['baseUOM'] = baseUOM;
    data['salesUOM'] = salesUOM;
    data['hasBatch'] = hasBatch;
    data['isActive'] = isActive;
    data['lastModifiedDateTime'] = lastModifiedDateTime;
    data['lastModifiedUserID'] = lastModifiedUserID;
    data['createdDateTime'] = createdDateTime;
    data['createdUserID'] = createdUserID;
    data['stockGroupID'] = stockGroupID;
    if (stockGroup != null) {
      data['stockGroup'] = stockGroup!.toJson();
    }
    data['stockTypeID'] = stockTypeID;
    if (stockType != null) {
      data['stockType'] = stockType!.toJson();
    }
    data['stockCategoryID'] = stockCategoryID;
    if (stockCategory != null) {
      data['stockCategory'] = stockCategory!.toJson();
    }
    data['taxTypeID'] = taxTypeID;
    if (taxType != null) {
      data['taxType'] = taxType!.toJson();
    }
    data['supplierID'] = supplierID;
    if (supplier != null) {
      data['supplier'] = supplier!.toJson();
    }
    if (stockUOMDtoList != null) {
      data['stockUOMDtoList'] =
          stockUOMDtoList!.map((v) => v.toJson()).toList();
    }
    if (stockBatchDtoList != null) {
      data['stockBatchDtoList'] =
          stockBatchDtoList!.map((v) => v.toJson()).toList();
    }
    data['baseUOMPrice1'] = baseUOMPrice1;
    return data;
  }
}

class StockGroup {
  int stockGroupID;
  String? description;
  String? desc2;
  String? shortCode;
  bool? isDisabled;

  StockGroup({
    required this.stockGroupID,
    required this.description,
    required this.desc2,
    required this.shortCode,
    required this.isDisabled,
  });

  factory StockGroup.fromJson(Map<String, dynamic> json) {
    return StockGroup(
      stockGroupID: json['stockGroupID'],
      description: json['description'],
      desc2: json['desc2'],
      shortCode: json['shortCode'],
      isDisabled: json['isDisabled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stockGroupID': stockGroupID,
      'description': description,
      'desc2': desc2,
      'shortCode': shortCode,
      'isDisabled': isDisabled,
    };
  }
}

class StockType {
  int stockTypeID;
  String? description;
  String? desc2;
  String? shortCode;
  bool? isDisabled;

  StockType({
    required this.stockTypeID,
    required this.description,
    required this.desc2,
    required this.shortCode,
    required this.isDisabled,
  });

  factory StockType.fromJson(Map<String, dynamic> json) {
    return StockType(
      stockTypeID: json['stockTypeID'],
      description: json['description'],
      desc2: json['desc2'],
      shortCode: json['shortCode'],
      isDisabled: json['isDisabled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stockTypeID': stockTypeID,
      'description': description,
      'desc2': desc2,
      'shortCode': shortCode,
      'isDisabled': isDisabled,
    };
  }
}

class StockCategory {
  int stockCategoryID;
  String? description;
  String? desc2;
  String? shortCode;
  bool? isDisabled;

  StockCategory({
    required this.stockCategoryID,
    required this.description,
    required this.desc2,
    required this.shortCode,
    required this.isDisabled,
  });

  factory StockCategory.fromJson(Map<String, dynamic> json) {
    return StockCategory(
      stockCategoryID: json['stockCategoryID'],
      description: json['description'],
      desc2: json['desc2'],
      shortCode: json['shortCode'],
      isDisabled: json['isDisabled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stockCategoryID': stockCategoryID,
      'description': description,
      'desc2': desc2,
      'shortCode': shortCode,
      'isDisabled': isDisabled,
    };
  }
}

class StockUOMDtoList {
  int? stockUOMID;
  String? uom;
  String? shelf;
  double? rate;
  double? price;
  double? cost;
  double? minSalePrice;
  double? maxSalePrice;
  double? reorderLevel;
  double? reorderQty;
  double? price2;
  double? price3;
  double? price4;
  double? price5;
  double? price6;
  String? lastModifiedDateTime;
  int? lastModifiedUserID;
  String? createdDateTime;
  int? createdUserID;
  int? stockID;
  int? companyID;
  List<StockBarcodeDtoList>? stockBarcodeDtoList;
  int? barcodeCount;
  // Null? stockBarcodeDtoDeletedList;

  StockUOMDtoList({
    this.stockUOMID,
    this.uom,
    this.shelf,
    this.rate,
    this.price,
    this.cost,
    this.minSalePrice,
    this.maxSalePrice,
    this.reorderLevel,
    this.reorderQty,
    this.price2,
    this.price3,
    this.price4,
    this.price5,
    this.price6,
    this.lastModifiedDateTime,
    this.lastModifiedUserID,
    this.createdDateTime,
    this.createdUserID,
    this.stockID,
    this.companyID,
    this.stockBarcodeDtoList,
    this.barcodeCount,
    //  this.stockBarcodeDtoDeletedList
  });

  StockUOMDtoList.fromJson(Map<String, dynamic> json) {
    stockUOMID = json['stockUOMID'];
    uom = json['uom'];
    shelf = json['shelf'];
    rate = json['rate'];
    price = json['price'];
    cost = json['cost'];
    minSalePrice = json['minSalePrice'];
    maxSalePrice = json['maxSalePrice'];
    reorderLevel = json['reorderLevel'];
    reorderQty = json['reorderQty'];
    price2 = json['price2'];
    price3 = json['price3'];
    price4 = json['price4'];
    price5 = json['price5'];
    price6 = json['price6'];
    lastModifiedDateTime = json['lastModifiedDateTime'];
    lastModifiedUserID = json['lastModifiedUserID'];
    createdDateTime = json['createdDateTime'];
    createdUserID = json['createdUserID'];
    stockID = json['stockID'];
    companyID = json['companyID'];
    if (json['stockBarcodeDtoList'] != null) {
      stockBarcodeDtoList = <StockBarcodeDtoList>[];
      json['stockBarcodeDtoList'].forEach((v) {
        stockBarcodeDtoList!.add(StockBarcodeDtoList.fromJson(v));
      });
    }
    barcodeCount = json['barcodeCount'];
    //  stockBarcodeDtoDeletedList = json['stockBarcodeDtoDeletedList'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['stockUOMID'] = stockUOMID;
    data['uom'] = uom;
    data['shelf'] = shelf;
    data['rate'] = rate;
    data['price'] = price;
    data['cost'] = cost;
    data['minSalePrice'] = minSalePrice;
    data['maxSalePrice'] = maxSalePrice;
    data['minQty'] = reorderLevel;
    data['maxQty'] = reorderQty;
    data['price2'] = price2;
    data['price3'] = price3;
    data['price4'] = price4;
    data['price5'] = price5;
    data['price6'] = price6;
    data['lastModifiedDateTime'] = lastModifiedDateTime;
    data['lastModifiedUserID'] = lastModifiedUserID;
    data['createdDateTime'] = createdDateTime;
    data['createdUserID'] = createdUserID;
    data['stockID'] = stockID;
    data['companyID'] = companyID;
    if (stockBarcodeDtoList != null) {
      data['stockBarcodeDtoList'] =
          stockBarcodeDtoList!.map((v) => v.toJson()).toList();
    }
    data['barcodeCount'] = barcodeCount;
    //data['stockBarcodeDtoDeletedList'] = this.stockBarcodeDtoDeletedList;
    return data;
  }
}

class StockBarcodeDtoList {
  int? stockBarcodeID;
  String? barcode;
  String? description;
  String? lastModifiedDateTime;
  int? lastModifiedUserID;
  String? createdDateTime;
  int? createdUserID;
  int? stockUOMID;
  String? stockUOM;
  int? companyID;

  StockBarcodeDtoList(
      {this.stockBarcodeID,
      this.barcode,
      this.description,
      this.lastModifiedDateTime,
      this.lastModifiedUserID,
      this.createdDateTime,
      this.createdUserID,
      this.stockUOMID,
      this.stockUOM,
      this.companyID});

  StockBarcodeDtoList.fromJson(Map<String, dynamic> json) {
    stockBarcodeID = json['stockBarcodeID'];
    barcode = json['barcode'];
    description = json['description'];
    lastModifiedDateTime = json['lastModifiedDateTime'];
    lastModifiedUserID = json['lastModifiedUserID'];
    createdDateTime = json['createdDateTime'];
    createdUserID = json['createdUserID'];
    stockUOMID = json['stockUOMID'];
    stockUOM = json['stockUOM'];
    companyID = json['companyID'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['stockBarcodeID'] = stockBarcodeID;
    data['barcode'] = barcode;
    data['description'] = description;
    data['lastModifiedDateTime'] = lastModifiedDateTime;
    data['lastModifiedUserID'] = lastModifiedUserID;
    data['createdDateTime'] = createdDateTime;
    data['createdUserID'] = createdUserID;
    data['stockUOMID'] = stockUOMID;
    data['stockUOM'] = stockUOM;
    data['companyID'] = companyID;
    return data;
  }
}

class StockBatchDtoList {
  int? stockBatchID;
  String? batchNo;
  String? manufacturedDate;
  String? expiryDate;
  String? lastModifiedDateTime;
  int? lastModifiedUserID;
  String? createdDateTime;
  int? createdUserID;
  int? stockID;
  int? companyID;
  String? manufacturedDateOnly;
  String? expiryDateOnly;

  StockBatchDtoList(
      {this.stockBatchID,
      this.batchNo,
      this.manufacturedDate,
      this.expiryDate,
      this.lastModifiedDateTime,
      this.lastModifiedUserID,
      this.createdDateTime,
      this.createdUserID,
      this.stockID,
      this.companyID,
      this.manufacturedDateOnly,
      this.expiryDateOnly});

  StockBatchDtoList.fromJson(Map<String, dynamic> json) {
    stockBatchID = json['stockBatchID'];
    batchNo = json['batchNo'];
    manufacturedDate = json['manufacturedDate'];
    expiryDate = json['expiryDate'];
    lastModifiedDateTime = json['lastModifiedDateTime'];
    lastModifiedUserID = json['lastModifiedUserID'];
    createdDateTime = json['createdDateTime'];
    createdUserID = json['createdUserID'];
    stockID = json['stockID'];
    companyID = json['companyID'];
    manufacturedDateOnly = json['manufacturedDateOnly'];
    expiryDateOnly = json['expiryDateOnly'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['stockBatchID'] = stockBatchID;
    data['batchNo'] = batchNo;
    data['manufacturedDate'] = manufacturedDate;
    data['expiryDate'] = expiryDate;
    data['lastModifiedDateTime'] = lastModifiedDateTime;
    data['lastModifiedUserID'] = lastModifiedUserID;
    data['createdDateTime'] = createdDateTime;
    data['createdUserID'] = createdUserID;
    data['stockID'] = stockID;
    data['companyID'] = companyID;
    data['manufacturedDateOnly'] = manufacturedDateOnly;
    data['expiryDateOnly'] = expiryDateOnly;
    return data;
  }
}

class StockItem {
  final int stockID;
  final String stockCode;
  final String description;
  final String desc2;
  final String image;
  final String baseUOM;
  final String salesUOM;
  final bool hasBatch;
  final bool isActive;
  final DateTime lastModifiedDateTime;
  final int lastModifiedUserID;
  final DateTime createdDateTime;
  final int createdUserID;
  final int? stockGroupID;
  final dynamic stockGroup;
  final int? stockTypeID;
  final dynamic stockType;
  final int? stockCategoryID;
  final dynamic stockCategory;
  final int? taxTypeID;
  final dynamic taxType;
  final int companyID;
  final double baseUOMPrice1;
  final String selectedUOM;
  final double baseUOMCost;

  StockItem({
    required this.stockID,
    required this.stockCode,
    required this.description,
    required this.desc2,
    required this.image,
    required this.baseUOM,
    required this.salesUOM,
    required this.hasBatch,
    required this.isActive,
    required this.lastModifiedDateTime,
    required this.lastModifiedUserID,
    required this.createdDateTime,
    required this.createdUserID,
    this.stockGroupID,
    this.stockGroup,
    this.stockTypeID,
    this.stockType,
    this.stockCategoryID,
    this.stockCategory,
    this.taxTypeID,
    this.taxType,
    required this.companyID,
    required this.baseUOMPrice1,
    required this.selectedUOM,
    required this.baseUOMCost,
  });

  factory StockItem.fromJson(Map<String, dynamic> json) {
    return StockItem(
      stockID: json['stockID'],
      stockCode: json['stockCode'],
      description: json['description'],
      desc2: json['desc2'],
      image: json['image'],
      baseUOM: json['baseUOM'],
      salesUOM: json['salesUOM'],
      hasBatch: json['hasBatch'],
      isActive: json['isActive'],
      lastModifiedDateTime: DateTime.parse(json['lastModifiedDateTime']),
      lastModifiedUserID: json['lastModifiedUserID'],
      createdDateTime: DateTime.parse(json['createdDateTime']),
      createdUserID: json['createdUserID'],
      stockGroupID: json['stockGroupID'],
      stockGroup: json['stockGroup'],
      stockTypeID: json['stockTypeID'],
      stockType: json['stockType'],
      stockCategoryID: json['stockCategoryID'],
      stockCategory: json['stockCategory'],
      taxTypeID: json['taxTypeID'],
      taxType: json['taxType'],
      companyID: json['companyID'],
      baseUOMPrice1: json['baseUOMPrice1'].toDouble(),
      selectedUOM: json['selectedUOM'],
      baseUOMCost: json['baseUOMCost'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stockID': stockID,
      'stockCode': stockCode,
      'description': description,
      'desc2': desc2,
      'image': image,
      'baseUOM': baseUOM,
      'salesUOM': salesUOM,
      'hasBatch': hasBatch,
      'isActive': isActive,
      'lastModifiedDateTime': lastModifiedDateTime.toIso8601String(),
      'lastModifiedUserID': lastModifiedUserID,
      'createdDateTime': createdDateTime.toIso8601String(),
      'createdUserID': createdUserID,
      'stockGroupID': stockGroupID,
      'stockGroup': stockGroup,
      'stockTypeID': stockTypeID,
      'stockType': stockType,
      'stockCategoryID': stockCategoryID,
      'stockCategory': stockCategory,
      'taxTypeID': taxTypeID,
      'taxType': taxType,
      'companyID': companyID,
      'baseUOMPrice1': baseUOMPrice1,
      'selectedUOM': selectedUOM,
      'baseUOMCost': baseUOMCost,
    };
  }
}

class StockHistory {
  String? stockCode;
  String? stockDescription;
  String? docType;
  String? docNo;
  DateTime? docDate;
  String? customerSupplierCode;
  String? customerSupplierName;
  String? uom;
  double? qty;
  double? unitPrice;
  double? discount;
  double? total;
  String? location;

  StockHistory({
    this.stockCode,
    this.stockDescription,
    this.docType,
    this.docNo,
    this.docDate,
    this.customerSupplierCode,
    this.customerSupplierName,
    this.uom,
    this.qty,
    this.unitPrice,
    this.discount,
    this.total,
    this.location,
  });

  factory StockHistory.fromJson(Map<String, dynamic> json) {
    return StockHistory(
      stockCode: json['stockCode'],
      stockDescription: json['stockDescription'],
      docType: json['docType'],
      docNo: json['docNo'],
      docDate: json['docDate'] != null ? DateTime.parse(json['docDate']) : null,
      customerSupplierCode: json['customerSupplierCode'],
      customerSupplierName: json['customerSupplierName'],
      uom: json['uom'],
      qty: json['qty'],
      unitPrice: json['unitPrice'],
      discount: json['discount'],
      total: json['total'],
      location: json['location'],
    );
  }
}