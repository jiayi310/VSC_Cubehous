import 'pagination.dart';

double _toD(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class ReceivingListItem {
  final int docID;
  final String docNo;
  final String docDate;
  final String supplierCode;
  final String supplierName;
  final String? description;
  final String? remark;
  final bool isPutAway;
  final bool isVoid;
  final int? purchaseDocID;
  final String? purchaseDocNo;

  const ReceivingListItem({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.supplierCode,
    required this.supplierName,
    this.description,
    this.remark,
    required this.isPutAway,
    required this.isVoid,
    this.purchaseDocID,
    this.purchaseDocNo,
  });

  factory ReceivingListItem.fromJson(Map<String, dynamic> json) =>
      ReceivingListItem(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        supplierCode: (json['supplierCode'] as String?) ?? '',
        supplierName: (json['supplierName'] as String?) ?? '',
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isPutAway: (json['isPutAway'] as bool?) ?? false,
        isVoid: (json['isVoid'] as bool?) ?? false,
        purchaseDocID: json['purchaseDocID'] as int?,
        purchaseDocNo: json['purchaseDocNo'] as String?,
      );
}

class ReceivingDetailLine {
  final int dtlID;
  final int docID;
  final int? stockID;
  final int? stockBatchID;
  final String? batchNo;
  final String stockCode;
  final String description;
  final String uom;
  final double qty;
  final double putAwayQty;
  final String? image;

  const ReceivingDetailLine({
    required this.dtlID,
    required this.docID,
    this.stockID,
    this.stockBatchID,
    this.batchNo,
    required this.stockCode,
    required this.description,
    required this.uom,
    required this.qty,
    required this.putAwayQty,
    this.image,
  });

  factory ReceivingDetailLine.fromJson(Map<String, dynamic> json) =>
      ReceivingDetailLine(
        dtlID: (json['dtlID'] as int?) ?? 0,
        docID: (json['docID'] as int?) ?? 0,
        stockID: json['stockID'] as int?,
        stockBatchID: json['stockBatchID'] as int?,
        batchNo: json['batchNo'] as String?,
        stockCode: (json['stockCode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        uom: (json['uom'] as String?) ?? '',
        qty: _toD(json['qty']),
        putAwayQty: _toD(json['putAwayQty']),
        image: json['image'] as String?,
      );
}

class ReceivingDoc {
  final int docID;
  final String docNo;
  final String docDate;
  final int? supplierID;
  final String supplierCode;
  final String supplierName;
  final String? address1;
  final String? address2;
  final String? address3;
  final String? address4;
  final String? phone;
  final String? fax;
  final String? email;
  final String? attention;
  final String? description;
  final String? remark;
  final bool isPutAway;
  final bool isVoid;
  final int? purchaseDocID;
  final String? purchaseDocNo;
  final List<ReceivingDetailLine> receivingDetails;

  const ReceivingDoc({
    required this.docID,
    required this.docNo,
    required this.docDate,
    this.supplierID,
    required this.supplierCode,
    required this.supplierName,
    this.address1,
    this.address2,
    this.address3,
    this.address4,
    this.phone,
    this.fax,
    this.email,
    this.attention,
    this.description,
    this.remark,
    required this.isPutAway,
    required this.isVoid,
    this.purchaseDocID,
    this.purchaseDocNo,
    required this.receivingDetails,
  });

  factory ReceivingDoc.fromJson(Map<String, dynamic> json) => ReceivingDoc(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        supplierID: json['supplierID'] as int?,
        supplierCode: (json['supplierCode'] as String?) ?? '',
        supplierName: (json['supplierName'] as String?) ?? '',
        address1: json['address1'] as String?,
        address2: json['address2'] as String?,
        address3: json['address3'] as String?,
        address4: json['address4'] as String?,
        phone: json['phone'] as String?,
        fax: json['fax'] as String?,
        email: json['email'] as String?,
        attention: json['attention'] as String?,
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isPutAway: (json['isPutAway'] as bool?) ?? false,
        isVoid: (json['isVoid'] as bool?) ?? false,
        purchaseDocID: json['purchaseDocID'] as int?,
        purchaseDocNo: json['purchaseDocNo'] as String?,
        receivingDetails:
            (json['receivingDetails'] as List<dynamic>?)
                    ?.map((e) => ReceivingDetailLine.fromJson(
                        e as Map<String, dynamic>))
                    .toList() ??
                [],
      );
}

class ReceivingResponse {
  final List<ReceivingListItem>? data;
  final Pagination? pagination;

  const ReceivingResponse({this.data, this.pagination});

  factory ReceivingResponse.fromJson(Map<String, dynamic> json) =>
      ReceivingResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) =>
                ReceivingListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(
                json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}

/// Lightweight PO item for the PO picker inside the receiving form.
class ReceivingPurchaseItem {
  final int docID;
  final String docNo;
  final String docDate;
  final String supplierCode;
  final String supplierName;

  const ReceivingPurchaseItem({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.supplierCode,
    required this.supplierName,
  });

  factory ReceivingPurchaseItem.fromJson(Map<String, dynamic> json) =>
      ReceivingPurchaseItem(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        supplierCode: (json['supplierCode'] as String?) ?? '',
        supplierName: (json['supplierName'] as String?) ?? '',
      );
}
