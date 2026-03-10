import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api/base_client.dart';
import 'common/my_color.dart';
import 'common/network_aware_wrapper.dart';
import 'common/session_manager.dart';
import 'common/theme_notifier.dart';
import 'home.dart';
import 'login.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Cubehous',
        debugShowCheckedModeBanner: false,
        theme: _lightTheme(),
        darkTheme: _darkTheme(),
        themeMode: mode,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginPage(),
          '/home': (context) => const HomePage(),
        },
        builder: (context, child) => NetworkAwareWrapper(child: child!),
      ),
    );
  }

  ThemeData _lightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: Mycolor.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: Mycolor.primary,
      secondary: Mycolor.secondary,
      surface: Mycolor.lightSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
      scaffoldBackgroundColor: Mycolor.lightBackground,
      cardTheme: CardTheme(
        color: Mycolor.lightCardSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Mycolor.lightSurface,
        indicatorColor: Mycolor.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Mycolor.primary,
            );
          }
          return const TextStyle(fontSize: 12, fontWeight: FontWeight.w400);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Mycolor.primary);
          }
          return const IconThemeData(color: Colors.grey);
        }),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: Mycolor.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Mycolor.secondary,
        dividerColor: Colors.transparent,
      ),
    );
  }

  ThemeData _darkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: Mycolor.primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: Mycolor.darkPrimary,
      secondary: Mycolor.secondary,
      surface: Mycolor.darkSurface,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: Mycolor.darkBackground,
      cardTheme: CardTheme(
        color: Mycolor.darkCardSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Mycolor.darkSurface,
        indicatorColor: Mycolor.darkPrimary.withValues(alpha: 0.20),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Mycolor.darkPrimary,
            );
          }
          return const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w400, color: Colors.grey);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: Mycolor.darkPrimary);
          }
          return const IconThemeData(color: Colors.grey);
        }),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: Mycolor.darkTabLabel,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Mycolor.secondary,
        dividerColor: Colors.transparent,
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const _appVersion = '9.0.12.21';
  static const _versionSecretKey = 'FGBpUTp3Msn2w9j';

  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    // ── Step 1: Version check ──────────────────
    final canProceed = await _checkAppVersion();
    if (!canProceed || !mounted) return;

    // ── Step 2: Remember Me auto-login ────────
    final rememberMe = await SessionManager.getRememberMe();
    final email = await SessionManager.getSavedEmail();
    final password = await SessionManager.getSavedPassword();

    if (!mounted) return;

    if (rememberMe && email.isNotEmpty && password.isNotEmpty) {
      await _tryAutoLogin(email, password);
    } else {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  // ── Version check ────────────────────────────

  Future<bool> _checkAppVersion() async {
    try {
      final response = await BaseClient.get(
        '/VersionCheck/GetMobileAppVersionInfo?secretKey=$_versionSecretKey',
      ) as Map<String, dynamic>;

      final serverVersion = (response['versionNo'] as String?) ?? '';
      final isForce = (response['isForce'] as bool?) ?? false;

      if (_isNewerVersion(serverVersion, _appVersion)) {
        if (!mounted) return false;
        if (isForce) {
          await _showForceUpdateDialog(serverVersion);
          return false; // permanently blocked
        } else {
          await _showOptionalUpdateDialog(serverVersion);
          return true; // user dismissed — continue
        }
      }
    } catch (_) {
      // Version check failed — allow app to continue
    }
    return true;
  }

  /// Returns true if [server] is newer than [current].
  bool _isNewerVersion(String server, String current) {
    if (server.isEmpty) return false;
    final s = server.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final c = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < s.length; i++) {
      final sv = i < s.length ? s[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (sv > cv) return true;
      if (sv < cv) return false;
    }
    return false;
  }

  Future<void> _showForceUpdateDialog(String version) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.system_update_rounded, size: 48, color: Colors.orange),
          title: const Text('Update Required', textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
            'Version $version is required to use Cubehous.\nPlease update to continue.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () {
                // TODO: launch app store URL
              },
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOptionalUpdateDialog(String version) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.new_releases_outlined, size: 48, color: Colors.blue),
        title: const Text('Update Available', textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Version $version is available. Update now for the latest features.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: launch app store URL
              Navigator.of(context).pop();
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  // ── Auto-login via ValidateMobileRemember ────

  Future<void> _tryAutoLogin(String email, String password) async {
    try {
      final isValid = await BaseClient.get(
        '/User/ValidateMobileRemember'
        '?email=${Uri.encodeComponent(email)}'
        '&password=${Uri.encodeComponent(password)}',
      ) as bool;

      if (!isValid || !mounted) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final userMappingID = await SessionManager.getUserMappingID();
      if (userMappingID == 0) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final sessionJson = await BaseClient.get(
        '/User/CreateUserSession?usermappingid=$userMappingID',
      ) as Map<String, dynamic>;

      final session = sessionJson['userSession'] as Map<String, dynamic>?;

      if (sessionJson.isEmpty || session == null || session.isEmpty) {
        if (mounted) {
          _showNoAccessSnackbar();
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      // Restore preserved user data + new session tokens
      final userID = await SessionManager.getUserID();
      final username = await SessionManager.getUsername();
      final companyName = await SessionManager.getCompanyName();
      final companyID = await SessionManager.getCompanyID();

      await SessionManager.saveSession(
        userID: userID,
        userMappingID: userMappingID,
        companyID: companyID,
        defaultLocationID: (session['defaultLocationID'] as int?) ?? 0,
        username: username,
        companyName: companyName,
        userSessionID: (session['userSessionID'] as String?) ?? '',
        companyGUID: (session['companyGUID'] as String?) ?? '',
        apiKey: (session['apiKey'] as String?) ?? '',
        isEnableTax: (session['isEnableTax'] as bool?) ?? false,
        isAutoBatchNo: (session['isAutoBatchNo'] as bool?) ?? false,
        batchNoFormat: session['batchNoFormat'] as String?,
        salesDecimalPoint: (session['salesDecimalPoint'] as int?) ?? 2,
        purchaseDecimalPoint: (session['purchaseDecimalPoint'] as int?) ?? 2,
        quantityDecimalPoint: (session['quantityDecimalPoint'] as int?) ?? 2,
        costDecimalPoint: (session['costDecimalPoint'] as int?) ?? 2,
      );

      await Future.wait([
        SessionManager.saveSavedEmail(email),
        SessionManager.saveSavedPassword(password),
        SessionManager.saveRememberMe(true),
      ]);

      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    } catch (_) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _showNoAccessSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have no access to this company.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assests/images/cubehous_logo_with_words.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
