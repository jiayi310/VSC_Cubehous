import 'dart:convert';
import 'package:flutter/material.dart';
import 'about_us.dart';
import 'settings.dart';
import 'view/General/stock_item.dart';
import 'package:flutter/services.dart';
import 'common/session_manager.dart';
import 'common/my_color.dart';
import 'common/theme_notifier.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String _username = '';
  String _companyName = '';
  String _profileImage = '';
  bool _userIsActive = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSession();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final username = await SessionManager.getUsername();
    final companyName = await SessionManager.getCompanyName();
    final profileImage = await SessionManager.getProfileImage();
    final userIsActive = await SessionManager.getUserIsActive();
    setState(() {
      _username = username.isNotEmpty ? username : '-';
      _companyName = companyName.isNotEmpty ? companyName : 'N/A';
      _profileImage = profileImage;
      _userIsActive = userIsActive;
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
              tabs: const [
                Tab(text: 'Sales'),
                Tab(text: 'Warehouse'),
                Tab(text: 'General'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SalesTab(columnCount: _columnCount, onModuleTap: _comingSoon),
                  _WarehouseTab(columnCount: _columnCount, onModuleTap: _comingSoon),
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

  void _onModuleTap(String module) {
    if (module == 'Stock Item') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StockItemPage()),
      );
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
// Warehouse Tab
// ─────────────────────────────────────────────

class _WarehouseTab extends StatelessWidget {
  final int Function(double) columnCount;
  final void Function(String) onModuleTap;

  const _WarehouseTab({required this.columnCount, required this.onModuleTap});

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleItem('Purchase Order', 'assests/images/purchaseorder.png',
          () => onModuleTap('Purchase Order')),
      _ModuleItem('Receiving', 'assests/images/receiving.png',
          () => onModuleTap('Receiving')),
      _ModuleItem('Put-Away', 'assests/images/putaway.png',
          () => onModuleTap('Put-Away')),
      _ModuleItem('Picking', 'assests/images/picking.png',
          () => onModuleTap('Picking')),
      _ModuleItem('Packing', 'assests/images/packing.png',
          () => onModuleTap('Packing')),
      _ModuleItem('Stock Transfer', 'assests/images/transfer.png',
          () => onModuleTap('Stock Transfer')),
      _ModuleItem('Stock Take', 'assests/images/stocktake.png',
          () => onModuleTap('Stock Take')),
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
      _ModuleItem('Customers', 'assests/images/customer.png',
          () => onModuleTap('Customers')),
      _ModuleItem('Suppliers', 'assests/images/supplier.png',
          () => onModuleTap('Suppliers')),
      _ModuleItem('Locations', 'assests/images/location.png',
          () => onModuleTap('Locations')),
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

  const _ModuleItem(this.title, this.imagePath, this.onTap);
}
