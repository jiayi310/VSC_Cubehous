import 'Pagination.dart';

class Customer {
  final int customerID;
  final String customerCode;
  final String name;
  final String name2;
  final String? address1;
  final String? address2;
  final String? address3;
  final String? address4;
  final String? postCode;
  final String? deliverAddr1;
  final String? deliverAddr2;
  final String? deliverAddr3;
  final String? deliverAddr4;
  final String? deliverPostCode;
  final String? attention;
  final String? phone1;
  final String? phone2;
  final String? fax1;
  final String? fax2;
  final String? email;
  final int priceCategory;
  final int? customerTypeID;
  final String customerType;
  final int? salesAgentID;
  final String salesAgent;

  const Customer({
    required this.customerID,
    required this.customerCode,
    required this.name,
    required this.name2,
    this.address1,
    this.address2,
    this.address3,
    this.address4,
    this.postCode,
    this.deliverAddr1,
    this.deliverAddr2,
    this.deliverAddr3,
    this.deliverAddr4,
    this.deliverPostCode,
    this.attention,
    this.phone1,
    this.phone2,
    this.fax1,
    this.fax2,
    this.email,
    required this.priceCategory,
    this.customerTypeID,
    required this.customerType,
    this.salesAgentID,
    required this.salesAgent,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        customerID: (json['customerID'] as int?) ?? 0,
        customerCode: (json['customerCode'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        name2: (json['name2'] as String?) ?? '',
        address1: json['address1'] as String?,
        address2: json['address2'] as String?,
        address3: json['address3'] as String?,
        address4: json['address4'] as String?,
        postCode: json['postCode'] as String?,
        deliverAddr1: json['deliverAddr1'] as String?,
        deliverAddr2: json['deliverAddr2'] as String?,
        deliverAddr3: json['deliverAddr3'] as String?,
        deliverAddr4: json['deliverAddr4'] as String?,
        deliverPostCode: json['deliverPostCode'] as String?,
        attention: json['attention'] as String?,
        phone1: json['phone1'] as String?,
        phone2: json['phone2'] as String?,
        fax1: json['fax1'] as String?,
        fax2: json['fax2'] as String?,
        email: json['email'] as String?,
        priceCategory: (json['priceCategory'] as int?) ?? 1,
        customerTypeID: json['customerTypeID'] as int?,
        customerType: (json['customerType'] as String?) ?? '',
        salesAgentID: json['salesAgentID'] as int?,
        salesAgent: (json['salesAgent'] as String?) ?? '',
      );

  String get addressLine {
    final parts = [address1, address2, address3, address4]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.join(', ');
  }
}

class CustomerResponse {
  final List<Customer>? data;
  final Pagination? pagination;

  const CustomerResponse({this.data, this.pagination});

  factory CustomerResponse.fromJson(Map<String, dynamic> json) =>
      CustomerResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) => Customer.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(
                json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}
