import 'Pagination.dart';

class SupplierType {
  int supplierTypeID;
  String? description;
  String? desc2;
  bool isDisabled;

  SupplierType({
    required this.supplierTypeID,
    this.description,
    this.desc2,
    required this.isDisabled,
  });

  factory SupplierType.fromJson(Map<String, dynamic> json) {
    return SupplierType(
      supplierTypeID: json['supplierTypeID'] as int,
      description: json['description'] as String?,
      desc2: json['desc2'] as String?,
      isDisabled: json['isDisabled'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supplierTypeID': supplierTypeID,
      'description': description,
      'desc2': desc2,
      'isDisabled': isDisabled,
    };
  }
}

class Supplier {
  int supplierID;
  String? supplierCode;
  String? name;
  String? name2;
  String? address1;
  String? address2;
  String? address3;
  String? address4;
  String? postCode;
  String? attention;
  String? phone1;
  String? phone2;
  String? fax1;
  String? fax2;
  String? email;
  String lastModifiedDateTime;
  int lastModifiedUserID;
  String createdDateTime;
  int createdUserID;
  int supplierTypeID;
  SupplierType? supplierType;

  Supplier({
    required this.supplierID,
    this.supplierCode,
    this.name,
    this.name2,
    this.address1,
    this.address2,
    this.address3,
    this.address4,
    this.postCode,
    this.attention,
    this.phone1,
    this.phone2,
    this.fax1,
    this.fax2,
    this.email,
    required this.lastModifiedDateTime,
    required this.lastModifiedUserID,
    required this.createdDateTime,
    required this.createdUserID,
    required this.supplierTypeID,
    this.supplierType,
  });

  factory Supplier.fromJson(Map<String, dynamic> json) {
    return Supplier(
      supplierID: (json['supplierID'] as int?) ?? 0,
      supplierCode: json['supplierCode'] as String?,
      name: json['name'] as String?,
      name2: json['name2'] as String?,
      address1: json['address1'] as String?,
      address2: json['address2'] as String?,
      address3: json['address3'] as String?,
      address4: json['address4'] as String?,
      postCode: json['postCode'] as String?,
      attention: json['attention'] as String?,
      phone1: json['phone1'] as String?,
      phone2: json['phone2'] as String?,
      fax1: json['fax1'] as String?,
      fax2: json['fax2'] as String?,
      email: json['email'] as String?,
      lastModifiedDateTime: (json['lastModifiedDateTime'] as String?) ?? '',
      lastModifiedUserID: (json['lastModifiedUserID'] as int?) ?? 0,
      createdDateTime: (json['createdDateTime'] as String?) ?? '',
      createdUserID: (json['createdUserID'] as int?) ?? 0,
      supplierTypeID: (json['supplierTypeID'] as int?) ?? 0,
      supplierType: json['supplierType'] is Map<String, dynamic>
          ? SupplierType.fromJson(json['supplierType'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'supplierID': supplierID,
      'supplierCode': supplierCode,
      'name': name,
      'name2': name2,
      'address1': address1,
      'address2': address2,
      'address3': address3,
      'address4': address4,
      'postCode': postCode,
      'attention': attention,
      'phone1': phone1,
      'phone2': phone2,
      'fax1': fax1,
      'fax2': fax2,
      'email': email,
      'lastModifiedDateTime': lastModifiedDateTime,
      'lastModifiedUserID': lastModifiedUserID,
      'createdDateTime': createdDateTime,
      'createdUserID': createdUserID,
      'supplierTypeID': supplierTypeID,
      'supplierType': supplierType?.toJson(),
    };
  }
}

class SupplierResponse {
  final List<Supplier>? data;
  final Pagination? pagination;

  const SupplierResponse({this.data, this.pagination});

  factory SupplierResponse.fromJson(Map<String, dynamic> json) =>
      SupplierResponse(
        data: (json['data'] as List<dynamic>?)
            ?.map((e) => Supplier.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination: json['paginationOpt'] != null
            ? Pagination.fromJson(
                json['paginationOpt'] as Map<String, dynamic>)
            : null,
      );
}
