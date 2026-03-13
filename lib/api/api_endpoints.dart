// All API endpoint paths used in the app.
// Base URL is defined in base_client.dart.
// For endpoints with query parameters, use the helper methods below.

class ApiEndpoints {
  ApiEndpoints._();

  // ── Version ────────────────────────────────────
  static const String getMobileAppVersionInfo =
      '/VersionCheck/GetMobileAppVersionInfo';

  // ── User / Auth ────────────────────────────────
  static const String validateUserLogin = '/User/ValidateUserLogin';
  static const String getUser = '/User/GetUser';
  static const String getCompanySelectionList =
      '/User/GetCompanySelectionList';
  static const String updateMobileRemember = '/User/UpdateMobileRemember';
  static const String validateMobileRemember = '/User/ValidateMobileRemember';
  static const String createUserSession = '/User/CreateUserSession';

  // ── Quotation ──────────────────────────────────
  static const String getQuotationList = '/Quotation/GetQuotationListByCompanyId';
  static const String getQuotation = '/Quotation/GetQuotation';
  static const String createQuotation = '/Quotation/CreateQuotation';

  // ── Sales ──────────────────────────────────────
  static const String getSalesList = '/Sales/GetSalesListByCompanyId';
  static const String getSalesListForCollect = '/Sales/GetSalesListAvailableForCollect';
  static const String getSales = '/Sales/GetSales';
  static const String createSales = '/Sales/CreateSales';

  // ── Tax Type ───────────────────────────────────
  static const String getTaxList = '/TaxType/GeTaxListByCompanyId';

  // ── Stock ──────────────────────────────────────
  static const String getStockList = '/Stock/GetStockListByCompanyId';
  static const String getStockMaxPrice = '/Stock/GetMaxPrice';
  static const String getStock = '/Stock/GetStock';
  static const String getStockBalance = '/Stock/GetStockBalance';
  static const String getSpecificStockBalance = '/Stock/GetSpecificStockBalance';
  static const String getCustomerPurchaseStock = '/Stock/GetCustomerPurchaseStock';

  // ── Customer ───────────────────────────────────
  static const String getCustomerList = '/Customer/GetCustomerList';
  static const String getCustomer = '/Customer/GetCustomer';
  static const String createCustomer = '/Customer/CreateCustomer';
  static const String updateCustomer = '/Customer/UpdateCustomer';

  // ── Customer Type ───────────────────────────────
  static const String getCustomerTypeList = '/CustomerType/GetCustomerTypeList';

  // ── Location ───────────────────────────────────
  static const String getLocationList = '/Location/GetLocationList';
  static const String getLocation = '/Location/GetLocation';
  static const String getLocationWithStorage = '/Location/GetLocationWithStorage';

  // ── Supplier ───────────────────────────────────
  static const String getSupplierList = '/Supplier/GetSupplierList';

   // ── Supplier Type ───────────────────────────────
  static const String getSupplierTypeList = '/SupplierType/GetSupplierTypeList';

  // ── Collection ─────────────────────────────────
  static const String getCollectionList = '/Collection/GetCollectListByCompany';
  static const String getCollection = '/Collection/GetCollection';
  static const String createCollection = '/Collection/CreateCollection';
  static const String getPaymentTypeList = '/Collection/GetPaymentTypeList';

  // ── Sales Agent ─────────────────────────────────
  static const String getSalesAgentList = '/SalesAgent/GetSalesAgentList';

  // ── Stock Filter Options ────────────────────────
  static const String getStockGroupList = '/StockGroup/GetStockGroupListByCompanyId';
  static const String getStockTypeList = '/StockType/GetStockTypeListByCompanyId';
  static const String getStockCategoryList = '/StockCategory/GetStockCategoryListByCompanyId';

  // ── Query helpers ──────────────────────────────

  static String getMobileAppVersionInfoQ(String secretKey) =>
      '$getMobileAppVersionInfo?secretKey=$secretKey';

  static String validateUserLoginQ(String email, String password) =>
      '$validateUserLogin?email=${Uri.encodeComponent(email)}&password=${Uri.encodeComponent(password)}';

  static String getUserQ(int userId) => '$getUser?userid=$userId';

  static String getCompanySelectionListQ(int userId) =>
      '$getCompanySelectionList?userid=$userId';

  static String updateMobileRememberQ(String email, int grant) =>
      '$updateMobileRemember?email=${Uri.encodeComponent(email)}&grant=$grant';

  static String validateMobileRememberQ(String email, String token) =>
      '$validateMobileRemember?email=${Uri.encodeComponent(email)}&token=${Uri.encodeComponent(token)}';

  static String createUserSessionQ(int userMappingId) =>
      '$createUserSession?usermappingid=$userMappingId';
}
