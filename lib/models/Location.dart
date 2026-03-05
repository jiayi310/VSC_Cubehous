class Location {
  int locationID;
  String? location;
  String? address1;
  String? address2;
  String? address3;
  String? address4;
  String? postCode;
  String? phone1;
  String? phone2;
  String? fax1;
  String? fax2;
  bool isActive;
  String lastModifiedDateTime;
  int lastModifiedUserID;
  String createdDateTime;
  int createdUserID;

  Location({
    required this.locationID,
    this.location,
    this.address1,
    this.address2,
    this.address3,
    this.address4,
    this.postCode,
    this.phone1,
    this.phone2,
    this.fax1,
    this.fax2,
    required this.isActive,
    required this.lastModifiedDateTime,
    required this.lastModifiedUserID,
    required this.createdDateTime,
    required this.createdUserID,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      locationID: json['locationID'] as int,
      location: json['location'] as String?,
      address1: json['address1'] as String?,
      address2: json['address2'] as String?,
      address3: json['address3'] as String?,
      address4: json['address4'] as String?,
      postCode: json['postCode'] as String?,
      phone1: json['phone1'] as String?,
      phone2: json['phone2'] as String?,
      fax1: json['fax1'] as String?,
      fax2: json['fax2'] as String?,
      isActive: json['isActive'] as bool,
      lastModifiedDateTime: json['lastModifiedDateTime'] as String,
      lastModifiedUserID: json['lastModifiedUserID'] as int,
      createdDateTime: json['createdDateTime'] as String,
      createdUserID: json['createdUserID'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'locationID': locationID,
      'location': location,
      'address1': address1,
      'address2': address2,
      'address3': address3,
      'address4': address4,
      'postCode': postCode,
      'phone1': phone1,
      'phone2': phone2,
      'fax1': fax1,
      'fax2': fax2,
      'isActive': isActive,
      'lastModifiedDateTime': lastModifiedDateTime,
      'lastModifiedUserID': lastModifiedUserID,
      'createdDateTime': createdDateTime,
      'createdUserID': createdUserID,
    };
  }
}
