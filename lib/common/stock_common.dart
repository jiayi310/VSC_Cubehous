import 'package:cubehous/api/api_endpoints.dart';
import 'package:cubehous/api/base_client.dart';
import 'package:cubehous/common/session_manager.dart';
import 'package:cubehous/models/stock_detail.dart';

class StockCommon {

  static double PriceForCategory(StockUOMDto uom, int cat) {
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
    String _apiKey = await SessionManager.getApiKey();
    String _companyGUID = await SessionManager.getCompanyGUID();
    int _userID = await SessionManager.getUserID();
    String _userSessionID = await SessionManager.getUserSessionID();
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getStock,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'stockID': stockID,
        },
      );
      final detail = StockDetail.fromJson(json as Map<String, dynamic>);
      final uomDto =
          detail.stockUOMDtoList.where((u) => u.uom == uomName).firstOrNull;
      if (uomDto != null) return PriceForCategory(uomDto, priceCategory);
    } catch (_) {}
    return null;
  }

  static String FormatDp(double v, int dp) {
    if (dp == 0) return v.toInt().toString();
    return v.toStringAsFixed(dp);
  }
}