import 'pagination.dart';

class PutAwayListItem {
  final int docID;
  final String docNo;
  final int stockID;
  final String stockCode;
  final int? stockBatchID;
  final String? batchNo;
  final String stockDescription;
  final String uom;
  final double qty;
  final String? receivingDocNo;
  final int? receivingDtlID;
  final int locationID;
  final String location;
  final int storageID;
  final String storageCode;
  final String createdDateTime;
  final int createdUserID;

  const PutAwayListItem({
    required this.docID,
    required this.docNo,
    required this.stockID,
    required this.stockCode,
    required this.stockBatchID,
    required this.batchNo,
    required this.stockDescription,
    required this.uom,
    required this.qty,
    required this.receivingDocNo,
    required this.receivingDtlID,
    required this.locationID,
    required this.location,
    required this.storageID,
    required this.storageCode,
    required this.createdDateTime,
    required this.createdUserID
  });

  factory PutAwayListItem.fromJson(Map<String, dynamic> json) => PutAwayListItem(
        docID: (json['putAwayID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        stockID: (json['stockID'] as int?) ?? 0,
        stockCode: (json['stockCode'] as String?) ?? '',
        stockBatchID: json['stockBatchID'] as int?,
        batchNo: json['batchNo'] as String?,
        stockDescription: (json['description'] as String?) ?? '',
        uom: (json['uom'] as String?) ?? '',
        qty: (json['qty'] as num?)?.toDouble() ?? 0.0,
        receivingDocNo: json['receivingDocNo'] as String?,
        receivingDtlID: json['receivingDtlID'] as int?,
        locationID: (json['locationID'] as int?) ?? 0,
        location: (json['location'] as String?) ?? '',
        storageID: (json['storageID'] as int?) ?? 0,
        storageCode: (json['storageCode'] as String?) ?? '',
        createdDateTime: (json['createdDateTime'] as String?) ?? '',
        createdUserID: (json['createdUserID'] as int?) ?? 0,
      );
}

class PutAwayResponse {
  final List<PutAwayListItem>? data;
  final Pagination? pagination;

  const PutAwayResponse({this.data, this.pagination});

  factory PutAwayResponse.fromJson(Map<String, dynamic> json) => PutAwayResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) => PutAwayListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}
