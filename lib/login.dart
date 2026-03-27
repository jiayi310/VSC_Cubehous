import 'dart:math' as math;
import 'package:cubehous/models/my_user.dart';
import 'package:cubehous/models/my_user_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api/base_client.dart';
import 'common/dots_loading.dart';
import 'common/network_aware_wrapper.dart';
import 'common/session_manager.dart';
import 'login_company.dart';
import 'models/my_company_selection.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late final AnimationController _waveController;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _userIsActive = false;
  String email = '';

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      value: 0.0,
      duration: const Duration(seconds: 25),
      upperBound: 1,
      lowerBound: -1,
      vsync: this,
    )..repeat();
    _loadSavedCredentials();
    // Trigger first network check now that login page is visible
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NetworkAwareWrapper.checkNow(),
    );
  }

  Future<void> _loadSavedCredentials() async {
    final rememberMe = await SessionManager.getRememberMe();
    final savedEmail = await SessionManager.getSavedEmail();
    final savedPassword = await SessionManager.getSavedPassword();
    if (rememberMe && savedEmail.isNotEmpty) {
      setState(() {
        _rememberMe = true;
        _emailController.text = savedEmail;
        if (savedPassword.isNotEmpty) _passwordController.text = savedPassword;
      });
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topInset = MediaQuery.of(context).padding.top;
    final headerHeight = size.height * 0.48;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: Stack(
          children: [
            SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                children: [
                  // ── Animated wave header ──────────────────
                  SizedBox(
                    height: headerHeight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Wave animation
                        AnimatedBuilder(
                          animation: _waveController,
                          builder: (_, __) => ClipPath(
                            clipper: _WaveClipper(_waveController.value),
                            child: Container(
                              height: headerHeight,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomLeft,
                                  end: Alignment.topRight,
                                  colors: [
                                    Color(0xFF1E2F4A),
                                    Color(0xFF5B8FD4),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Logo centred over the wave
                        Padding(
                          padding: EdgeInsets.only(top: topInset, bottom: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assests/images/logo.png',
                                height: 150,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 140,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Cubehous',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                   Text(
                    'Sign in to your account',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      letterSpacing: 0.3,
                    ),
                   ),
                  // ── Form ─────────────────────────────────
                  _buildForm(context),
                ],
              ),
            ),
            // Loading overlay
            if (_isLoading)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: DotsLoading(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Password
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          // Remember Me
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                activeColor: Theme.of(context).colorScheme.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (v) => setState(() => _rememberMe = v ?? false),
              ),
              GestureDetector(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: const Text('Remember Me',
                    style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Login button
          FilledButton(
            onPressed: _isLoading ? null : _login,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Login',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 20),
          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade600, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                          color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _login() async {
    email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userID = await BaseClient.get(
        '/User/ValidateUserLogin'
        '?email=${Uri.encodeComponent(email)}'
        '&password=${Uri.encodeComponent(password)}',
      ) as int;

      final raw1 = await BaseClient.get('/User/GetUser?userid=$userID');
      final myUser = MyUser.fromJson(raw1 as Map<String, dynamic>);
      final username = myUser.name ?? '';
      final profileImage = myUser.profileImage ?? '';
      _userIsActive = myUser.isActive ?? false;

      final raw2= await BaseClient.get('/User/GetCompanySelectionList?userid=$userID',) as List<dynamic>;
      final companies = raw2
          .map((e) => CompanySelection.fromJson(e as Map<String, dynamic>))
          .toList();

      if (!mounted) return;

      if (companies.isEmpty) {
        setState(() => _errorMessage = 'No company found for this account');
        return;
      }

      // Save credentials + update remember me on server
      await SessionManager.saveRememberMe(_rememberMe);
      await SessionManager.saveSavedEmail(_rememberMe ? email : '');
      await SessionManager.saveSavedPassword(_rememberMe ? _passwordController.text : '');

      if (_rememberMe) {
        try {
          await BaseClient.get(
            '/User/UpdateMobileRemember'
            '?email=${Uri.encodeComponent(email)}&grant=1',
          );
        } catch (_) {
          // Non-critical — continue
        }
      }

      if (!mounted) return;

      // Use previously selected company if still available (skip selection page)
      final savedUserMappingID = await SessionManager.getUserMappingID();
      if (savedUserMappingID > 0) {
        final savedCompany = companies.cast<CompanySelection?>().firstWhere(
          (c) => c!.userMappingID == savedUserMappingID,
          orElse: () => null,
        );
        if (savedCompany != null && mounted) {
          await _createSession(
            company: savedCompany,
            userID: userID,
            username: username,
            profileImage: profileImage,
          );
          return;
        }
      }

      if (companies.length == 1) {
        await _createSession(
          company: companies.first,
          userID: userID,
          username: username,
          profileImage: profileImage,
        );
      } else {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LoginCompanyPage(
              companies: companies,
              userID: userID,
              username: username,
              profileImage: profileImage,
              userIsActive: _userIsActive,
            ),
          ),
        );
      }
    } on UnauthorizedException {
      setState(() => _errorMessage = 'Invalid email or password');
    } on TimeoutException {
      setState(
          () => _errorMessage = 'Connection timed out. Please try again');
    } catch (_) {
      setState(() => _errorMessage = 'Invalid email or password');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createSession({
    required CompanySelection company,
    required int userID,
    required String username,
    required String profileImage,
  }) async {
    final sessionJson = await BaseClient.get(
      '/User/CreateUserSession?usermappingid=${company.userMappingID}',
    ) as Map<String, dynamic>;

    // Response body (userSession)
    final userSession = MyUserSession.fromJson(sessionJson['userSession'] as Map<String, dynamic>);
    final userAccessRights = List<String>.from(sessionJson['userAccessRights'] ?? []);
    final companyModuleIdList = List<String>.from(sessionJson['companyModuleIdList'] ?? []);
    //final userProfile = sessionJson['userProfile'] != null
    //    ? UserProfile.fromJson(sessionJson['userProfile'] as Map<String, dynamic>)
    //    : null;

    userAccessRights.add('SHOW_COST');

    if (sessionJson.isEmpty) {
      setState(() => _errorMessage = 'You have no access to this company.');
      return;
    }

    await SessionManager.saveSession(
      email: email,
      userID: userID,
      userMappingID: company.userMappingID,
      companyID: company.companyID,
      userSessionID: userSession.userSessionID ?? '',
      companyGUID: userSession.companyGUID ?? '',
      apiKey: userSession.apiKey ?? '',
      userType: userSession.userType ?? '',
      username: username,
      companyName: company.companyName,
      userAccessRight: userAccessRights,
      companyModuleIdList: companyModuleIdList,
      salesDecimalPoint: userSession.salesDecimalPoint ?? 2,
      purchaseDecimalPoint: userSession.purchaseDecimalPoint ?? 2,
      quantityDecimalPoint: userSession.quantityDecimalPoint ?? 0,
      costDecimalPoint: userSession.costDecimalPoint ?? 2,
      isAutoBatchNo: userSession.isAutoBatchNo ?? false,
      batchNoFormat: userSession.batchNoFormat ?? '',
      isEnableTax: userSession.isEnableTax ?? false,
      defaultLocationID: userSession.defaultLocationID ?? 0,
      defaultSalesAgentID: userSession.defaultSalesAgentID ?? 0,
      userIsActive: _userIsActive,
    );

    if (profileImage.isNotEmpty) {
      await SessionManager.saveProfileImage(profileImage);
    }

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }
}

// ─────────────────────────────────────────────
// Wave clipper
// ─────────────────────────────────────────────

class _WaveClipper extends CustomClipper<Path> {
  final double move;
  static const double _slice = math.pi;

  const _WaveClipper(this.move);

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.85);
    final xCenter =
        size.width * 0.5 + (size.width * 0.8 + 1) * math.sin(move * _slice);
    final yCenter = size.height * 0.85 + 60 * math.cos(move * _slice);
    path.quadraticBezierTo(xCenter, yCenter, size.width, size.height * 0.85);
    path.lineTo(size.width, 0);
    return path;
  }

  @override
  bool shouldReclip(_WaveClipper old) => old.move != move;
}
