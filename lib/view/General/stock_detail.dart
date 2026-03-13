import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../common/session_manager.dart';
import '../../models/stock.dart';
import '../../models/stock_detail.dart';

class StockDetailPage extends StatefulWidget {
  final Stock stock;
  const StockDetailPage({super.key, required this.stock});

  @override
  State<StockDetailPage> createState() => _StockDetailPageState();
}

class _StockDetailPageState extends State<StockDetailPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _priceFmt = NumberFormat('#,##0.00');
  final _qtyFmt = NumberFormat('#,##0.##');

  StockDetail? _detail;
  bool _loading = true;
  String? _error;
  String _selectedUOM = '';

  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  double? _salesQty;
  double? _wmsQty;
  List<StockSpecificBalance> _specificBalances = [];
  bool _balanceLoading = false;
  bool _balanceLoadedForUOM = false;
  String? _balanceError;

  int get _tabCount => (_detail?.hasBatch ?? widget.stock.hasBatch) ? 5 : 4;

  @override
  void initState() {
    super.initState();
    _selectedUOM = widget.stock.baseUOM;
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(_onTabChanged);
    _init();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == _tabController.length - 1 &&
        !_balanceLoadedForUOM &&
        !_balanceLoading) {
      _loadBalance();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    await _loadDetail();
    await _loadBalance();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getStock,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'stockID': widget.stock.stockID,
        },
      );
      final detail = StockDetail.fromJson(json as Map<String, dynamic>);
      final newTabCount = detail.hasBatch ? 5 : 4;
      final needsRebuild = _tabController.length != newTabCount;
      setState(() {
        _detail = detail;
        _selectedUOM = detail.baseUOM;
        _loading = false;
        _salesQty = null;
        _wmsQty = null;
        _specificBalances = [];
        _balanceLoadedForUOM = false;
        _balanceError = null;
      });
      if (needsRebuild) {
        _tabController.removeListener(_onTabChanged);
        _tabController.dispose();
        _tabController = TabController(length: newTabCount, vsync: this);
        _tabController.addListener(_onTabChanged);
        if (mounted) setState(() {});
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadBalance() async {
    if (_detail == null) return;
    setState(() {
      _balanceLoading = true;
      _balanceError = null;
    });
    try {
      final body = {
        'apiKey': _apiKey,
        'companyGUID': _companyGUID,
        'userID': _userID,
        'userSessionID': _userSessionID,
        'stockID': _detail!.stockID,
        'uom': _selectedUOM,
      };

      // GetStockBalance is required — let it throw if it fails
      final balanceResponse = await BaseClient.post(
        ApiEndpoints.getStockBalance,
        body: body,
      );

      // API may return a Map or a single-element List
      Map<String, dynamic>? balanceJson;
      if (balanceResponse is Map<String, dynamic>) {
        balanceJson = balanceResponse;
      } else if (balanceResponse is List<dynamic> &&
          balanceResponse.isNotEmpty &&
          balanceResponse.first is Map<String, dynamic>) {
        balanceJson = balanceResponse.first as Map<String, dynamic>;
      }

      // GetSpecificStockBalance is optional — don't let it block the result
      List<StockSpecificBalance> specifics = [];
      try {
        final specificJson =
            await BaseClient.post(ApiEndpoints.getSpecificStockBalance, body: body);
        if (specificJson is List<dynamic>) {
          specifics = specificJson
              .map((e) =>
                  StockSpecificBalance.fromJson(e as Map<String, dynamic>))
              .toList();
        } else if (specificJson is Map<String, dynamic>) {
          final data = specificJson['data'];
          if (data is List<dynamic>) {
            specifics = data
                .map((e) =>
                    StockSpecificBalance.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (_) {
        // Specific balance breakdown is optional; show main balance anyway
      }

      setState(() {
        _salesQty = _toD(balanceJson?['salesQty']);
        _wmsQty = _toD(balanceJson?['wmsQty']);
        _specificBalances = specifics;
        _balanceLoading = false;
        _balanceLoadedForUOM = true;
        _balanceError = null;
      });
    } catch (e) {
      setState(() {
        _balanceLoading = false;
        _balanceLoadedForUOM = true; // stop auto-retry loop
        _balanceError = e.toString();
      });
    }
  }

  double _toD(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  void _selectUOM(String uom) {
    if (uom == _selectedUOM) return;
    setState(() {
      _selectedUOM = uom;
      _salesQty = null;
      _wmsQty = null;
      _specificBalances = [];
      _balanceLoadedForUOM = false;
      _balanceError = null;
    });
    if (_tabController.index == _tabController.length - 1) {
      _loadBalance();
    }
  }

  StockUOMDto? get _currentUOM {
    final list = _detail?.stockUOMDtoList;
    if (list == null || list.isEmpty) return null;
    try {
      return list.firstWhere((u) => u.uom == _selectedUOM);
    } catch (_) {
      return list.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: DotsLoading())
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    _buildHeader(),
                    const Divider(height: 1),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: _buildTabViews(),
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 52,
                color:
                    Theme.of(context).colorScheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            Text(
              'Failed to load item',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sticky header ────────────────────────────────────────────────────

  Widget _buildHeader() {
    final detail = _detail!;
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    final uoms = detail.stockUOMDtoList.map((u) => u.uom).toList();

    return Container(
      color: cardColor,
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Centered image
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 100,
                height: 100,
                child: _StockImage(base64: detail.image),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Stock code
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              detail.stockCode,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primary,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 3),

          // Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              detail.description,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(height: 8),

          // UOM selector (always shown)
          if (uoms.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildUOMSelector(uoms),
          ] else
            const SizedBox(height: 4),

          // Tab bar
          TabBar(
            controller: _tabController,
            tabs: [
              const Tab(
                icon: Icon(Icons.list_alt_outlined, size: 18),
                text: 'Info',
                iconMargin: EdgeInsets.only(bottom: 2),
              ),
              const Tab(
                icon: Icon(Icons.sell_outlined, size: 18),
                text: 'Pricing',
                iconMargin: EdgeInsets.only(bottom: 2),
              ),
              const Tab(
                icon: Icon(Icons.qr_code_outlined, size: 18),
                text: 'Barcode',
                iconMargin: EdgeInsets.only(bottom: 2),
              ),
              if (detail.hasBatch)
                const Tab(
                  icon: Icon(Icons.layers_outlined, size: 18),
                  text: 'Batch',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              const Tab(
                icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                text: 'Balance',
                iconMargin: EdgeInsets.only(bottom: 2),
              ),
            ],
            labelColor: primary,
            unselectedLabelColor: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.35),
            indicatorColor: primary,
            indicatorWeight: 2.5,
            labelStyle:
                const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            isScrollable: false,
          ),
        ],
      ),
    );
  }

  Widget _buildUOMSelector(List<String> uoms) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: uoms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final uom = uoms[i];
          final isSelected = uom == _selectedUOM;
          return ChoiceChip(
            label: Text(uom),
            selected: isSelected,
            onSelected: (_) => _selectUOM(uom),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }

  List<Widget> _buildTabViews() {
    final detail = _detail!;
    return [
      _buildInfoTab(detail),
      _buildPricingTab(),
      _buildBarcodeTab(),
      if (detail.hasBatch) _buildBatchTab(detail),
      _buildBalanceTab(),
    ];
  }

  // ── Info ────────────────────────────────────────────────────────────

  Widget _buildInfoTab(StockDetail detail) {
    return ListView(
      children: [
        _SectionHeader(title: 'GENERAL'),
        _DetailRow(label: 'Stock Code', value: detail.stockCode),
        _DetailRow(
            label: 'Description',
            value: detail.description.isNotEmpty ? detail.description : '—'),
        _DetailRow(
            label: 'Description 2',
            value: detail.desc2.isNotEmpty ? detail.desc2 : '—'),
        _DetailRow(
            label: 'Base UOM',
            value: detail.baseUOM.isNotEmpty ? detail.baseUOM : '—'),
        _DetailRow(
            label: 'Sales UOM',
            value: detail.salesUOM.isNotEmpty ? detail.salesUOM : '—'),
        _DetailRow(label: 'Has Batch', value: detail.hasBatch ? 'Yes' : 'No'),
        
        _DetailRow(
          label: 'Status',
          valueWidget: Align(
            alignment: Alignment.centerRight,
            child: _StatusBadge(active: detail.isActive),
          ),
        ),
        _SectionHeader(title: 'CLASSIFICATION'),
        _DetailRow(
            label: 'Group',
            value: detail.stockGroup.isNotEmpty ? detail.stockGroup : '—'),
        _DetailRow(
            label: 'Type',
            value: detail.stockType.isNotEmpty ? detail.stockType : '—'),
        _DetailRow(
            label: 'Category',
            value:
                detail.stockCategory.isNotEmpty ? detail.stockCategory : '—'),
        _DetailRow(
            label: 'Tax Code',
            value: detail.taxCode.isNotEmpty ? detail.taxCode : '—'),
        _DetailRow(
            label: 'Tax Rate',
            value: '${_qtyFmt.format(detail.taxRate)}%'),
        _SectionHeader(title: 'OTHERS'),
        _DetailRow(
            label: 'Supplier Code',
            value:
                detail.supplierCode.isNotEmpty ? detail.supplierCode : '—'),
      ],
    );
  }

  // ── Pricing ─────────────────────────────────────────────────────────

  Widget _buildPricingTab() {
    final uom = _currentUOM;
    if (uom == null) {
      return const _Placeholder(
        icon: Icons.sell_outlined,
        title: 'No Pricing Data',
      );
    }
    return ListView(
      children: [
        _SectionHeader(title: 'PRICE'),
        _PriceRow(label: 'Price 1', value: _priceFmt.format(uom.price1)),
        _PriceRow(label: 'Price 2', value: _priceFmt.format(uom.price2)),
        _PriceRow(label: 'Price 3', value: _priceFmt.format(uom.price3)),
        _PriceRow(label: 'Price 4', value: _priceFmt.format(uom.price4)),
        _PriceRow(label: 'Price 5', value: _priceFmt.format(uom.price5)),
        _PriceRow(label: 'Price 6', value: _priceFmt.format(uom.price6)),
        _PriceRow(label: 'Min Sale Price', value: _priceFmt.format(uom.minSalePrice)),
        _PriceRow(label: 'Max Sale Price', value: _priceFmt.format(uom.maxSalePrice)),
        _PriceRow(label: 'Cost', value: _priceFmt.format(uom.cost)),
        _SectionHeader(title: 'OTHERS'),
        _PriceRow(label: 'Rate', value: _qtyFmt.format(uom.rate)),
        _PriceRow(label: 'Shelf', value: _qtyFmt.format(uom.shelf)),
        _PriceRow(label: 'Reorder Level', value: _qtyFmt.format(uom.reorderLevel)),
        _PriceRow(label: 'Reorder Qty', value: _qtyFmt.format(uom.reorderQty)),
      ],
    );
  }

  // ── Barcode ──────────────────────────────────────────────────────────

  Widget _buildBarcodeTab() {
    final barcodes = _currentUOM?.stockBarcodeDtoList ?? [];
    if (barcodes.isEmpty) {
      return const _Placeholder(
        icon: Icons.qr_code_outlined,
        title: 'No barcodes found for this UOM.',
      );
    }
    return ListView.separated(
      itemCount: barcodes.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final b = barcodes[i];
        return ListTile(
          leading: const Icon(Icons.qr_code_2_outlined),
          title: Text(b.barcode,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: b.description.isNotEmpty ? Text(b.description) : null,
        );
      },
    );
  }

  // ── Batch ────────────────────────────────────────────────────────────

  Widget _buildBatchTab(StockDetail detail) {
    final batches = detail.stockBatchDtoList;
    if (batches.isEmpty) {
      return const _Placeholder(
        icon: Icons.layers_outlined,
        title: 'No batch records found for this item.',
      );
    }
    return ListView.separated(
      itemCount: batches.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final b = batches[i];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                b.batchNo.isNotEmpty ? b.batchNo : '—',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _DateChip(
                    icon: Icons.factory_outlined,
                    label: 'Mfg',
                    date: b.manufacturedDateOnly.isNotEmpty
                        ? b.manufacturedDateOnly
                        : '—',
                  ),
                  const SizedBox(width: 16),
                  _DateChip(
                    icon: Icons.event_busy_outlined,
                    label: 'Exp',
                    date: b.expiryDateOnly.isNotEmpty
                        ? b.expiryDateOnly
                        : '—',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Balance ──────────────────────────────────────────────────────────

  Widget _buildBalanceTab() {
    // Auto-trigger load when this tab is first rendered
    if (!_balanceLoadedForUOM && !_balanceLoading && _detail != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_balanceLoadedForUOM && !_balanceLoading) {
          _loadBalance();
        }
      });
    }

    if (_balanceLoading) {
      return const Center(child: DotsLoading());
    }

    if (_balanceError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 52,
                  color: Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.6)),
              const SizedBox(height: 14),
              Text(
                'Failed to load balance',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _balanceError ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _balanceLoadedForUOM = false;
                    _balanceError = null;
                  });
                  _loadBalance();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_balanceLoadedForUOM) {
      return const _Placeholder(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Loading Balance...',
      );
    }

    final hasNoData =
        (_salesQty ?? 0) == 0 && (_wmsQty ?? 0) == 0 && _specificBalances.isEmpty;
    if (hasNoData) {
      return const _Placeholder(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No stock balance found for this UOM.',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sales summary card
        _BalanceCard(
          icon: Icons.shopping_cart_outlined,
          iconColor: Colors.blue,
          title: 'Sales Qty',
          subtitle: 'Quantity from sales orders',
          value: _qtyFmt.format(_salesQty ?? 0),
          uom: _selectedUOM,
        ),
        const SizedBox(height: 12),
        // WMS summary card
        _BalanceCard(
          icon: Icons.warehouse_outlined,
          iconColor: Colors.orange,
          title: 'WMS Qty',
          subtitle: 'Total quantity in warehouse',
          value: _qtyFmt.format(_wmsQty ?? 0),
          uom: _selectedUOM,
        ),

        // WMS breakdown
        if (_specificBalances.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'WMS STORAGE BREAKDOWN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ..._specificBalances.map((b) => _StorageBalanceRow(
                item: b,
                qtyFmt: _qtyFmt,
                uom: _selectedUOM,
              )),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Balance card
// ─────────────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String value;
  final String uom;

  const _BalanceCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.uom,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w700)),
              Text(
                uom,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Storage balance row (WMS breakdown)
// ─────────────────────────────────────────────────────────────────────

class _StorageBalanceRow extends StatelessWidget {
  final StockSpecificBalance item;
  final NumberFormat qtyFmt;
  final String uom;

  const _StorageBalanceRow({
    required this.item,
    required this.qtyFmt,
    required this.uom,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ??
        Theme.of(context).colorScheme.surface;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.storageName.isNotEmpty
                      ? item.storageName
                      : item.storageCode,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
                if (item.batchNo.isNotEmpty)
                  Text(
                    'Batch: ${item.batchNo}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                qtyFmt.format(item.qty),
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                uom,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Detail row (label + value, right-aligned)
// ─────────────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;

  const _DetailRow({required this.label, this.value, this.valueWidget});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: valueWidget ??
                Text(
                  value ?? '—',
                  style:
                      const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.right,
                ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Price row (label + value, with slightly larger value)
// ─────────────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;

  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tag badge (e.g. "Has Batch")
// ─────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool active;
  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────
// Batch date chip
// ─────────────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String date;
  const _DateChip(
      {required this.icon, required this.label, required this.date});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 13,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.4)),
        const SizedBox(width: 4),
        Text(
          '$label: $date',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Empty / placeholder state
// ─────────────────────────────────────────────────────────────────────

class _Placeholder extends StatelessWidget {
  final IconData icon;
  final String title;

  const _Placeholder({
    required this.icon,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 52,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.18)),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Stock image (base64 → Image.memory, fallback to icon)
// ─────────────────────────────────────────────────────────────────────

class _StockImage extends StatelessWidget {
  final String? base64;
  const _StockImage({this.base64});

  @override
  Widget build(BuildContext context) {
    if (base64 != null && base64!.isNotEmpty) {
      try {
        final raw = base64!.contains(',') ? base64!.split(',').last : base64!;
        final bytes = base64Decode(raw);
        return Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true);
      } catch (_) {}
    }
    return Container(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 36,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
