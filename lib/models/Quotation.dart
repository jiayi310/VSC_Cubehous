import 'pagination.dart';

class QuotationListItem {
  final int docID;
  final String docNo;
  final String docDate;
  final int customerID;
  final String customerCode;
  final String customerName;
  final String? salesAgent;
  final double subtotal;
  final double taxableAmt;
  final double taxAmt;
  final double finalTotal;
  final String? description;
  final String? remark;
  final bool isVoid;

  const QuotationListItem({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.customerID,
    required this.customerCode,
    required this.customerName,
    this.salesAgent,
    required this.subtotal,
    required this.taxableAmt,
    required this.taxAmt,
    required this.finalTotal,
    this.description,
    this.remark,
    required this.isVoid,
  });

  factory QuotationListItem.fromJson(Map<String, dynamic> json) =>
      QuotationListItem(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        customerID: (json['customerID'] as int?) ?? 0,
        customerCode: (json['customerCode'] as String?) ?? '',
        customerName: (json['customerName'] as String?) ?? '',
        salesAgent: json['salesAgent'] as String?,
        subtotal: _toD(json['subtotal']),
        taxableAmt: _toD(json['taxableAmt']),
        taxAmt: _toD(json['taxAmt']),
        finalTotal: _toD(json['finalTotal']),
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
      );
}

class QuotationDetailLine {
  final int dtlID;
  final int docID;
  final int stockID;
  final String stockCode;
  final String description;
  final String uom;
  final double qty;
  final double unitPrice;
  final double discount;
  final double total;
  final int? taxTypeID;
  final String? taxCode;
  final double taxableAmt;
  final double taxRate;
  final double taxAmt;
  final int? locationID;
  final String? location;
  String? image;

  QuotationDetailLine({
    required this.dtlID,
    required this.docID,
    required this.stockID,
    required this.stockCode,
    required this.description,
    required this.uom,
    required this.qty,
    required this.unitPrice,
    required this.discount,
    required this.total,
    this.taxTypeID,
    this.taxCode,
    required this.taxableAmt,
    required this.taxRate,
    required this.taxAmt,
    this.locationID,
    this.location,
    this.image,
  });

  factory QuotationDetailLine.fromJson(Map<String, dynamic> json) =>
      QuotationDetailLine(
        dtlID: (json['dtlID'] as int?) ?? 0,
        docID: (json['docID'] as int?) ?? 0,
        stockID: (json['stockID'] as int?) ?? 0,
        stockCode: (json['stockCode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        uom: (json['uom'] as String?) ?? '',
        qty: _toD(json['qty']),
        unitPrice: _toD(json['unitPrice']),
        discount: _toD(json['discount']),
        total: _toD(json['total']),
        taxTypeID: json['taxTypeID'] as int?,
        taxCode: json['taxCode'] as String?,
        taxableAmt: _toD(json['taxableAmt']),
        taxRate: _toD(json['taxRate']),
        taxAmt: _toD(json['taxAmt']),
        locationID: json['locationID'] as int?,
        location: json['location'] as String?,
      );
}

class QuotationDoc {
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
  final String? salesAgent;
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
  final int? shippingMethodID;
  final String? shippingMethodDescription;
  final bool isVoid;
  final List<QuotationDetailLine> quotationDetails;

  const QuotationDoc({
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
    this.salesAgent,
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
    this.shippingMethodID,
    this.shippingMethodDescription,
    required this.isVoid,
    required this.quotationDetails,
  });

  factory QuotationDoc.fromJson(Map<String, dynamic> json) => QuotationDoc(
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
        salesAgent: json['salesAgent'] as String?,
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
        shippingMethodID: json['shippingMethodID'] as int?,
        shippingMethodDescription:
            json['shippingMethodDescription'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
        quotationDetails: (json['quotationDetails'] as List<dynamic>?)
                ?.map((e) =>
                    QuotationDetailLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class QuotationResponse {
  final List<QuotationListItem>? data;
  final Pagination? pagination;

  const QuotationResponse({this.data, this.pagination});

  factory QuotationResponse.fromJson(Map<String, dynamic> json) =>
      QuotationResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) =>
                QuotationListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(
                json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}

double _toD(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}
