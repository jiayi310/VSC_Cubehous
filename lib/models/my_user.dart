class MyUser {
  int? userID;
  String? email;
  String? name;
  String? phone;
  String? profileImage;
  bool? isActive;
  String? lastModifiedDateTime;
  int? lastModifiedUserID;
  String? createdDateTime;
  int? createdUserID;
  int? controlAccountID;
  int? controlAccount;

  MyUser({
    this.userID,
    this.email,
    this.name,
    this.phone,
    this.profileImage,
    this.isActive,
    this.lastModifiedDateTime,
    this.lastModifiedUserID,
    this.createdDateTime,
    this.createdUserID,
    this.controlAccountID,
    this.controlAccount,
  });

  factory MyUser.fromJson(Map<String, dynamic> json) {
    return MyUser(
      userID: json['userID'] as int?,
      email: json['email'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      profileImage: json['profileImage'] as String?,
      isActive: json['isActive'] as bool?,
      lastModifiedDateTime: json['lastModifiedDateTime'] as String?,
      lastModifiedUserID: json['lastModifiedUserID'] as int?,
      createdDateTime: json['createdDateTime'] as String?,
      createdUserID: json['createdUserID'] as int?,
      controlAccountID: json['controlAccountID'] as int?,
      controlAccount: json['controlAccount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userID': userID,
      'email': email,
      'name': name,
      'phone': phone,
      'profileImage': profileImage,
      'isActive': isActive,
      'lastModifiedDateTime': lastModifiedDateTime,
      'lastModifiedUserID': lastModifiedUserID,
      'createdDateTime': createdDateTime,
      'createdUserID': createdUserID,
      'controlAccountID': controlAccountID,
      'controlAccount': controlAccount,
    };
  }

}