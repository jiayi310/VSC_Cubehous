import 'package:flutter/material.dart';
import 'common/dots_loading.dart';
import 'common/my_color.dart';
import 'common/session_manager.dart';

// ─────────────────────────────────────────────
// Settings Page (main)
// ─────────────────────────────────────────────

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // App preferences
  String _language = 'en';
  int _itemsPerPage = 20;
  String _displayMode = 'grid';
  bool _loading = true;

  // Account defaults (view-only)
  int _defaultLocationID = 0;
  bool _isEnableTax = false;
  bool _isAutoBatchNo = false;
  String _batchNoFormat = '';
  int _salesDecimalPoint = 2;
  int _purchaseDecimalPoint = 2;
  int _quantityDecimalPoint = 2;
  int _costDecimalPoint = 2;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      SessionManager.getLanguage(),
      SessionManager.getItemsPerPage(),
      SessionManager.getDisplayMode(),
      SessionManager.getDefaultLocationID(),
      SessionManager.getIsEnableTax(),
      SessionManager.getIsAutoBatchNo(),
      SessionManager.getBatchNoFormat(),
      SessionManager.getSalesDecimalPoint(),
      SessionManager.getPurchaseDecimalPoint(),
      SessionManager.getQuantityDecimalPoint(),
      SessionManager.getCostDecimalPoint(),
    ]);
    if (!mounted) return;
    setState(() {
      _language = results[0] as String;
      _itemsPerPage = results[1] as int;
      _displayMode = results[2] as String;
      _defaultLocationID = results[3] as int;
      _isEnableTax = results[4] as bool;
      _isAutoBatchNo = results[5] as bool;
      _batchNoFormat = (results[6] as String?) ?? '';
      _salesDecimalPoint = results[7] as int;
      _purchaseDecimalPoint = results[8] as int;
      _quantityDecimalPoint = results[9] as int;
      _costDecimalPoint = results[10] as int;
      _loading = false;
    });
  }

  String get _languageLabel {
    const map = {'en': 'English', 'ms': 'Bahasa Melayu', 'zh': '中文 (Simplified)'};
    return map[_language] ?? 'English';
  }

  String get _displayModeLabel => _displayMode == 'grid' ? 'Grid View' : 'List View';

  Future<void> _openLanguage() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _SelectionPage<String>(
          title: 'Language',
          icon: Icons.language_outlined,
          current: _language,
          items: const [
            _Item('en', 'English', null),
            _Item('ms', 'Bahasa Melayu', null),
            _Item('zh', '中文 (Simplified)', null),
          ],
        ),
      ),
    );
    if (result != null && result != _language) {
      await SessionManager.saveLanguage(result);
      if (mounted) setState(() => _language = result);
    }
  }

  Future<void> _openItemsPerPage() async {
    final result = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => _SelectionPage<int>(
          title: 'Items Per Page',
          icon: Icons.format_list_numbered_outlined,
          current: _itemsPerPage,
          items: const [
            _Item(10, '10 items', null),
            _Item(20, '20 items', 'Default'),
            _Item(50, '50 items', null),
            _Item(100, '100 items', null),
          ],
        ),
      ),
    );
    if (result != null && result != _itemsPerPage) {
      await SessionManager.saveItemsPerPage(result);
      if (mounted) setState(() => _itemsPerPage = result);
    }
  }

  Future<void> _openDisplayMode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => _SelectionPage<String>(
          title: 'Display Mode',
          icon: Icons.grid_view_outlined,
          current: _displayMode,
          items: const [
            _Item('grid', 'Grid View', 'Default'),
            _Item('list', 'List View', null),
          ],
        ),
      ),
    );
    if (result != null && result != _displayMode) {
      await SessionManager.saveDisplayMode(result);
      if (mounted) setState(() => _displayMode = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: DotsLoading())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // ── General ──────────────────────────
                _SectionLabel(title: 'General'),
                _SettingsTile(
                  icon: Icons.language_outlined,
                  title: 'Language',
                  value: _languageLabel,
                  onTap: _openLanguage,
                ),
                const SizedBox(height: 24),

                // ── Display ──────────────────────────
                _SectionLabel(title: 'Display'),
                _SettingsTile(
                  icon: Icons.format_list_numbered_outlined,
                  title: 'Items Per Page',
                  value: '$_itemsPerPage items',
                  onTap: _openItemsPerPage,
                ),
                const SizedBox(height: 1),
                _SettingsTile(
                  icon: Icons.grid_view_outlined,
                  title: 'Display Mode',
                  value: _displayModeLabel,
                  onTap: _openDisplayMode,
                ),
                const SizedBox(height: 24),

                // ── Account Defaults (read-only) ──────
                _SectionLabel(title: 'Account Defaults'),
                _ReadonlyGroup(items: [
                  _ReadonlyItem(
                    icon: Icons.location_on_outlined,
                    title: 'Default Location ID',
                    value: _defaultLocationID > 0 ? '$_defaultLocationID' : '—',
                  ),
                  _ReadonlyItem(
                    icon: Icons.receipt_long_outlined,
                    title: 'Enable Tax',
                    value: _isEnableTax ? 'Yes' : 'No',
                  ),
                  _ReadonlyItem(
                    icon: Icons.batch_prediction_outlined,
                    title: 'Auto Batch No',
                    value: _isAutoBatchNo ? 'Yes' : 'No',
                  ),
                  _ReadonlyItem(
                    icon: Icons.tag_outlined,
                    title: 'Batch No Format',
                    value: _batchNoFormat.isNotEmpty ? _batchNoFormat : '—',
                  ),
                  _ReadonlyItem(
                    icon: Icons.point_of_sale_outlined,
                    title: 'Sales Decimal Point',
                    value: '$_salesDecimalPoint',
                  ),
                  _ReadonlyItem(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Purchase Decimal Point',
                    value: '$_purchaseDecimalPoint',
                  ),
                  _ReadonlyItem(
                    icon: Icons.inventory_2_outlined,
                    title: 'Quantity Decimal Point',
                    value: '$_quantityDecimalPoint',
                  ),
                  _ReadonlyItem(
                    icon: Icons.attach_money_outlined,
                    title: 'Cost Decimal Point',
                    value: '$_costDecimalPoint',
                  ),
                ]),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Settings tile (navigates to sub-page)
// ─────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.10),
                ),
                child: Icon(icon, size: 18, color: primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Generic selection sub-page
// ─────────────────────────────────────────────

class _Item<T> {
  final T value;
  final String label;
  final String? badge;
  const _Item(this.value, this.label, this.badge);
}

class _SelectionPage<T> extends StatefulWidget {
  final String title;
  final IconData icon;
  final T current;
  final List<_Item<T>> items;

  const _SelectionPage({
    super.key,
    required this.title,
    required this.icon,
    required this.current,
    required this.items,
  });

  @override
  State<_SelectionPage<T>> createState() => _SelectionPageState<T>();
}

class _SelectionPageState<T> extends State<_SelectionPage<T>> {
  late T _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor =
        Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selected),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            elevation: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: [
                  for (int i = 0; i < widget.items.length; i++) ...[
                    _SelectionTile<T>(
                      item: widget.items[i],
                      selected: _selected == widget.items[i].value,
                      primary: primary,
                      onTap: () => setState(() => _selected = widget.items[i].value),
                    ),
                    if (i < widget.items.length - 1)
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Read-only info group + item
// ─────────────────────────────────────────────

class _ReadonlyItem {
  final IconData icon;
  final String title;
  final String value;
  const _ReadonlyItem({required this.icon, required this.title, required this.value});
}

class _ReadonlyGroup extends StatelessWidget {
  final List<_ReadonlyItem> items;
  const _ReadonlyGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    final cardColor =
        Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final primary = Theme.of(context).colorScheme.primary;
    final labelColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primary.withValues(alpha: 0.08),
                      ),
                      child: Icon(items[i].icon, size: 18, color: primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        items[i].title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      items[i].value,
                      style: TextStyle(fontSize: 13, color: labelColor),
                    ),
                  ],
                ),
              ),
              if (i < items.length - 1)
                const Divider(height: 1, indent: 68, endIndent: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _SelectionTile<T> extends StatelessWidget {
  final _Item<T> item;
  final bool selected;
  final Color primary;
  final VoidCallback onTap;

  const _SelectionTile({
    required this.item,
    required this.selected,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? primary : null,
                    ),
                  ),
                  if (item.badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Mycolor.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Mycolor.secondary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        item.badge!,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Mycolor.secondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: primary)
            else
              const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }
}
