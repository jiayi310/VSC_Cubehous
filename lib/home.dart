import 'dart:convert';
import 'package:cubehous/view/General/Customer/customer_list.dart';
import 'package:cubehous/view/Analysis/analysis_page.dart';
import 'package:cubehous/view/Report/report_page.dart';
import 'package:cubehous/view/General/Location/location_list.dart';
import 'package:cubehous/view/General/Supplier/supplier_list.dart';
import 'package:cubehous/view/Sales/Collection/collection_list.dart';
import 'package:cubehous/view/Purchase/purchase_list.dart';
import 'package:cubehous/view/Warehouse/Packing/packing_list.dart';
import 'package:cubehous/view/Warehouse/Receiving/receiving_list.dart';
import 'package:cubehous/view/Warehouse/PutAway/put_away_list.dart';
import 'package:cubehous/view/Warehouse/StockAdjustment/stock_adjustment_list.dart';
import 'package:cubehous/view/Warehouse/StockTake/stock_take_list.dart';
import 'package:cubehous/view/Sales/Quotation/quotation_list.dart';
import 'package:cubehous/view/Sales/Sales/sales_list.dart';
import 'package:flutter/material.dart';
import 'about_us.dart';
import 'settings.dart';
import 'view/General/Stock/stock_item.dart';
import 'package:flutter/services.dart';
import 'common/session_manager.dart';
import 'common/my_color.dart';
import 'common/theme_notifier.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;

  String _username = '';
  String _companyName = '';
  String _profileImage = '';
  bool _userIsActive = true;
  bool _hasSales = true;
  bool _hasWms = true;
  List<String> _accessRights = [];

  @override
  void initState() {
    super.initState();
    // length 4 = Sales + Inbound + Outbound + General (defaults: both modules on)
    _tabController = TabController(length: 4, vsync: this);
    _loadSession();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final results = await Future.wait([
      SessionManager.getUsername(),
      SessionManager.getCompanyName(),
      SessionManager.getProfileImage(),
      SessionManager.getUserIsActive(),
      SessionManager.getCompanyModuleIdList(),
      SessionManager.getUserAccessRight(),
    ]);
    if (!mounted) return;
    final username = results[0] as String;
    final companyName = results[1] as String;
    final profileImage = results[2] as String;
    final userIsActive = results[3] as bool;
    final modules = results[4] as List<String>;
    final accessRights = results[5] as List<String>;

    final hasSales = modules.contains('SALES');
    final hasWms = modules.contains('WMS');
    final tabCount = 1 + (hasSales ? 1 : 0) + (hasWms ? 2 : 0);

    // Swap controller only when the tab count genuinely changes.
    if (_tabController.length != tabCount) {
      final old = _tabController;
      _tabController = TabController(length: tabCount, vsync: this);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }

    setState(() {
      _username = username.isNotEmpty ? username : '-';
      _companyName = companyName.isNotEmpty ? companyName : 'N/A';
      _profileImage = profileImage;
      _userIsActive = userIsActive;
      _hasSales = hasSales;
      _hasWms = hasWms;
      _accessRights = accessRights;
    });
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  int _columnCount(double width) {
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: SafeArea(
          top: false,
          bottom: false,
          child: Column(
            children: [
              _GreetingBanner(
                greeting: _greeting,
                username: _username,
                companyName: _companyName,
                profileImage: _profileImage,
                onTap: _showProfileSheet,
              ),
              TabBar(
                controller: _tabController,
                tabs: [
                  if (_hasSales) const Tab(icon: Icon(Icons.attach_money_rounded, size: 23)),
                  if (_hasWms) const Tab(icon: Icon(Icons.move_to_inbox_rounded, size: 23)),
                  if (_hasWms) const Tab(icon: Icon(Icons.outbox_rounded, size: 23)),
                  const Tab(icon: Icon(Icons.apps_rounded, size: 23)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    if (_hasSales) _SalesTab(columnCount: _columnCount, onModuleTap: _onModuleTap),
                    if (_hasWms) _InboundTab(columnCount: _columnCount, onModuleTap: _onModuleTap),
                    if (_hasWms) _OutboundTab(columnCount: _columnCount, onModuleTap: _onModuleTap),
                    _GeneralTab(columnCount: _columnCount, onModuleTap: _onModuleTap),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProfileSheet(
        username: _username,
        companyName: _companyName,
        profileImage: _profileImage,
        userIsActive: _userIsActive,
        onLogout: _logout,
        onSettingTap: _onSettingTap,
      ),
    );
  }

  void _onSettingTap(String setting) {
    if (setting == 'Theme') {
      _showThemePicker();
    } else if (setting == 'About') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AboutUsPage()),
      );
    } else if (setting == 'Settings') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
    } else {
      _comingSoon(setting);
    }
  }

  void _showThemePicker() {
    final options = [
      (label: 'Light', mode: ThemeMode.light, icon: Icons.light_mode_outlined),
      (label: 'Dark', mode: ThemeMode.dark, icon: Icons.dark_mode_outlined),
    ];

    showDialog(
      context: context,
      builder: (ctx) => ValueListenableBuilder<ThemeMode>(
        valueListenable: themeNotifier,
        builder: (_, current, __) => SimpleDialog(
          title: const Text('Choose Theme'),
          children: options.map((opt) {
            final selected = current == opt.mode;
            return SimpleDialogOption(
              onPressed: () {
                saveThemePreference(opt.mode);
                Navigator.pop(ctx);
              },
              child: Row(
                children: [
                  Icon(opt.icon,
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : null),
                  const SizedBox(width: 12),
                  Text(
                    opt.label,
                    style: selected
                        ? TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                  const Spacer(),
                  if (selected) Icon(Icons.check, color: Theme.of(context).colorScheme.primary, size: 18),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _hasAccess(String right) => _accessRights.contains(right);

  void _showNoAccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text('You do not have the access right to perform this action.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onModuleTap(String module) {
    if (module == 'Stock Item') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StockItemPage()),
      );
    } else if (module == 'Customers') {
      // Navigator.of(context).push(
      //   MaterialPageRoute(builder: (_) => const CustomerListPage()),
      // );
    } else if (module == 'Suppliers') {
      // Navigator.of(context).push(
      //   MaterialPageRoute(builder: (_) => const SupplierListPage()),
      // );
    } else if (module == 'Locations') {
      // Navigator.of(context).push(
      //   MaterialPageRoute(builder: (_) => const LocationListPage()),
      // );
    } else if (module == 'Quotation') {
      if (!_hasAccess('QUOTATION_VIEW')) { _showNoAccessDialog(); return; }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const QuotationListPage()),
      );
    } else if (module == 'Sales Order') {
      if (!_hasAccess('SALES_VIEW')) { _showNoAccessDialog(); return; }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SalesListPage()),
      );
    } else if (module == 'Collection') {
      if (!_hasAccess('COLLECT_VIEW')) { _showNoAccessDialog(); return; }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CollectionListPage()),
      );
    } else if (module == 'Purchase Order') {
      // if (!_hasAccess('PURCHASE_VIEW')) { _showNoAccessDialog(); return; }
      // Navigator.of(context).push(
      //   MaterialPageRoute(builder: (_) => const PurchaseListPage()),
      // );
    } else if (module == 'Receiving') {
      if (!_hasAccess('RECEIVING_VIEW')) { _showNoAccessDialog(); return; }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ReceivingListPage()),
      );
    } else if (module == 'Put Away') {
      if (!_hasAccess('PUTAWAY_VIEW')) { _showNoAccessDialog(); return; }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PutAwayListPage()),
      );
    } else if (module == 'Packing') {
      if (!_hasAccess('PACKING_VIEW')) { _showNoAccessDialog(); return; }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PackingListPage()),
      );
    } else if (module == 'Stock Take') {
      if (!_hasAccess('STOCKTAKE_VIEW')) { _showNoAccessDialog(); return; }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StockTakeListPage()),
      );
    } else if (module == 'Stock Transfer') {
      // if (!_hasAccess('STOCKTRANSFER_VIEW')) { _showNoAccessDialog(); return; }
      // Navigator.of(context).push(
      //   MaterialPageRoute(builder: (_) => const StockTransferListPage()),
      // );
    } else if (module == 'Stock Adjustment'){
      if (!_hasAccess('STOCKADJUSTMENT_VIEW')) { _showNoAccessDialog(); return; }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StockAdjustmentListPage()),
      );
    } else if (module == 'Analysis') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AnalysisPage()),
      );
    } else if (module == 'Reports') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ReportPage()),
      );
    } else if (
        module == 'Picking') {
      _comingSoon(module);
    } else {
      _comingSoon(module);
    }
  }

  void _comingSoon(String module) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$module — coming soon'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _logout() async {
    await SessionManager.clearSession();
    if (mounted) Navigator.of(context).pushReplacementNamed('/login');
  }
}

// ─────────────────────────────────────────────
// Sales Tab
// ─────────────────────────────────────────────

class _SalesTab extends StatelessWidget {
  final int Function(double) columnCount;
  final void Function(String) onModuleTap;

  const _SalesTab({required this.columnCount, required this.onModuleTap});

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleItem('Quotation', 'assests/images/quotation.png',
          () => onModuleTap('Quotation')),
      _ModuleItem('Sales Order', 'assests/images/sales.png',
          () => onModuleTap('Sales Order')),
      _ModuleItem('Collection', 'assests/images/collection.png',
          () => onModuleTap('Collection')),
    ];
    return _ModuleGrid(items: modules, columnCount: columnCount);
  }
}

// ─────────────────────────────────────────────
// Inbound Tab
// ─────────────────────────────────────────────

class _InboundTab extends StatelessWidget {
  final int Function(double) columnCount;
  final void Function(String) onModuleTap;

  const _InboundTab({required this.columnCount, required this.onModuleTap});

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleItem('Receiving', 'assests/images/receiving.png',
          () => onModuleTap('Receiving')),
      _ModuleItem('Put Away', 'assests/images/putaway.png',
          () => onModuleTap('Put Away')),
    ];
    return _ModuleGrid(items: modules, columnCount: columnCount);
  }
}

// ─────────────────────────────────────────────
// Outbound Tab
// ─────────────────────────────────────────────

class _OutboundTab extends StatelessWidget {
  final int Function(double) columnCount;
  final void Function(String) onModuleTap;

  const _OutboundTab({required this.columnCount, required this.onModuleTap});

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleItem('Picking', 'assests/images/picking.png',
          () => onModuleTap('Picking')),
      _ModuleItem('Packing', 'assests/images/packing.png',
          () => onModuleTap('Packing')),
    ];
    return _ModuleGrid(items: modules, columnCount: columnCount);
  }
}

// ─────────────────────────────────────────────
// General Tab
// ─────────────────────────────────────────────

class _GeneralTab extends StatelessWidget {
  final int Function(double) columnCount;
  final void Function(String) onModuleTap;

  const _GeneralTab({required this.columnCount, required this.onModuleTap});

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleItem('Stock Item', 'assests/images/stockitem.png',
          () => onModuleTap('Stock Item')),
      _ModuleItem('Stock Take', 'assests/images/stocktake.png',
          () => onModuleTap('Stock Take')),
      _ModuleItem('Stock Adjustment', 'assests/images/adjustment.png',
          () => onModuleTap('Stock Adjustment'),
          iconData: Icons.tune_outlined,
          iconColor: const Color(0xFF2E7D32)),
      _ModuleItem('Stock Transfer', 'assests/images/transfer.png',
          () => onModuleTap('Stock Transfer')),
      _ModuleItem('Analysis', 'assests/images/analysis.png',
          () => onModuleTap('Analysis'),
          iconData: Icons.analytics_outlined,
          iconColor: const Color(0xFF1565C0)),
      _ModuleItem('Reports', 'assests/images/report.png',
          () => onModuleTap('Reports'),
          iconData: Icons.bar_chart_rounded,
          iconColor: const Color(0xFF6A1B9A)),
    ];
    return _ModuleGrid(items: modules, columnCount: columnCount);
  }
}

// ─────────────────────────────────────────────
// Greeting Banner
// ─────────────────────────────────────────────

class _GreetingBanner extends StatelessWidget {
  final String greeting;
  final String username;
  final String companyName;
  final String profileImage;
  final VoidCallback onTap;

  const _GreetingBanner({
    required this.greeting,
    required this.username,
    required this.companyName,
    required this.profileImage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(16, topInset + 16, 16, 20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Mycolor.primary, Color(0xFF1E6EC8)],
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    companyName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    username.isNotEmpty ? '$greeting, $username!' : '$greeting!',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final img = _decodeProfileImage(profileImage);
    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color.fromARGB(255, 170, 170, 170),
      child: ClipOval(
        child: img ?? _gradientAvatar(),
      ),
    );
  }

  /// Decodes profileImage — supports base64 string or http URL.
  /// Returns null if the image cannot be decoded.
  Widget? _decodeProfileImage(String src, {double size = 52}) {
    if (src.isEmpty) return null;
    final fallback = SizedBox(width: size, height: size);
    if (src.startsWith('http')) {
      return Image.network(src, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback);
    }
    try {
      final raw = src.contains(',') ? src.split(',').last : src;
      final bytes = base64Decode(raw);
      return Image.memory(bytes, width: size, height: size, fit: BoxFit.cover,
          gaplessPlayback: true, errorBuilder: (_, __, ___) => fallback);
    } catch (_) {
      return null;
    }
  }

  Widget _gradientAvatar() {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF64B5F6), Color(0xFF1565C0)],
        ),
      ),
      child: const Icon(Icons.person, color: Color.fromARGB(255, 170, 170, 170), size: 30),
    );
  }
}

// ─────────────────────────────────────────────
// Profile Bottom Sheet
// ─────────────────────────────────────────────

class _ProfileSheet extends StatelessWidget {
  final String username;
  final String companyName;
  final String profileImage;
  final bool userIsActive;
  final VoidCallback onLogout;
  final void Function(String) onSettingTap;

  const _ProfileSheet({
    required this.username,
    required this.companyName,
    required this.profileImage,
    required this.userIsActive,
    required this.onLogout,
    required this.onSettingTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color.fromARGB(255, 170, 170, 170),
            child: ClipOval(
              child: _buildSheetAvatar(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            username.isNotEmpty ? username : '—',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            companyName.isNotEmpty ? companyName : '—',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            userIsActive ? 'Active' : 'Inactive',
            style: TextStyle(fontSize: 13, color: userIsActive ? const Color.fromARGB(255, 45, 207, 0) : const Color.fromARGB(255, 191, 0, 0)),
          ),
          const SizedBox(height: 16),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dark_mode_outlined),
            title: const Text('Theme'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () { Navigator.pop(context); onSettingTap('Theme'); },
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Settings'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () { Navigator.pop(context); onSettingTap('Settings'); },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () { Navigator.pop(context); onSettingTap('About'); },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              onLogout();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSheetAvatar() {
    if (profileImage.isNotEmpty) {
      try {
        final raw = profileImage.contains(',')
            ? profileImage.split(',').last
            : profileImage;
        final bytes = base64Decode(raw);
        return Image.memory(bytes, width: 72, height: 72, fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _sheetAvatarFallback());
      } catch (_) {}
      if (profileImage.startsWith('http')) {
        return Image.network(profileImage, width: 72, height: 72, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _sheetAvatarFallback());
      }
    }
    return _sheetAvatarFallback();
  }

  Widget _sheetAvatarFallback() {
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';
    return Container(
      width: 72,
      height: 72,
      color: Mycolor.primary,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Module Grid & Card
// ─────────────────────────────────────────────

class _ModuleGrid extends StatelessWidget {
  final List<_ModuleItem> items;
  final int Function(double) columnCount;

  const _ModuleGrid({required this.items, required this.columnCount});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnCount(constraints.maxWidth);
        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: items.length,
          itemBuilder: (_, index) => _ModuleCard(item: items[index]),
        );
      },
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final _ModuleItem item;

  const _ModuleCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item.onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.iconData != null)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: (item.iconColor ?? Theme.of(context).colorScheme.primary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(item.iconData!,
                    size: 34,
                    color: item.iconColor ??
                        Theme.of(context).colorScheme.primary),
              )
            else
              Image.asset(
                item.imagePath,
                width: 64,
                height: 64,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.image_not_supported_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Module Item Data
// ─────────────────────────────────────────────

class _ModuleItem {
  final String title;
  final String imagePath;
  final VoidCallback onTap;
  final IconData? iconData;
  final Color? iconColor;

  const _ModuleItem(this.title, this.imagePath, this.onTap,
      {this.iconData, this.iconColor});
}
