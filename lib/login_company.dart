import 'package:cubehous/models/my_user_session.dart';
import 'package:flutter/material.dart';
import 'api/base_client.dart';
import 'common/dots_loading.dart';
import 'common/session_manager.dart';
import 'models/my_company_selection.dart';

class LoginCompanyPage extends StatefulWidget {
  final List<CompanySelection> companies;
  final int userID;
  final String username;
  final String profileImage;
  final bool userIsActive;

  const LoginCompanyPage({
    super.key,
    required this.companies,
    required this.userID,
    required this.username,
    required this.profileImage,
    required this.userIsActive
  });

  @override
  State<LoginCompanyPage> createState() => _LoginCompanyPageState();
}

class _LoginCompanyPageState extends State<LoginCompanyPage> {
  CompanySelection? _selected;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Company'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'You are associated with ${widget.companies.length} companies.\nPlease select one to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: widget.companies.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final company = widget.companies[i];
                    final isSelected =
                        _selected?.userMappingID == company.userMappingID;
                    return _CompanyTile(
                      company: company,
                      isSelected: isSelected,
                      onTap: () => setState(() => _selected = company),
                    );
                  },
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade600, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 16),
                child: FilledButton(
                  onPressed: _selected == null || _isLoading ? null : _confirm,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: DotsLoading(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    final company = _selected!;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sessionJson = await BaseClient.get(
        '/User/CreateUserSession?usermappingid=${company.userMappingID}',
      ) as Map<String, dynamic>;

      // Response body (userSession)
      final userSession = MyUserSession.fromJson(sessionJson['userSession'] as Map<String, dynamic>);
      final userAccessRights = List<String>.from(sessionJson['userAccessRights'] ?? []);
      final companyModuleIdList = List<String>.from(sessionJson['companyModuleIdList'] ?? []);
      // final userProfile = sessionJson['userProfile'] != null
      //   ? UserProfile.fromJson(sessionJson['userProfile'] as Map<String, dynamic>)
      //   : null;

      if (sessionJson.isEmpty) {
        setState(() => _errorMessage = 'You have no access to this company.');
        return;
      }

      await SessionManager.saveSession(
        email: userSession.email ?? '',
        userID: widget.userID,
        userMappingID: company.userMappingID,
        companyID: company.companyID,
        userSessionID: userSession.userSessionID ?? '',
        companyGUID: userSession.companyGUID ?? '',
        apiKey: userSession.apiKey ?? '',
        userType: userSession.userType ?? '',
        username: widget.username,
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
        userIsActive: widget.userIsActive,
      );

      if (widget.profileImage.isNotEmpty) {
        await SessionManager.saveProfileImage(widget.profileImage);
      }

      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      }
    } on TimeoutException {
      setState(
          () => _errorMessage = 'Connection timed out. Please try again');
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ─────────────────────────────────────────────
// Company tile widget
// ─────────────────────────────────────────────

class _CompanyTile extends StatelessWidget {
  final CompanySelection company;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompanyTile({
    required this.company,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? primary : Colors.transparent,
          width: 2,
        ),
        color: isSelected ? primary.withValues(alpha: 0.08) : cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Text(
                  company.companyName.isNotEmpty
                      ? company.companyName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      company.companyName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? primary : null,
                      ),
                    ),
                    if (company.userType.isNotEmpty)
                      Text(
                        company.userType,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: primary, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
