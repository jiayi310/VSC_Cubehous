import 'pagination.dart';

class StockAdjustmentDetailLine {
  final int dtlID;
  final int docID;
  final int stockID;
  final int stockBatchID;
  final String? batchNo;
  final String stockCode;
  final String description;
  final String uom;
  final double qty;
  final int stockTakeDtlID;
  final String stockTakeDocNo;
  final int locationID;
  final int storageID;
  final String storageCode;
  String? image;

  StockAdjustmentDetailLine({
    this.dtlID = 0,
    this.docID = 0,
    this.stockID = 0,
    this.stockBatchID = 0,
    this.batchNo,
    this.stockCode = '',
    this.description = '',
    this.uom = '',
    this.qty = 0.0,
    this.stockTakeDtlID = 0,
    this.stockTakeDocNo = '',
    this.locationID = 0,
    this.storageID = 0,
    this.storageCode = '',
    this.image,
  });

  factory StockAdjustmentDetailLine.fromJson(Map<String, dynamic> json) =>
      StockAdjustmentDetailLine(
        dtlID: (json['dtlID'] as int?) ?? 0,
        docID: (json['docID'] as int?) ?? 0,
        stockID: (json['stockID'] as int?) ?? 0,
        stockBatchID: (json['stockBatchID'] as int?) ?? 0,
        batchNo: json['batchNo'] as String?,
        stockCode: (json['stockCode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        uom: (json['uom'] as String?) ?? '',
        qty: _toD(json['qty']),
        stockTakeDtlID: (json['stockTakeDtlID'] as int?) ?? 0,
        stockTakeDocNo: (json['stockTakeDocNo'] as String?) ?? '',
        locationID: (json['locationID'] as int?) ?? 0,
        storageID: (json['storageID'] as int?) ?? 0,
        storageCode: (json['storageCode'] as String?) ?? '',
      );

  static double _toD(dynamic v) =>
      v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
}

class StockAdjustmentListItem {
  final int docID;
  final String docNo;
  final String docDate;
  final String? description;
  final String? remark;
  final bool isVoid;
  final int locationID;
  final String location;
  final int stockTakeDocID;
  final String stockTakeDocNo;

  const StockAdjustmentListItem({
    this.docID = 0,
    this.docNo = '',
    this.docDate = '',
    this.description,
    this.remark,
    this.isVoid = false,
    this.locationID = 0,
    this.location = '',
    this.stockTakeDocID = 0,
    this.stockTakeDocNo = '',
  });

  factory StockAdjustmentListItem.fromJson(Map<String, dynamic> json) =>
      StockAdjustmentListItem(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
        locationID: (json['locationID'] as int?) ?? 0,
        location: (json['location'] as String?) ?? '',
        stockTakeDocID: (json['stockTakeDocID'] as int?) ?? 0,
        stockTakeDocNo: (json['stockTakeDocNo'] as String?) ?? '',
      );
}

class StockAdjustmentDoc {
  final int docID;
  final String docNo;
  final String docDate;
  final String? description;
  final String? remark;
  final bool isVoid;
  final String? lastModifiedDateTime;
  final int lastModifiedUserID;
  final String? createdDateTime;
  final int createdUserID;
  final int stockTakeDocID;
  final String stockTakeDocNo;
  final int locationID;
  final String location;
  final int companyID;
  final List<StockAdjustmentDetailLine> stockAdjustmentDetails;

  const StockAdjustmentDoc({
    this.docID = 0,
    this.docNo = '',
    this.docDate = '',
    this.description,
    this.remark,
    this.isVoid = false,
    this.lastModifiedDateTime,
    this.lastModifiedUserID = 0,
    this.createdDateTime,
    this.createdUserID = 0,
    this.stockTakeDocID = 0,
    this.stockTakeDocNo = '',
    this.locationID = 0,
    this.location = '',
    this.companyID = 0,
    this.stockAdjustmentDetails = const [],
  });

  factory StockAdjustmentDoc.fromJson(Map<String, dynamic> json) {
    final raw = json['stockAdjustmentForm'] ?? json;
    final details = (raw['stockAdjustmentDetails'] as List<dynamic>? ?? [])
        .map((e) => StockAdjustmentDetailLine.fromJson(e as Map<String, dynamic>))
        .toList();
    return StockAdjustmentDoc(
      docID: (raw['docID'] as int?) ?? 0,
      docNo: (raw['docNo'] as String?) ?? '',
      docDate: (raw['docDate'] as String?) ?? '',
      description: raw['description'] as String?,
      remark: raw['remark'] as String?,
      isVoid: (raw['isVoid'] as bool?) ?? false,
      lastModifiedDateTime: raw['lastModifiedDateTime'] as String?,
      lastModifiedUserID: (raw['lastModifiedUserID'] as int?) ?? 0,
      createdDateTime: raw['createdDateTime'] as String?,
      createdUserID: (raw['createdUserID'] as int?) ?? 0,
      stockTakeDocID: (raw['stockTakeDocID'] as int?) ?? 0,
      stockTakeDocNo: (raw['stockTakeDocNo'] as String?) ?? '',
      locationID: (raw['locationID'] as int?) ?? 0,
      location: (raw['location'] as String?) ?? '',
      companyID: (raw['companyID'] as int?) ?? 0,
      stockAdjustmentDetails: details,
    );
  }
}

class StockAdjustmentResponse {
  final List<StockAdjustmentListItem>? data;
  final Pagination? pagination;

  const StockAdjustmentResponse({this.data, this.pagination});

  factory StockAdjustmentResponse.fromJson(Map<String, dynamic> json) =>
      StockAdjustmentResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) =>
                StockAdjustmentListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(
                json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}
