import 'package:cubehous/api/api_endpoints.dart';
import 'package:cubehous/api/base_client.dart';
import 'package:cubehous/common/session_manager.dart';
import 'package:cubehous/models/stock_detail.dart';

class StockCommon {

  static double priceForCategory(StockUOMDto uom, int cat) {
    switch (cat) {
      case 2: return uom.price2;
      case 3: return uom.price3;
      case 4: return uom.price4;
      case 5: return uom.price5;
      case 6: return uom.price6;
      default: return uom.price1;
    }
  }

  /// Fetches StockDetail and returns the price for [uomName] and current
  /// customer price category. Returns null if the call fails.
  static Future<double?> fetchUOMPrice(int stockID, String uomName, int priceCategory) async {
    String apiKey = await SessionManager.getApiKey();
    String companyGUID = await SessionManager.getCompanyGUID();
    int userID = await SessionManager.getUserID();
    String userSessionID = await SessionManager.getUserSessionID();
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getStock,
        body: {
          'apiKey': apiKey,
          'companyGUID': companyGUID,
          'userID': userID,
          'userSessionID': userSessionID,
          'stockID': stockID,
        },
      );
      final detail = StockDetail.fromJson(json as Map<String, dynamic>);
      final uomDto =
          detail.stockUOMDtoList.where((u) => u.uom == uomName).firstOrNull;
      if (uomDto != null) return priceForCategory(uomDto, priceCategory);
    } catch (_) {}
    return null;
  }

  static String formatDP(double v, int dp) {
    if (dp == 0) return v.toInt().toString();
    return v.toStringAsFixed(dp);
  }

  static double toD(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
  }
}