import 'SalesAgent.dart';

class CustomerType {
  int customerTypeID;
  String? description;
  String? desc2;
  bool isActive;

  CustomerType({
    required this.customerTypeID,
    this.description,
    this.desc2,
    required this.isActive,
  });

  factory CustomerType.fromJson(Map<String, dynamic> json) {
    return CustomerType(
      customerTypeID: json['customerTypeID'] as int,
      description: json['description'] as String,
      desc2: json['desc2'] as String,
      isActive: json['isActive'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerTypeID': customerTypeID,
      'description': description,
      'desc2': desc2,
      'isActive': isActive,
    };
  }
}

class Customer {
  int? customerID;
  String? customerCode;
  String? name;
  String? name2;
  String? address1;
  String? address2;
  String? address3;
  String? address4;
  String? postCode;
  String? deliverAddr1;
  String? deliverAddr2;
  String? deliverAddr3;
  String? deliverAddr4;
  String? deliverPostCode;
  String? attention;
  String? phone1;
  String? phone2;
  String? fax1;
  String? fax2;
  String? email;
  int priceCategory;
  String lastModifiedDateTime;
  int lastModifiedUserID;
  String createdDateTime;
  int createdUserID;
  int? customerTypeID;
  int? salesAgentID;
  CustomerType? customerType;
  SalesAgent? salesAgent;

  Customer({
    this.customerID,
    this.customerCode,
    this.name,
    this.name2,
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
    required this.lastModifiedDateTime,
    required this.lastModifiedUserID,
    required this.createdDateTime,
    required this.createdUserID,
    this.customerTypeID,
    this.salesAgentID,
    this.customerType,
    this.salesAgent,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      customerID: json['customerID'] as int?,
      customerCode: json['customerCode'] as String?,
      name: json['name'] as String?,
      name2: json['name2'] as String?,
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
      priceCategory: json['priceCategory'] as int,
      lastModifiedDateTime: json['lastModifiedDateTime'] as String,
      lastModifiedUserID: json['lastModifiedUserID'] as int,
      createdDateTime: json['createdDateTime'] as String,
      createdUserID: json['createdUserID'] as int,
      customerTypeID: json['customerTypeID'] as int?,
      salesAgentID: json['salesAgentID'] as int?,
      customerType: json['customerType'] != null ? CustomerType.fromJson(json['customerType']) : null,
      salesAgent: json['salesAgent'] != null ? SalesAgent.fromJson(json['salesAgent']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'customerID': customerID,
      'customerCode': customerCode,
      'name': name,
      'name2': name2,
      'address1': address1,
      'address2': address2,
      'address3': address3,
      'address4': address4,
      'postCode': postCode,
      'deliverAddr1': deliverAddr1,
      'deliverAddr2': deliverAddr2,
      'deliverAddr3': deliverAddr3,
      'deliverAddr4': deliverAddr4,
      'deliverPostCode': deliverPostCode,
      'attention': attention,
      'phone1': phone1,
      'phone2': phone2,
      'fax1': fax1,
      'fax2': fax2,
      'email': email,
      'priceCategory': priceCategory,
      'lastModifiedDateTime': lastModifiedDateTime,
      'lastModifiedUserID': lastModifiedUserID,
      'createdDateTime': createdDateTime,
      'createdUserID': createdUserID,
      'customerTypeID': customerTypeID,
      'salesAgentID': salesAgentID,
      'customerType': customerType?.toJson(),
      'salesAgent': salesAgent?.toJson(),
    };
  }
}
