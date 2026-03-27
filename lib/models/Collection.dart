import 'pagination.dart';

double _toD(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class CollectionListItem {
  final int docID;
  final String docNo;
  final String docDate;
  final int customerID;
  final String customerCode;
  final String customerName;
  final String? salesAgent;
  final String? paymentType;
  final String? refNo;
  final double paymentTotal;

  const CollectionListItem({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.customerID,
    required this.customerCode,
    required this.customerName,
    this.salesAgent,
    this.paymentType,
    this.refNo,
    required this.paymentTotal,
  });

  factory CollectionListItem.fromJson(Map<String, dynamic> json) =>
      CollectionListItem(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        customerID: (json['customerID'] as int?) ?? 0,
        customerCode: (json['customerCode'] as String?) ?? '',
        customerName: (json['customerName'] as String?) ?? '',
        salesAgent: json['salesAgent'] as String?,
        paymentType: json['paymentType'] as String?,
        refNo: json['refNo'] as String?,
        paymentTotal: _toD(json['paymentTotal']),
      );
}

class CollectMapping {
  final int collectMappingID;
  final int collectDocID;
  final double paymentAmt;
  final int salesDocID;
  final String salesDocNo;
  final String salesDocDate;
  final String? salesAgent;
  final double salesFinalTotal;
  final double salesOutstanding;
  final double editOutstanding;
  final double editPaymentAmt;

  const CollectMapping({
    required this.collectMappingID,
    required this.collectDocID,
    required this.paymentAmt,
    required this.salesDocID,
    required this.salesDocNo,
    required this.salesDocDate,
    this.salesAgent,
    required this.salesFinalTotal,
    required this.salesOutstanding,
    required this.editOutstanding,
    required this.editPaymentAmt,
  });

  factory CollectMapping.fromJson(Map<String, dynamic> json) => CollectMapping(
        collectMappingID: (json['collectMappingID'] as int?) ?? 0,
        collectDocID: (json['collectDocID'] as int?) ?? 0,
        paymentAmt: _toD(json['paymentAmt']),
        salesDocID: (json['salesDocID'] as int?) ?? 0,
        salesDocNo: (json['salesDocNo'] as String?) ?? '',
        salesDocDate: (json['salesDocDate'] as String?) ?? '',
        salesAgent: json['salesAgent'] as String?,
        salesFinalTotal: _toD(json['salesFinalTotal']),
        salesOutstanding: _toD(json['salesOutstanding']),
        editOutstanding: _toD(json['editOutstanding']),
        editPaymentAmt: _toD(json['editPaymentAmt']),
      );
}

class CollectionDoc {
  final int docID;
  final String docNo;
  final String docDate;
  final int customerID;
  final String customerCode;
  final String customerName;
  final String? salesAgent;
  final String? paymentType;
  final String? refNo;
  final double paymentTotal;
  final String? address1;
  final String? address2;
  final String? address3;
  final String? address4;
  final String? image;
  final List<CollectMapping> collectMappings;

  const CollectionDoc({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.customerID,
    required this.customerCode,
    required this.customerName,
    this.salesAgent,
    this.paymentType,
    this.refNo,
    required this.paymentTotal,
    this.address1,
    this.address2,
    this.address3,
    this.address4,
    this.image,
    required this.collectMappings,
  });

  factory CollectionDoc.fromJson(Map<String, dynamic> json) => CollectionDoc(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        customerID: (json['customerID'] as int?) ?? 0,
        customerCode: (json['customerCode'] as String?) ?? '',
        customerName: (json['customerName'] as String?) ?? '',
        salesAgent: json['salesAgent'] as String?,
        paymentType: json['paymentType'] as String?,
        refNo: json['refNo'] as String?,
        paymentTotal: _toD(json['paymentTotal']),
        address1: json['address1'] as String?,
        address2: json['address2'] as String?,
        address3: json['address3'] as String?,
        address4: json['address4'] as String?,
        image: json['image'] as String?,
        collectMappings: (json['collectMappings'] as List<dynamic>?)
                ?.map(
                    (e) => CollectMapping.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class CollectionResponse {
  final List<CollectionListItem>? data;
  final Pagination? pagination;

  const CollectionResponse({this.data, this.pagination});

  factory CollectionResponse.fromJson(Map<String, dynamic> json) =>
      CollectionResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) =>
                CollectionListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(
                json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}

class PaymentTypeItem {
  final String paymentType;

  const PaymentTypeItem({required this.paymentType});

  factory PaymentTypeItem.fromJson(Map<String, dynamic> json) =>
      PaymentTypeItem(
        paymentType: (json['paymentType'] as String?) ?? '',
      );
}
