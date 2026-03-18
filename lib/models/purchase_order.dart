import 'pagination.dart';

double _toD(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class PurchaseListItem {
  final int docID;
  final String docNo;
  final String docDate;
  final String supplierCode;
  final String supplierName;
  final double subtotal;
  final double taxableAmt;
  final double taxAmt;
  final double finalTotal;
  final String? description;
  final String? remark;
  final bool isVoid;
  final bool isReceive;

  const PurchaseListItem({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.supplierCode,
    required this.supplierName,
    required this.subtotal,
    required this.taxableAmt,
    required this.taxAmt,
    required this.finalTotal,
    this.description,
    this.remark,
    required this.isVoid,
    required this.isReceive,
  });

  factory PurchaseListItem.fromJson(Map<String, dynamic> json) =>
      PurchaseListItem(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        supplierCode: (json['supplierCode'] as String?) ?? '',
        supplierName: (json['supplierName'] as String?) ?? '',
        subtotal: _toD(json['subtotal']),
        taxableAmt: _toD(json['taxableAmt']),
        taxAmt: _toD(json['taxAmt']),
        finalTotal: _toD(json['finalTotal']),
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
        isReceive: (json['isReceive'] as bool?) ?? false,
      );
}

class PurchaseDetailLine {
  final int dtlID;
  final int docID;
  final int? stockID;
  final String stockCode;
  final String description;
  final String uom;
  final double qty;
  final double receiveQty;
  final double unitPrice;
  final double discount;
  final double total;
  final String? taxCode;
  final double taxableAmt;
  final double taxRate;
  final double taxAmt;

  const PurchaseDetailLine({
    required this.dtlID,
    required this.docID,
    this.stockID,
    required this.stockCode,
    required this.description,
    required this.uom,
    required this.qty,
    required this.receiveQty,
    required this.unitPrice,
    required this.discount,
    required this.total,
    this.taxCode,
    required this.taxableAmt,
    required this.taxRate,
    required this.taxAmt,
  });

  factory PurchaseDetailLine.fromJson(Map<String, dynamic> json) =>
      PurchaseDetailLine(
        dtlID: (json['dtlID'] as int?) ?? 0,
        docID: (json['docID'] as int?) ?? 0,
        stockID: json['stockID'] as int?,
        stockCode: (json['stockCode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        uom: (json['uom'] as String?) ?? '',
        qty: _toD(json['qty']),
        receiveQty: _toD(json['receiveQty']),
        unitPrice: _toD(json['unitPrice']),
        discount: _toD(json['discount']),
        total: _toD(json['total']),
        taxCode: json['taxCode'] as String?,
        taxableAmt: _toD(json['taxableAmt']),
        taxRate: _toD(json['taxRate']),
        taxAmt: _toD(json['taxAmt']),
      );
}

class PurchaseDoc {
  final int docID;
  final String docNo;
  final String docDate;
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
  final double subtotal;
  final double taxableAmt;
  final double taxAmt;
  final double finalTotal;
  final String? description;
  final String? remark;
  final bool isVoid;
  final bool isReceive;
  final List<PurchaseDetailLine> purchaseDetails;

  const PurchaseDoc({
    required this.docID,
    required this.docNo,
    required this.docDate,
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
    required this.subtotal,
    required this.taxableAmt,
    required this.taxAmt,
    required this.finalTotal,
    this.description,
    this.remark,
    required this.isVoid,
    required this.isReceive,
    required this.purchaseDetails,
  });

  factory PurchaseDoc.fromJson(Map<String, dynamic> json) => PurchaseDoc(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
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
        subtotal: _toD(json['subtotal']),
        taxableAmt: _toD(json['taxableAmt']),
        taxAmt: _toD(json['taxAmt']),
        finalTotal: _toD(json['finalTotal']),
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
        isReceive: (json['isReceive'] as bool?) ?? false,
        purchaseDetails: (json['purchaseDetails'] as List<dynamic>?)
                ?.map((e) =>
                    PurchaseDetailLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class PurchaseResponse {
  final List<PurchaseListItem>? data;
  final Pagination? pagination;

  const PurchaseResponse({this.data, this.pagination});

  factory PurchaseResponse.fromJson(Map<String, dynamic> json) =>
      PurchaseResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) =>
                PurchaseListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(
                json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}
