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
  static const String updateQuotation = '/Quotation/UpdateQuotation';
  static const String removeQuotation = '/Quotation/RemoveQuotation';
  static const String getQuotationReport = '/Report/GetQuotationReport';

  // ── Analysis ───────────────────────────────────
  static const String getSalesByDateRange = '/Sales/GetSalesByCompanyIdAndDateRange';
  static const String getTotalSalesCount = '/Sales/GetTotalSalesCount';
  static const String getTotalPackingCount = '/Packing/GetTotalPackingCount';
  static const String getStockValue = '/Stock/GetStockValue';
  static const String getTop10SalesQtyByStock = '/Sales/GetTop10SalesQtybyStock';
  static const String getTop10SalesAmtByCustomer = '/Sales/GetTop10SalesAmtByCustomer';
  static const String getTop10Agent = '/Sales/GetTop10Agent';
  static const String getTop10StockInbound = '/Receiving/GetTop10StockInboundByCompanyId';
  static const String getTop10StockOutbound = '/Packing/GetTop10StockOutboundByCompanyId';

  // ── Reports ────────────────────────────────────
  static const String getOutstandingSalesList = '/Sales/GetOutstandingSalesListByCompanyId';
  static const String getSalesDtlListingReport = '/Report/GetSalesDtlListingReport';
  static const String getSalesOutstandingListReport = '/Report/GetSalesOutstandingListReport';


  // ── Sales ──────────────────────────────────────
  static const String getSalesList = '/Sales/GetSalesListByCompanyId';
  static const String getSalesListForCollect = '/Sales/GetSalesListAvailableForCollect';
  static const String getSalesListAvailableForPacking = '/Sales/GetSalesListAvailableForPacking';
  static const String getSales = '/Sales/GetSales';
  static const String createSales = '/Sales/CreateSales';
  static const String updateSales = '/Sales/UpdateSales';
  static const String removeSales = '/Sales/RemoveSales';
  static const String getSalesReport = '/Report/GetSalesReport';

  // ── Tax Type ───────────────────────────────────
  static const String getTaxList = '/TaxType/GeTaxListByCompanyId';

  // ── Stock ──────────────────────────────────────
  static const String getStockList = '/Stock/GetStockListByCompanyId';
  static const String getStockMaxPrice = '/Stock/GetMaxPrice';
  static const String getStock = '/Stock/GetStock';
  static const String getStockByBarcode = '/Stock/GetStockByStockCodeOrBarcode';
  static const String getStockBalance = '/Stock/GetStockBalance';
  static const String getSpecificStockBalance = '/Stock/GetSpecificStockBalance';
  static const String getStockSalesHistory = '/Stock/GetStockSalesHistory';
  static const String getStockPurchaseHistory = '/Stock/GetStockPurchaseHistory';
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
  static const String updateCollection = '/Collection/UpdateCollection';
  static const String removeCollection = '/Collection/RemoveCollection';
  static const String getPaymentTypeList = '/Collection/GetPaymentTypeList';
  static const String getCollectionReport = '/Report/GetCollectionReport';

  // ── Purchase ───────────────────────────────────
  static const String getPurchaseList = '/Purchase/GetPurchaseListByCompanyId';
  static const String getPurchase = '/Purchase/GetPurchase';
  static const String createPurchase = '/Purchase/CreatePurchase';
  static const String removePurchase = '/Purchase/RemovePurchase';
  static const String getPurchaseReport = '/Report/GetPurchaseReport';

  // ── Receiving ───────────────────────────────────
  static const String getReceivingList = '/Receiving/GetReceivingListByCompanyId';
  static const String getReceiving = '/Receiving/GetReceiving';
  static const String createReceiving = '/Receiving/CreateReceiving';
  static const String updateReceiving = '/Receiving/UpdateReceiving';
  static const String removeReceiving = '/Receiving/RemoveReceiving';
  static const String getReceivingReport = '/Report/GetReceivingReport';
  static const String getReceivingPurchaseList = '/Purchase/GetReceivingPurchaseList';

  // ── Packing ───────────────────────────────────
  static const String getPackingList = '/Packing/GetPackingListByCompanyId';
  static const String getPacking = '/Packing/GetPacking';
  static const String createPacking = '/Packing/CreatePacking';
  static const String removePacking= '/Packing/RemovePacking';
  static const String getPackingReport = '/Report/GetPackingReport';

  // ── Sales Agent ─────────────────────────────────
  static const String getSalesAgentList = '/SalesAgent/GetSalesAgentList';

  // ── Shipping Method ──────────────────────────────
  static const String getShippingMethodList = '/ShippingMethod/GetShippingMethodList';

  // ── Stock Take ──────────────────────────────────
  static const String getStockTakeList = '/StockTake/GetStockTakeListByCompanyId';
  static const String getStockTake = '/StockTake/GetStockTake';
  static const String createStockTake = '/StockTake/CreateStockTake';
  static const String updateStockTake = '/StockTake/UpdateStockTake';
  static const String removeStockTake = '/StockTake/RemoveStockTake';
  static const String getStockTakeReport = '/Report/GetStockTakeReport';

  // ── Stock Adjustment ──────────────────────────────────
  static const String getStockAdjustmentList = '/StockAdjustment/GetStockAdjustmentListByCompanyId';
  static const String getStockAdjustment = '/StockAdjustment/GetStockAdjustment';
  static const String createStockAdjustment = '/StockAdjustment/CreateStockAdjustment';
  static const String updateStockAdjustment = '/StockTake/UpdateStockAdjustment';
  static const String removeStockAdjustment = '/StockAdjustment/RemoveAdjustment';
  static const String getStockAdjustmentReport = '/Report/GetStockAdjustmentReport';

  // ── Inbound ──────────────────────────────────
  static const String getInboundList = '/Inbound/GetInboundListByCompanyId';
  static const String getInbound = '/Inbound/GetInbound';
  static const String createInbound= '/Inbound/CreateInbound';
  static const String updateInbound = '/Inbound/UpdateInbound';
  static const String removeInbound= '/Inbound/RemoveInbound';
  static const String getInboundReport = '/Report/GetInboundReport';

  // ── Stock Batch ──────────────────────────────────
  static const String createStockBatch = '/StockBatch/CreateStockBatch';

  // ── Put Away ──────────────────────────────────
  static const String getPutAwayList = '/PutAway/GetPutAwayListByCompanyId';
  static const String getPutAway = '/PutAway/GetPutAway';
  static const String createPutAway = '/PutAway/CreatePutAway';
  static const String removePutAway = '/PutAway/RemovePutAway';

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
