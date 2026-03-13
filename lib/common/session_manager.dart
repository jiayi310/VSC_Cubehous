import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionManager {
  static const _storage = FlutterSecureStorage();

  // ── Write ────────────────────────────────────

  static Future<void> saveSession({
    required int userID,
    required int userMappingID,
    required int companyID,
    required int defaultLocationID,
    required String username,
    required String companyName,
    required String userSessionID,
    required String companyGUID,
    required String apiKey,
    required bool isEnableTax,
    required bool isAutoBatchNo,
    String? batchNoFormat,
    int salesDecimalPoint = 2,
    int purchaseDecimalPoint = 2,
    int quantityDecimalPoint = 2,
    int costDecimalPoint = 2,
  }) async {
    await Future.wait([
      _storage.write(key: 'userid', value: userID.toString()),
      _storage.write(key: 'userMappingID', value: userMappingID.toString()),
      _storage.write(key: 'companyid', value: companyID.toString()),
      _storage.write(key: 'defaultLocation', value: defaultLocationID.toString()),
      _storage.write(key: 'username', value: username),
      _storage.write(key: 'companyName', value: companyName),
      _storage.write(key: 'userSessionID', value: userSessionID),
      _storage.write(key: 'companyGUID', value: companyGUID),
      _storage.write(key: 'apiKey', value: apiKey),
      _storage.write(key: 'isEnableTax', value: isEnableTax.toString()),
      _storage.write(key: 'isAutoBatchNo', value: isAutoBatchNo.toString()),
      _storage.write(key: 'batchNoFormat', value: batchNoFormat ?? ''),
      _storage.write(key: 'salesDecimalPoint', value: salesDecimalPoint.toString()),
      _storage.write(key: 'purchaseDecimalPoint', value: purchaseDecimalPoint.toString()),
      _storage.write(key: 'quantityDecimalPoint', value: quantityDecimalPoint.toString()),
      _storage.write(key: 'costDecimalPoint', value: costDecimalPoint.toString()),
    ]);
  }

  // ── Read ─────────────────────────────────────

  static Future<String> getUsername() async =>
      await _storage.read(key: 'username') ?? '';

  static Future<String> getProfileImage() async =>
      await _storage.read(key: 'profileImage') ?? '';

  static Future<void> saveProfileImage(String url) =>
      _storage.write(key: 'profileImage', value: url);

  static Future<String> getCompanyName() async =>
      await _storage.read(key: 'companyName') ?? '';

  static Future<int> getUserID() async =>
      int.tryParse(await _storage.read(key: 'userid') ?? '') ?? 0;

  static Future<int> getCompanyID() async =>
      int.tryParse(await _storage.read(key: 'companyid') ?? '') ?? 0;

  static Future<bool> getUserIsActive() async =>
      (await _storage.read(key: 'userIsActive')) == 'true';

  static Future<int> getDefaultLocationID() async =>
      int.tryParse(await _storage.read(key: 'defaultLocation') ?? '') ?? 0;

  static Future<int> getUserMappingID() async =>
      int.tryParse(await _storage.read(key: 'userMappingID') ?? '') ?? 0;

  static Future<String> getUserSessionID() async =>
      await _storage.read(key: 'userSessionID') ?? '';

  static Future<String> getApiKey() async =>
      await _storage.read(key: 'apiKey') ?? '';

  static Future<String> getCompanyGUID() async =>
      await _storage.read(key: 'companyGUID') ?? '';

  static Future<bool> getIsEnableTax() async =>
      (await _storage.read(key: 'isEnableTax')) == 'true';

  static Future<bool> getIsAutoBatchNo() async =>
      (await _storage.read(key: 'isAutoBatchNo')) == 'true';

  static Future<String?> getBatchNoFormat() =>
      _storage.read(key: 'batchNoFormat');

  static Future<int> getSalesDecimalPoint() async =>
      int.tryParse(await _storage.read(key: 'salesDecimalPoint') ?? '') ?? 2;

  static Future<int> getPurchaseDecimalPoint() async =>
      int.tryParse(await _storage.read(key: 'purchaseDecimalPoint') ?? '') ?? 2;

  static Future<int> getQuantityDecimalPoint() async =>
      int.tryParse(await _storage.read(key: 'quantityDecimalPoint') ?? '') ?? 2;

  static Future<int> getCostDecimalPoint() async =>
      int.tryParse(await _storage.read(key: 'costDecimalPoint') ?? '') ?? 2;

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

  static Future<void> saveDisplayMode(String mode) =>
      _storage.write(key: 'displayMode', value: mode);

  /// Returns 'grid' or 'list'. Defaults to 'grid'.
  static Future<String> getDisplayMode() async =>
      await _storage.read(key: 'displayMode') ?? 'grid';

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
}
