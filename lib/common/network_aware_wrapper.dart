import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class NetworkAwareWrapper extends StatefulWidget {
  final Widget child;
  const NetworkAwareWrapper({super.key, required this.child});

  @override
  State<NetworkAwareWrapper> createState() => _NetworkAwareWrapperState();
}

class _NetworkAwareWrapperState extends State<NetworkAwareWrapper> {
  late final StreamSubscription<List<ConnectivityResult>> _sub;
  bool _dialogVisible = false;

  @override
  void initState() {
    super.initState();
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
    // Check immediately on startup
    Connectivity().checkConnectivity().then(
      (results) => _onChanged(results),
    );
  }

  @override
  void dispose() {
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
    // Wait for a valid context/navigator before showing
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _NoNetworkDialog(),
      ).then((_) => _dialogVisible = false);
    });
  }

  void _dismissDialog() {
    _dialogVisible = false;
    if (mounted) Navigator.of(context, rootNavigator: true).maybePop();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NoNetworkDialog extends StatelessWidget {
  const _NoNetworkDialog();

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
    );
  }
}
