import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cubehous/common/session_expired_handler.dart';
import 'package:flutter/material.dart';

class NetworkAwareWrapper extends StatefulWidget {
  final Widget child;
  const NetworkAwareWrapper({super.key, required this.child});

  /// Call this once the login page is visible to trigger the first check.
  static void checkNow() {
    Connectivity().checkConnectivity().then(
      (results) => _NetworkAwareWrapperState._instance?._onChanged(results),
    );
  }

  @override
  State<NetworkAwareWrapper> createState() => _NetworkAwareWrapperState();
}

class _NetworkAwareWrapperState extends State<NetworkAwareWrapper> {
  static _NetworkAwareWrapperState? _instance;

  late final StreamSubscription<List<ConnectivityResult>> _sub;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    _instance = this;
    // Only listen to changes — initial check is triggered by checkNow()
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    _sub.cancel();
    super.dispose();
  }

  void _onChanged(List<ConnectivityResult> results) {
    final offline = results.isEmpty ||
        results.every((r) => r == ConnectivityResult.none);

    if (offline && !_dialogVisible) {
      _showDialog();
    } else if (!offline && _dialogVisible) {
      _dismissDialog();
    }
  }

  void _showDialog() {
    _dialogVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = appNavigatorKey.currentContext;
      if (ctx == null) {
        _dialogVisible = false;
        return;
      }
      showDialog(
        context: ctx,
        barrierDismissible: false,
        builder: (_) => const _NoNetworkDialog(),
      ).then((_) => _dialogVisible = false);
    });
  }

  void _dismissDialog() {
    _dialogVisible = false;
    appNavigatorKey.currentState?.maybePop();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NoNetworkDialog extends StatefulWidget {
  const _NoNetworkDialog();

  @override
  State<_NoNetworkDialog> createState() => _NoNetworkDialogState();
}

class _NoNetworkDialogState extends State<_NoNetworkDialog> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    final results = await Connectivity().checkConnectivity();
    if (!mounted) return;
    final online = results.any((r) => r != ConnectivityResult.none);
    if (online) {
      Navigator.of(context).pop();
    } else {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      icon: const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red),
      title: const Text(
        'No Internet Connection',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'Please connect to a network to continue using Cubehous.',
        textAlign: TextAlign.center,
      ),
      actions: [
        FilledButton.icon(
          onPressed: _checking ? null : _retry,
          icon: _checking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
    );
  }
}
