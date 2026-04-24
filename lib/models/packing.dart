import 'pagination.dart';

class PackingListItem {
  final int docID;
  final String docNo;
  final String docDate;
  final int customerID;
  final String customerCode;
  final String customerName;
  final String? address1;
  final String? address2;
  final String? address3;
  final String? address4;
  final String? deliverAddr1;
  final String? deliverAddr2;
  final String? deliverAddr3;
  final String? deliverAddr4;
  final String? phone;
  final String? fax;
  final String? email;
  final String? attention;
  final String? description;
  final String? remark;
  final bool isVoid;
  final String lastModifiedDateTime;
  final int lastModifiedUserID;
  final String createdDateTime;
  final int createdUserID;
  final String shippingMethodDescription;
  final String salesDocNo;
  final String pickingDocNo;

  const PackingListItem({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.customerID,
    required this.customerCode,
    required this.customerName,
    required this.address1,
    required this.address2,
    required this.address3,
    required this.address4,
    required this.deliverAddr1,
    required this.deliverAddr2,
    required this.deliverAddr3,
    required this.deliverAddr4,
    required this.phone,
    required this.fax,
    required this.email,
    required this.attention,
    required this.description,
    required this.remark,
    required this.isVoid,
    required this.lastModifiedDateTime,
    required this.lastModifiedUserID,
    required this.createdDateTime,
    required this.createdUserID,
    required this.shippingMethodDescription,
    required this.salesDocNo,
    required this.pickingDocNo
  });

  factory PackingListItem.fromJson(Map<String, dynamic> json) => PackingListItem(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        customerID: (json['customerID'] as int?) ?? 0,
        customerCode: (json['customerCode'] as String?) ?? '',
        customerName: (json['customerName'] as String?) ?? '',
        address1: (json['address1'] as String?) ?? '',
        address2: (json['address2'] as String?) ?? '',
        address3: (json['address2'] as String?) ?? '',
        address4: (json['address2'] as String?) ?? '',
        deliverAddr1: (json['deliverAddr1'] as String?) ?? '',
        deliverAddr2: (json['deliverAddr2'] as String?) ?? '',
        deliverAddr3: (json['deliverAddr3'] as String?) ?? '',
        deliverAddr4: (json['deliverAddr4'] as String?) ?? '',
        phone: json['phone'] as String?,
        fax: json['fax'] as String?,
        email: json['email'] as String?,
        attention: json['attention'] as String?,
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
        lastModifiedDateTime: (json['lastModifiedDateTime'] as String?) ?? '',
        lastModifiedUserID: (json['lastModifiedUserID'] as int?) ?? 0,
        createdDateTime: (json['createdDateTime'] as String?) ?? '',
        createdUserID: (json['createdUserID'] as int?) ?? 0,
        shippingMethodDescription: (json['shippingMethodDescription'] as String?) ?? '',
        salesDocNo: (json['salesDocNo'] as String?) ?? '',
        pickingDocNo: (json['pickingDocNo'] as String?) ?? '',
      );
}

class PackingDetailLine {
  final int dtlID;
  final int docID;
  final int pickingItemID;
  final int stockID;
  final String stockCode;
  final String description;
  final String uom;
  final double qty;
  final int? batchID;
  final String? batchNo;
  String? image;
  double? packQty;

  PackingDetailLine({
    required this.dtlID,
    required this.docID,
    required this.pickingItemID,
    required this.stockID,
    required this.stockCode,
    required this.description,
    required this.uom,
    required this.qty,
    this.batchID,
    this.batchNo,
    this.image,
    this.packQty
  });

  factory PackingDetailLine.fromJson(Map<String, dynamic> json) =>
      PackingDetailLine(
        dtlID: (json['dtlID'] as int?) ?? 0,
        docID: (json['docID'] as int?) ?? 0,
        pickingItemID: (json['pickingItemID'] as int?) ?? 0,
        stockID: (json['stockID'] as int?) ?? 0,
        stockCode: (json['stockCode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        uom: (json['uom'] as String?) ?? '',
        qty: _toD(json['qty']),
        batchID: json['stockBatchID'] as int?,
        batchNo: (json['batchNo'] as String?) ?? '',
      );
}

class PackingResponse {
  final List<PackingListItem>? data;
  final Pagination? pagination;

  const PackingResponse({this.data, this.pagination});

  factory PackingResponse.fromJson(Map<String, dynamic> json) => PackingResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) => PackingListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}

class PackingDoc {
  final int docID;
  final String docNo;
  final String docDate;
  final int customerID;
  final String customerCode;
  final String customerName;
  final String? address1;
  final String? address2;
  final String? address3;
  final String? address4;
  final String? deliverAddr1;
  final String? deliverAddr2;
  final String? deliverAddr3;
  final String? deliverAddr4;
  final String? phone;
  final String? fax;
  final String? email;
  final String? attention;
  final String? description;
  final String? remark;
  final bool isVoid;
  final String lastModifiedDateTime;
  final int lastModifiedUserID;
  final String createdDateTime;
  final int createdUserID;
  final String? shippingRefNo;
  final int? shippingMethodID;
  final String? shippingMethodDescription;
  final int salesDocID;
  final String salesDocNo;
  final int pickingDocID;
  final String pickingDocNo;
  final List<PackingDetailLine> packingDetails;

  const PackingDoc({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.customerID,
    required this.customerCode,
    required this.customerName,
    this.address1,
    this.address2,
    this.address3,
    this.address4,
    this.deliverAddr1,
    this.deliverAddr2,
    this.deliverAddr3,
    this.deliverAddr4,
    this.phone,
    this.fax,
    this.email,
    this.attention,
    this.description,
    this.remark,
    required this.isVoid,
    required this.lastModifiedDateTime,
    required this.lastModifiedUserID,
    required this.createdDateTime,
    required this.createdUserID,
    this.shippingRefNo,
    this.shippingMethodID,
    this.shippingMethodDescription,
    required this.salesDocID,
    required this.salesDocNo,
    required this.pickingDocID,
    required this.pickingDocNo,
    required this.packingDetails,
  });

  factory PackingDoc.fromJson(Map<String, dynamic> json) => PackingDoc(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        customerID: (json['customerID'] as int?) ?? 0,
        customerCode: (json['customerCode'] as String?) ?? '',
        customerName: (json['customerName'] as String?) ?? '',
        address1: json['address1'] as String?,
        address2: json['address2'] as String?,
        address3: json['address3'] as String?,
        address4: json['address4'] as String?,
        deliverAddr1: json['deliverAddr1'] as String?,
        deliverAddr2: json['deliverAddr2'] as String?,
        deliverAddr3: json['deliverAddr3'] as String?,
        deliverAddr4: json['deliverAddr4'] as String?,
        phone: json['phone'] as String?,
        fax: json['fax'] as String?,
        email: json['email'] as String?,
        attention: json['attention'] as String?,
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
        lastModifiedDateTime: (json['lastModifiedDateTime'] as String?) ?? '',
        lastModifiedUserID: (json['lastModifiedUserID'] as int?) ?? 0,
        createdDateTime: (json['createdDateTime'] as String?) ?? '',
        createdUserID: (json['createdUserID'] as int?) ?? 0,
        shippingRefNo: json['shippingRefNo'] as String?,
        shippingMethodID: json['shippingMethodID'] as int?,
        shippingMethodDescription: json['shippingMethodDescription'] as String?,
        salesDocID: (json['salesDocID'] as int?) ?? 0,
        salesDocNo: (json['salesDocNo'] as String?) ?? '',
        pickingDocID: (json['pickingDocID'] as int?) ?? 0,
        pickingDocNo: (json['pickingDocNo'] as String?) ?? '',
        packingDetails: (json['packingDetails'] as List<dynamic>?)
                ?.map((e) =>
                    PackingDetailLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

double _toD(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
