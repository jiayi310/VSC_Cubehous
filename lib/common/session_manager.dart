import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SessionManager {
  static const _storage = FlutterSecureStorage();

  // ── Write ────────────────────────────────────

  static Future<void> saveSession({
    required String email,
    required int userID,
    required int userMappingID,
    required int companyID,
    required String userSessionID,
    required String companyGUID,
    required String apiKey,
    required String userType,
    required String username,
    required String companyName,
    required List<String> userAccessRight,
    required List<String> companyModuleIdList,
    int salesDecimalPoint = 2,
    int purchaseDecimalPoint = 2,
    int quantityDecimalPoint = 2,
    int costDecimalPoint = 2,
    bool isAutoBatchNo = false,
    String? batchNoFormat,
    bool isEnableTax = false,
    int? defaultLocationID,
    int? defaultSalesAgentID,
    bool userIsActive = false,
  }) async {
    await Future.wait([
      _storage.write(key: 'email', value: email),
      _storage.write(key: 'userid', value: userID.toString()),
      _storage.write(key: 'userMappingID', value: userMappingID.toString()),
      _storage.write(key: 'companyid', value: companyID.toString()),
      _storage.write(key: 'userSessionID', value: userSessionID),
      _storage.write(key: 'companyGUID', value: companyGUID),
      _storage.write(key: 'apiKey', value: apiKey),
      _storage.write(key: 'userType', value: userType),
      _storage.write(key: 'username', value: username),
      _storage.write(key: 'companyName', value: companyName),
      _storage.write(key: 'userAccessRight', value: jsonEncode(userAccessRight)),
      _storage.write(key: 'companyModuleIdList', value: jsonEncode(companyModuleIdList)),
      _storage.write(key: 'salesDecimalPoint', value: salesDecimalPoint.toString()),
      _storage.write(key: 'purchaseDecimalPoint', value: purchaseDecimalPoint.toString()),
      _storage.write(key: 'quantityDecimalPoint', value: quantityDecimalPoint.toString()),
      _storage.write(key: 'costDecimalPoint', value: costDecimalPoint.toString()),
      _storage.write(key: 'isAutoBatchNo', value: isAutoBatchNo.toString()),
      _storage.write(key: 'batchNoFormat', value: batchNoFormat ?? ''),
      _storage.write(key: 'isEnableTax', value: isEnableTax.toString()),
      _storage.write(key: 'defaultLocationID', value: defaultLocationID?.toString() ?? ''),
      _storage.write(key: 'defaultSalesAgentID', value: defaultSalesAgentID?.toString() ?? ''),
      _storage.write(key: 'userIsActive', value: userIsActive.toString()),
      _storage.write(key: 'currencySymbol', value: 'RM'),
      _storage.write(key: 'dateFormat', value: 'dd/MM/yyyy'),
    ]);
  }

  // ── Read ─────────────────────────────────────

  static Future<String> getUserEmail() async =>
    await _storage.read(key: 'email') ?? '';

  static Future<int> getUserID() async =>
    int.tryParse(await _storage.read(key: 'userid') ?? '') ?? 0;

  static Future<int> getUserMappingID() async =>
    int.tryParse(await _storage.read(key: 'userMappingID') ?? '') ?? 0;

  static Future<int> getCompanyID() async => 
    int.tryParse(await _storage.read(key: 'companyid') ?? '') ?? 0;

  static Future<String> getUserSessionID() async =>
    await _storage.read(key: 'userSessionID') ?? '';

  static Future<String> getCompanyGUID() async =>
    await _storage.read(key: 'companyGUID') ?? '';

  static Future<String> getApiKey() async =>
    await _storage.read(key: 'apiKey') ?? '';

  static Future<String> getUserType() async =>
    await _storage.read(key: 'userType') ?? '';

  static Future<String> getUsername() async =>
    await _storage.read(key: 'username') ?? '';

  static Future<String> getCompanyName() async =>
    await _storage.read(key: 'companyName') ?? '';

  static Future<int> getSalesDecimalPoint() async =>
    int.tryParse(await _storage.read(key: 'salesDecimalPoint') ?? '') ?? 2;

  static Future<int> getPurchaseDecimalPoint() async =>
    int.tryParse(await _storage.read(key: 'purchaseDecimalPoint') ?? '') ?? 2;

  static Future<int> getQuantityDecimalPoint() async =>
    int.tryParse(await _storage.read(key: 'quantityDecimalPoint') ?? '') ?? 2;

  static Future<int> getCostDecimalPoint() async =>
    int.tryParse(await _storage.read(key: 'costDecimalPoint') ?? '') ?? 2;

  static Future<bool> getIsAutoBatchNo() async =>
    (await _storage.read(key: 'isAutoBatchNo')) == 'true';

  static Future<String?> getBatchNoFormat() =>
    _storage.read(key: 'batchNoFormat');

  static Future<bool> getIsEnableTax() async =>
    (await _storage.read(key: 'isEnableTax')) == 'true';

  static Future<int> getDefaultLocationID() async =>
    int.tryParse(await _storage.read(key: 'defaultLocationID') ?? '') ?? 0;

  static Future<int> getDefaultSalesAgentID() async =>
    int.tryParse(await _storage.read(key: 'defaultSalesAgentID') ?? '') ?? 0;

  static Future<bool> getUserIsActive() async =>
    (await _storage.read(key: 'userIsActive')) == 'true';

  static Future<List<String>> getCompanyModuleIdList() async {
    final raw = await _storage.read(key: 'companyModuleIdList') ?? '[]';
    final decoded = jsonDecode(raw);
    return List<String>.from(decoded);
  }

  static Future<List<String>> getUserAccessRight() async {
    final raw = await _storage.read(key: 'userAccessRight') ?? '[]';
    final decoded = jsonDecode(raw);
    return List<String>.from(decoded);
  }

  static Future<String> getProfileImage() async =>
      await _storage.read(key: 'profileImage') ?? '';

  static Future<void> saveProfileImage(String url) =>
      _storage.write(key: 'profileImage', value: url);

  static Future<String> getCurrencySymbol() async =>
      await _storage.read(key: 'currencySymbol') ?? '';

  static Future<String> getDateFormat() async =>
      await _storage.read(key: 'dateFormat') ?? '';

  // ── Remember Me ───────────────────────────────

  static Future<void> saveRememberMe(bool value) =>
      _storage.write(key: 'rememberMe', value: value.toString());

  static Future<bool> getRememberMe() async =>
      (await _storage.read(key: 'rememberMe')) == 'true';

  static Future<void> saveSavedEmail(String email) =>
      _storage.write(key: 'savedEmail', value: email);

  static Future<String> getSavedEmail() async =>
      await _storage.read(key: 'savedEmail') ?? '';

  static Future<void> saveSavedPassword(String password) =>
      _storage.write(key: 'savedPassword', value: password);

  static Future<String> getSavedPassword() async =>
      await _storage.read(key: 'savedPassword') ?? '';

  // ── App Settings ──────────────────────────────

  static Future<void> saveLanguage(String lang) =>
      _storage.write(key: 'appLanguage', value: lang);

  static Future<String> getLanguage() async =>
      await _storage.read(key: 'appLanguage') ?? 'en';

  static Future<void> saveItemsPerPage(int count) =>
      _storage.write(key: 'itemsPerPage', value: count.toString());

  static Future<int> getItemsPerPage() async =>
      int.tryParse(await _storage.read(key: 'itemsPerPage') ?? '') ?? 20;

  static Future<void> saveImageMode(String mode) =>
      _storage.write(key: 'imageMode', value: mode);

  /// Returns 'show' or 'noShow'. Defaults to 'show'.
  static Future<String> getImageMode() async =>
      await _storage.read(key: 'imageMode') ?? 'show';

  // ── Auth Body Helper ──────────────────────────

  /// Returns a fresh Map of the 4 auth fields required by most POST endpoints.
  /// Call this at the start of every API request to ensure renewed sessions
  /// are always used (avoids stale cached local vars).
  static Future<Map<String, dynamic>> authBody() async {
    final results = await Future.wait([
      getApiKey(),
      getCompanyGUID(),
      getUserID(),
      getUserSessionID(),
    ]);
    return {
      'apiKey': results[0],
      'companyGUID': results[1],
      'userID': results[2],
      'userSessionID': results[3],
    };
  }

  // ── Session Renewal ───────────────────────────

  static Future<void> renewSession({
    required String userSessionID,
    required String companyGUID,
    required String apiKey,
    required String userType,
    required List<String> userAccessRight,
    required List<String> companyModuleIdList,
    int salesDecimalPoint = 2,
    int purchaseDecimalPoint = 2,
    int quantityDecimalPoint = 2,
    int costDecimalPoint = 2,
    bool isAutoBatchNo = false,
    String? batchNoFormat,
    bool isEnableTax = false,
    int? defaultLocationID,
    int? defaultSalesAgentID,
  }) async {
    await Future.wait([
      _storage.write(key: 'userSessionID', value: userSessionID),
      _storage.write(key: 'companyGUID', value: companyGUID),
      _storage.write(key: 'apiKey', value: apiKey),
      _storage.write(key: 'userType', value: userType),
      _storage.write(key: 'userAccessRight', value: jsonEncode(userAccessRight)),
      _storage.write(key: 'companyModuleIdList', value: jsonEncode(companyModuleIdList)),
      _storage.write(key: 'salesDecimalPoint', value: salesDecimalPoint.toString()),
      _storage.write(key: 'purchaseDecimalPoint', value: purchaseDecimalPoint.toString()),
      _storage.write(key: 'quantityDecimalPoint', value: quantityDecimalPoint.toString()),
      _storage.write(key: 'costDecimalPoint', value: costDecimalPoint.toString()),
      _storage.write(key: 'isAutoBatchNo', value: isAutoBatchNo.toString()),
      _storage.write(key: 'batchNoFormat', value: batchNoFormat ?? ''),
      _storage.write(key: 'isEnableTax', value: isEnableTax.toString()),
      _storage.write(key: 'defaultLocationID', value: defaultLocationID?.toString() ?? ''),
      _storage.write(key: 'defaultSalesAgentID', value: defaultSalesAgentID?.toString() ?? ''),
      _storage.write(key: 'currencySymbol', value: 'RM'),
      _storage.write(key: 'dateFormat', value: 'dd/MM/yyyy'),
    ]);
  }

  // ── Session Check ─────────────────────────────

  static Future<bool> isLoggedIn() async {
    final userID = await _storage.read(key: 'userid');
    final sessionID = await _storage.read(key: 'userSessionID');
    return userID != null &&
        userID.isNotEmpty &&
        sessionID != null &&
        sessionID.isNotEmpty;
  }

  // ── Clear ─────────────────────────────────────

  /// Clears session data but keeps credentials and user info when remember me is on.
  static Future<void> clearSession() async {
    final rememberMe = await getRememberMe();
    final savedEmail = await getSavedEmail();
    final savedPassword = await getSavedPassword();
    final userID = await getUserID();
    final username = await getUsername();
    final profileImage = await getProfileImage();

    await _storage.deleteAll();

    if (rememberMe) {
      await Future.wait([
        saveRememberMe(true),
        saveSavedEmail(savedEmail),
        saveSavedPassword(savedPassword),
        _storage.write(key: 'userid', value: userID.toString()),
        _storage.write(key: 'username', value: username),
        _storage.write(key: 'profileImage', value: profileImage),
      ]);
    }
  }

  // ── Quotation Draft ──────────────────────────────────────

  static Future<void> saveQuotationDraft(String jsonStr) =>
      _storage.write(key: 'quotation_draft', value: jsonStr);

  static Future<String?> getQuotationDraft() =>
      _storage.read(key: 'quotation_draft');

  static Future<void> clearQuotationDraft() =>
      _storage.delete(key: 'quotation_draft');

  static Future<bool> hasQuotationDraft() async {
    final v = await _storage.read(key: 'quotation_draft');
    return v != null && v.isNotEmpty;
  }

  // ── Collection Draft ──────────────────────────────────────

  static Future<void> saveCollectionDraft(String jsonStr) =>
      _storage.write(key: 'collection_draft', value: jsonStr);

  static Future<String?> getCollectionDraft() =>
      _storage.read(key: 'collection_draft');

  static Future<void> clearCollectionDraft() =>
      _storage.delete(key: 'collection_draft');

  static Future<bool> hasCollectionDraft() async {
    final v = await _storage.read(key: 'collection_draft');
    return v != null && v.isNotEmpty;
  }

  // ── Sales Draft ──────────────────────────────────────

  static Future<void> saveSalesDraft(String jsonStr) =>
      _storage.write(key: 'sales_draft', value: jsonStr);

  static Future<String?> getSalesDraft() =>
      _storage.read(key: 'sales_draft');

  static Future<void> clearSalesDraft() =>
      _storage.delete(key: 'sales_draft');

  static Future<bool> hasSalesDraft() async {
    final v = await _storage.read(key: 'sales_draft');
    return v != null && v.isNotEmpty;
  }


  // ── Stock Take Draft ──────────────────────────────────────

  static Future<void> saveStockTakeDraft(String jsonStr) =>
      _storage.write(key: 'stock_take_draft', value: jsonStr);

  static Future<String?> getStockTakeDraft() =>
      _storage.read(key: 'stock_take_draft');

  static Future<void> clearStockTakeDraft() =>
      _storage.delete(key: 'stock_take_draft');

  static Future<bool> hasStockTakeDraft() async {
    final v = await _storage.read(key: 'stock_take_draft');
    return v != null && v.isNotEmpty;
  }

 // ── Stock Adjustment Draft ──────────────────────────────────────

  static Future<void> saveStockAdjustmentDraft(String jsonStr) =>
      _storage.write(key: 'stock_adjustment_draft', value: jsonStr);

  static Future<String?> getStockAdjustmentDraft() =>
      _storage.read(key: 'stock_adjustment_draft');

  static Future<void> clearStockAdjustmentDraft() =>
      _storage.delete(key: 'stock_adjustment_draft');

  static Future<bool> hasStockAdjustmentDraft() async {
    final v = await _storage.read(key: 'stock_adjustment_draft');
    return v != null && v.isNotEmpty;
  }

  // ── Inbound Draft ──────────────────────────────────────

  static Future<void> saveInboundDraft(String jsonStr) =>
      _storage.write(key: 'inbound_draft', value: jsonStr);

  static Future<String?> getInboundDraft() =>
      _storage.read(key: 'inbound_draft');

  static Future<void> clearInboundDraft() =>
      _storage.delete(key: 'inbound_draft');

  static Future<bool> hasInboundDraft() async {
    final v = await _storage.read(key: 'inbound_draft');
    return v != null && v.isNotEmpty;
  }

}
