import 'pagination.dart';

class StockTakeDetailLine {
  final int dtlID;
  final int docID;
  final int stockID;
  final int stockBatchID;
  final String? batchNo;
  final String stockCode;
  final String description;
  final String uom;
  final double qty;
  final int locationID;
  final int storageID;
  final String storageCode;
  String? image;

  StockTakeDetailLine({
    this.dtlID = 0,
    this.docID = 0,
    this.stockID = 0,
    this.stockBatchID = 0,
    this.batchNo,
    this.stockCode = '',
    this.description = '',
    this.uom = '',
    this.qty = 0.0,
    this.locationID = 0,
    this.storageID = 0,
    this.storageCode = '',
    this.image,
  });

  factory StockTakeDetailLine.fromJson(Map<String, dynamic> json) =>
      StockTakeDetailLine(
        dtlID: (json['dtlID'] as int?) ?? 0,
        docID: (json['docID'] as int?) ?? 0,
        stockID: (json['stockID'] as int?) ?? 0,
        stockBatchID: (json['stockBatchID'] as int?) ?? 0,
        batchNo: json['batchNo'] as String?,
        stockCode: (json['stockCode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        uom: (json['uom'] as String?) ?? '',
        qty: _toD(json['qty']),
        locationID: (json['locationID'] as int?) ?? 0,
        storageID: (json['storageID'] as int?) ?? 0,
        storageCode: (json['storageCode'] as String?) ?? '',
      );

  static double _toD(dynamic v) =>
      v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
}

class StockTakeListItem {
  final int docID;
  final String docNo;
  final String docDate;
  final int locationID;
  final String location;
  final String? description;
  final String? remark;
  final bool isVoid;
  final bool isMerge;
  final bool isAdjustment;

  const StockTakeListItem({
    this.docID = 0,
    this.docNo = '',
    this.docDate = '',
    this.locationID = 0,
    this.location = '',
    this.description,
    this.remark,
    this.isVoid = false,
    this.isMerge = false,
    this.isAdjustment = false,
  });

  factory StockTakeListItem.fromJson(Map<String, dynamic> json) =>
      StockTakeListItem(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        locationID: (json['locationID'] as int?) ?? 0,
        location: (json['location'] as String?) ?? '',
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
        isMerge: (json['isMerge'] as bool?) ?? false,
        isAdjustment: (json['isAdjustment'] as bool?) ?? false,
      );
}

class StockTakeDoc {
  final int docID;
  final String docNo;
  final String docDate;
  final int locationID;
  final String location;
  final String? description;
  final String? remark;
  final bool isVoid;
  final bool isMerge;
  final String? mergeDocNo;
  final int mergeDocID;
  final bool isAdjustment;
  final String? adjustmentDocNo;
  final int adjustmentDocID;
  final List<StockTakeDetailLine> stockTakeDetails;

  const StockTakeDoc({
    this.docID = 0,
    this.docNo = '',
    this.docDate = '',
    this.locationID = 0,
    this.location = '',
    this.description,
    this.remark,
    this.isVoid = false,
    this.isMerge = false,
    this.mergeDocNo,
    this.mergeDocID = 0,
    this.isAdjustment = false,
    this.adjustmentDocNo,
    this.adjustmentDocID = 0,
    this.stockTakeDetails = const [],
  });

  factory StockTakeDoc.fromJson(Map<String, dynamic> json) => StockTakeDoc(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        locationID: (json['locationID'] as int?) ?? 0,
        location: (json['location'] as String?) ?? '',
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
        isMerge: (json['isMerge'] as bool?) ?? false,
        mergeDocNo: json['mergeDocNo'] as String?,
        mergeDocID: (json['mergeDocID'] as int?) ?? 0,
        isAdjustment: (json['isAdjustment'] as bool?) ?? false,
        adjustmentDocNo: json['adjustmentDocNo'] as String?,
        adjustmentDocID: (json['adjustmentDocID'] as int?) ?? 0,
        stockTakeDetails: (json['stockTakeDetails'] as List<dynamic>?)
                ?.map((e) => StockTakeDetailLine.fromJson(
                    e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class StockTakeResponse {
  final List<StockTakeListItem>? data;
  final Pagination? pagination;

  const StockTakeResponse({this.data, this.pagination});

  factory StockTakeResponse.fromJson(Map<String, dynamic> json) =>
      StockTakeResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) =>
                StockTakeListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(
                json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}
