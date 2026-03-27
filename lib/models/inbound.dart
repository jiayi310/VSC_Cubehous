import 'pagination.dart';

double _toD(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

// ── List item ──────────────────────────────────────────────────────────

class InboundListItem {
  final int docID;
  final String docNo;
  final String docDate;
  final String docType; // 'GRN' | 'PUT'
  final String? refDocNo; // PO No for GRN, GRN No for PUT
  final String? description;
  final String? remark;
  final bool isVoid;

  const InboundListItem({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.docType,
    this.refDocNo,
    this.description,
    this.remark,
    required this.isVoid,
  });

  factory InboundListItem.fromJson(Map<String, dynamic> json) =>
      InboundListItem(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        docType: (json['docType'] as String?) ?? '',
        refDocNo: json['refDocNo'] as String?,
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
      );
}

// ── Detail line ────────────────────────────────────────────────────────

class InboundDetailLine {
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
  final String? image;

  const InboundDetailLine({
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

  factory InboundDetailLine.fromJson(Map<String, dynamic> json) =>
      InboundDetailLine(
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
        image: json['image'] as String?,
      );
}

// ── Full document ──────────────────────────────────────────────────────

class InboundDoc {
  final int docID;
  final String docNo;
  final String docDate;
  final String docType; // 'GRN' | 'PUT'
  final String? description;
  final String? remark;
  final bool isVoid;
  final List<InboundDetailLine> lines;

  const InboundDoc({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.docType,
    this.description,
    this.remark,
    required this.isVoid,
    required this.lines,
  });

  factory InboundDoc.fromJson(Map<String, dynamic> json) => InboundDoc(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        docType: (json['docType'] as String?) ?? '',
        description: json['description'] as String?,
        remark: json['remark'] as String?,
        isVoid: (json['isVoid'] as bool?) ?? false,
        lines: (json['lines'] as List<dynamic>?)
                ?.map((e) =>
                    InboundDetailLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

// ── Paginated list response ────────────────────────────────────────────

class InboundResponse {
  final List<InboundListItem>? data;
  final Pagination? pagination;

  const InboundResponse({this.data, this.pagination});

  factory InboundResponse.fromJson(Map<String, dynamic> json) =>
      InboundResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) =>
                InboundListItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(
                json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}
