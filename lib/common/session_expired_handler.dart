import 'package:flutter/material.dart';
import 'package:cubehous/api/api_endpoints.dart';
import 'package:cubehous/api/base_client.dart';
import 'package:cubehous/common/session_manager.dart';
import 'package:cubehous/models/my_user_session.dart';

/// Global navigator key — set on [MaterialApp.navigatorKey] in main.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class SessionExpiredHandler {
  static bool _isShowing = false;

  /// Call this whenever an [UnauthorizedException] is caught.
  /// Shows a one-at-a-time dialog letting the user renew their session.
  static void handleSessionExpired() {
    if (_isShowing) return;
    final context = appNavigatorKey.currentContext;
    if (context == null) return;

    _isShowing = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SessionExpiredDialog(),
    ).then((_) => _isShowing = false);
  }
}

class _SessionExpiredDialog extends StatefulWidget {
  const _SessionExpiredDialog();

  @override
  State<_SessionExpiredDialog> createState() => _SessionExpiredDialogState();
}

class _SessionExpiredDialogState extends State<_SessionExpiredDialog> {
  bool _isLoading = false;
  String? _errorMsg;

  Future<void> _reLogin() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final userMappingID = await SessionManager.getUserMappingID();
      final sessionJson = await BaseClient.get(
        ApiEndpoints.createUserSessionQ(userMappingID),
      ) as Map<String, dynamic>;

      final userSession = MyUserSession.fromJson(
        sessionJson['userSession'] as Map<String, dynamic>,
      );
      final userAccessRights =
          List<String>.from(sessionJson['userAccessRights'] ?? []);
      final companyModuleIdList =
          List<String>.from(sessionJson['companyModuleIdList'] ?? []);

      await SessionManager.renewSession(
        userSessionID: userSession.userSessionID ?? '',
        companyGUID: userSession.companyGUID ?? '',
        apiKey: userSession.apiKey ?? '',
        userType: userSession.userType ?? '',
        userAccessRight: userAccessRights,
        companyModuleIdList: companyModuleIdList,
        salesDecimalPoint: userSession.salesDecimalPoint ?? 2,
        purchaseDecimalPoint: userSession.purchaseDecimalPoint ?? 2,
        quantityDecimalPoint: userSession.quantityDecimalPoint ?? 0,
        costDecimalPoint: userSession.costDecimalPoint ?? 2,
        isAutoBatchNo: userSession.isAutoBatchNo ?? false,
        batchNoFormat: userSession.batchNoFormat,
        isEnableTax: userSession.isEnableTax ?? false,
        defaultLocationID: userSession.defaultLocationID,
        defaultSalesAgentID: userSession.defaultSalesAgentID,
      );

      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Failed to renew session. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(
        Icons.lock_clock_outlined,
        size: 48,
        color: Colors.orange,
      ),
      title: const Text(
        'Session Expired',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: Text(
        _errorMsg ??
            'Your session has expired.\nPlease re-login to continue.',
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton(
          onPressed: _isLoading ? null : _reLogin,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Re-login'),
        ),
      ],
    );
  }
}
