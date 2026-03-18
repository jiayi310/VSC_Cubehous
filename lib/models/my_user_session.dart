class MyUserSession {
  String? userSessionID;
  int? userID;
  String? email;
  String? name;
  String? phone;
  String? profileImage;
  int? userMappingID;
  int? userTypeID;
  String? userType;
  int? companyID;
  String? companyName;
  String? companyGUID;
  String? apiKey;
  int? salesDecimalPoint;
  int? purchaseDecimalPoint;
  int? quantityDecimalPoint;
  int? costDecimalPoint;
  bool? isAutoBatchNo;
  String? batchNoFormat;
  bool? isEnableTax;
  int? maxUserCount;
  String? licenseTypeName;
  int? licenseID;
  int? defaultLocationID;
  int? defaultSalesAgentID;
  String? smtpEmail;
  String? smtpHost;
  String? smtpPassword;

  MyUserSession.fromJson(Map<String, dynamic> json)
      : userSessionID = json['userSessionID'],
        userID = json['userID'],
        email = json['email'],
        name = json['name'],
        phone = json['phone'],
        profileImage = json['profileImage'],
        userMappingID = json['userMappingID'],
        userTypeID = json['userTypeID'],
        userType = json['userType'],
        companyID = json['companyID'],
        companyName = json['companyName'],
        companyGUID = json['companyGUID'],
        apiKey = json['apiKey'],
        salesDecimalPoint = json['salesDecimalPoint'],
        purchaseDecimalPoint = json['purchaseDecimalPoint'],
        quantityDecimalPoint = json['quantityDecimalPoint'],
        costDecimalPoint = json['costDecimalPoint'],
        isAutoBatchNo = json['isAutoBatchNo'],
        batchNoFormat = json['batchNoFormat'],
        isEnableTax = json['isEnableTax'],
        maxUserCount = json['maxUserCount'],
        licenseTypeName = json['licenseTypeName'],
        licenseID = json['licenseID'],
        defaultLocationID = json['defaultLocationID'],
        defaultSalesAgentID = json['defaultSalesAgentID'],
        smtpEmail = json['smtpEmail'],
        smtpHost = json['smtpHost'],
        smtpPassword = json['smtpPassword'];
}

class UserProfile {
  int? userProfileID;
  String? description;
  bool? enableFilterCustomerBySalesAgent;
  bool? enableFilterStockByStockCategory;
  bool? enableFilterStockByStockGroup;
  bool? enableFilterStockByStockType;
  List<int>? filterCustomerBySalesAgentIdList;
  List<int>? filterStockByStockCategoryIdList;
  List<int>? filterStockByStockGroupIdList;
  List<int>? filterStockByStockTypeIdList;
  bool? includeNullCustomerBySalesAgent;
  bool? includeNullStockByStockCategory;
  bool? includeNullStockByStockGroup;
  bool? includeNullStockByStockType;

  UserProfile.fromJson(Map<String, dynamic> json)
      : userProfileID = json['userProfileID'],
        description = json['description'],
        enableFilterCustomerBySalesAgent = json['enableFilterCustomerBySalesAgent'],
        enableFilterStockByStockCategory = json['enableFilterStockByStockCategory'],
        enableFilterStockByStockGroup = json['enableFilterStockByStockGroup'],
        enableFilterStockByStockType = json['enableFilterStockByStockType'],
        filterCustomerBySalesAgentIdList = json['filterCustomerBySalesAgentIdList'] != null
            ? List<int>.from(json['filterCustomerBySalesAgentIdList'])
            : null,
        filterStockByStockCategoryIdList = json['filterStockByStockCategoryIdList'] != null
            ? List<int>.from(json['filterStockByStockCategoryIdList'])
            : null,
        filterStockByStockGroupIdList = json['filterStockByStockGroupIdList'] != null
            ? List<int>.from(json['filterStockByStockGroupIdList'])
            : null,
        filterStockByStockTypeIdList = json['filterStockByStockTypeIdList'] != null
            ? List<int>.from(json['filterStockByStockTypeIdList'])
            : null,
        includeNullCustomerBySalesAgent = json['includeNullCustomerBySalesAgent'],
        includeNullStockByStockCategory = json['includeNullStockByStockCategory'],
        includeNullStockByStockGroup = json['includeNullStockByStockGroup'],
        includeNullStockByStockType = json['includeNullStockByStockType'];
}