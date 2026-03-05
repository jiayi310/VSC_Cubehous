class MyUser {
  int? userID;
  String? email;
  String? name;
  String? phone;
  String? profileImage;
  bool? isActive;
  bool? isSuperAdmin;
  bool? isControlAcc;
  String? lastModifiedDateTime;
  String? createdDateTime;
  int? lastModifiedUserID;
  int? createdUserID;
  List<String> accessRights = [];

  MyUser({
    this.userID,
    this.email,
    this.name,
    this.phone,
    this.profileImage,
    this.isActive,
    this.isSuperAdmin,
    this.isControlAcc,
    this.lastModifiedDateTime,
    this.createdDateTime,
    this.lastModifiedUserID,
    this.createdUserID,
    this.accessRights = const [],
  });

  // Convert JSON to MyUser object
  factory MyUser.fromJson(Map<String, dynamic> json) {
    return MyUser(
      userID: json['userID'] as int?,
      email: json['email'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      profileImage: json['profileImage'] as String?,
      isActive: json['isActive'] as bool?,
      isSuperAdmin: json['isSuperAdmin'] as bool?,
      isControlAcc: json['isControlAcc'] as bool?,
      lastModifiedDateTime: json['lastModifiedDateTime'] as String?,
      createdDateTime: json['createdDateTime'] as String?,
      lastModifiedUserID: json['lastModifiedUserID'] as int?,
      createdUserID: json['createdUserID'] as int?,
      accessRights: List<String>.from(json['accessRights'] as List<dynamic>? ?? []),
    );
  }

  // Convert MyUser object to JSON
  Map<String, dynamic> toJson() {
    return {
      'userID': userID,
      'email': email,
      'name': name,
      'phone': phone,
      'profileImage': profileImage,
      'isActive': isActive,
      'isSuperAdmin': isSuperAdmin,
      'isControlAcc': isControlAcc,
      'lastModifiedDateTime': lastModifiedDateTime,
      'createdDateTime': createdDateTime,
      'lastModifiedUserID': lastModifiedUserID,
      'createdUserID': createdUserID,
      'accessRights': accessRights,
    };
  }
}