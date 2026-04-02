import 'pagination.dart';

double _toD(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class SalesListItem {
  final int docID;
  final String docNo;
  final String docDate;
  final int customerID;
  final String customerCode;
  final String customerName;
  final String? salesAgent;
  final double subtotal;
  final double taxAmt;
  final double finalTotal;
  final double paymentTotal;
  final double outstanding;
  final String? description;
  final String? remark;
  final bool isVoid;

  const SalesListItem({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.customerID,
    required this.customerCode,
    required this.customerName,
    this.salesAgent,
    required this.subtotal,
    required this.taxAmt,
    required this.finalTotal,
    required this.paymentTotal,
    required this.outstanding,
    this.description,
    this.remark,
    required this.isVoid,
  });

  factory SalesListItem.fromJson(Map<String, dynamic> json) => SalesListItem(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        customerID: (json['customerID'] as int?) ?? 0,
        customerCode: (json['customerCode'] as String?) ?? '',
        customerName: (json['customerName'] as String?) ?? '',
        salesAgent: json['salesAgent'] as String?,
        subtotal: _toD(json['subtotal']),
        taxAmt: _toD(json['taxAmt']),
        finalTotal: _toD(json['finalTotal']),
        paymentTotal: _toD(json['paymentTotal']),
        outstanding: _toD(json['outstanding']),
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
      );
}

class SalesDetailLine {
  final int dtlID;
  final int docID;
  final int stockID;
  final String stockCode;
  final String description;
  final String uom;
  final double qty;
  final double unitPrice;
  final String? discountText;
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

  SalesDetailLine({
    required this.dtlID,
    required this.docID,
    required this.stockID,
    required this.stockCode,
    required this.description,
    required this.uom,
    required this.qty,
    required this.unitPrice,
    this.discountText,
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

  factory SalesDetailLine.fromJson(Map<String, dynamic> json) =>
      SalesDetailLine(
        dtlID: (json['dtlID'] as int?) ?? 0,
        docID: (json['docID'] as int?) ?? 0,
        stockID: (json['stockID'] as int?) ?? 0,
        stockCode: (json['stockCode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        uom: (json['uom'] as String?) ?? '',
        qty: _toD(json['qty']),
        unitPrice: _toD(json['unitPrice']),
        discountText: (json['discountText'] as String?) ?? '',
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

class SalesDoc {
  final int docID;
  final String docNo;
  final String docDate;
  final int customerID;
  final String customerCode;
  final String customerName;
  final String? salesAgent;
  final double subtotal;
  final double taxAmt;
  final double finalTotal;
  final double paymentTotal;
  final double outstanding;
  final String? description;
  final String? remark;
  final bool isVoid;
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
  final double taxableAmt;
  final int? shippingMethodID;
  final String? shippingMethodDescription;
  final String? qtDocNo;
  final bool isPicking;
  final bool isPacking;
  final String? pickingDocNo;
  final List<SalesDetailLine> salesDetails;

  const SalesDoc({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.customerID,
    required this.customerCode,
    required this.customerName,
    this.salesAgent,
    required this.subtotal,
    required this.taxAmt,
    required this.finalTotal,
    required this.paymentTotal,
    required this.outstanding,
    this.description,
    this.remark,
    required this.isVoid,
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
    required this.taxableAmt,
    this.shippingMethodID,
    this.shippingMethodDescription,
    this.qtDocNo,
    required this.isPicking,
    required this.isPacking,
    this.pickingDocNo,
    required this.salesDetails,
  });

  factory SalesDoc.fromJson(Map<String, dynamic> json) => SalesDoc(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        customerID: (json['customerID'] as int?) ?? 0,
        customerCode: (json['customerCode'] as String?) ?? '',
        customerName: (json['customerName'] as String?) ?? '',
        salesAgent: json['salesAgent'] as String?,
        subtotal: _toD(json['subtotal']),
        taxAmt: _toD(json['taxAmt']),
        finalTotal: _toD(json['finalTotal']),
        paymentTotal: _toD(json['paymentTotal']),
        outstanding: _toD(json['outstanding']),
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
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
        taxableAmt: _toD(json['taxableAmt']),
        shippingMethodID: (json['shippingMethodID'] as int?) ?? 0,
        shippingMethodDescription:
            json['shippingMethodDescription'] as String?,
        qtDocNo: json['qtDocNo'] as String?,
        isPicking: (json['isPicking'] as bool?) ?? false,
        isPacking: (json['isPacking'] as bool?) ?? false,
        pickingDocNo: json['pickingDocNo'] as String?,
        salesDetails: (json['salesDetails'] as List<dynamic>?)
                ?.map(
                    (e) => SalesDetailLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class SalesResponse {
  final List<SalesListItem>? data;
  final Pagination? pagination;

  const SalesResponse({this.data, this.pagination});

  factory SalesResponse.fromJson(Map<String, dynamic> json) => SalesResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) => SalesListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(
                json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}

class CustomerPurchaseStock {
  final int stockID;
  final String stockCode;
  final String description;
  final String uom;
  final double totalQty;
  final double unitPrice;
  final double totalAmt;
  final String? lastPurchaseDate;

  const CustomerPurchaseStock({
    required this.stockID,
    required this.stockCode,
    required this.description,
    required this.uom,
    required this.totalQty,
    required this.unitPrice,
    required this.totalAmt,
    this.lastPurchaseDate,
  });

  factory CustomerPurchaseStock.fromJson(Map<String, dynamic> json) =>
      CustomerPurchaseStock(
        stockID: (json['stockID'] as int?) ?? 0,
        stockCode: (json['stockCode'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        uom: (json['uom'] as String?) ?? '',
        totalQty: _toD(json['totalQty']),
        unitPrice: _toD(json['unitPrice']),
        totalAmt: _toD(json['totalAmt']),
        lastPurchaseDate: json['lastPurchaseDate'] as String?,
      );
}

class CustomerPurchaseResponse {
  final List<CustomerPurchaseStock>? data;
  final Pagination? pagination;

  const CustomerPurchaseResponse({this.data, this.pagination});

  factory CustomerPurchaseResponse.fromJson(Map<String, dynamic> json) =>
      CustomerPurchaseResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) =>
                CustomerPurchaseStock.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(
                json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}
