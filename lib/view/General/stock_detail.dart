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
  bool _canShowCost = false;

  List<StockLocationBalance> _locationBalances = [];
  bool _balanceLoading = false;
  bool _balanceLoadedForUOM = false;
  String? _balanceError;
  final Map<int, List<StockSpecificBalance>> _specificByLocation = {};
  final Map<int, bool> _locationExpanded = {};
  final Map<int, bool> _specificLoading = {};
  final Map<int, String> _specificError = {};

  // History tab
  List<StockHistoryItem> _historyItems = [];
  bool _historyLoading = false;
  String? _historyError;
  bool _historySales = true; // true = Sales, false = Purchase
  DateTime _historyFromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _historyToDate = DateTime.now();
  bool _historyLoaded = false;

  int get _tabCount => (_detail?.hasBatch ?? widget.stock.hasBatch) ? 6 : 5;

  // One scroll controller per tab slot (max 5)
  final List<ScrollController> _scrollControllers =
      List.generate(6, (_) => ScrollController());

  void _scrollCurrentTabToTop() {
    final i = _tabController.index;
    if (i < _scrollControllers.length &&
        _scrollControllers[i].hasClients) {
      _scrollControllers[i].animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

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
    final last = _tabController.length - 1;
    final secondLast = last - 1;
    // Balance tab is second-to-last, History is last
    if (_tabController.index == secondLast && !_balanceLoadedForUOM && !_balanceLoading) {
      _loadBalance();
    }
    if (_tabController.index == last && !_historyLoaded && !_historyLoading) {
      _loadHistory();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    for (final sc in _scrollControllers) {
      sc.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    final rights = await SessionManager.getUserAccessRight();
    _canShowCost = rights.contains('SHOW_COST');
    await _loadDetail();
    await _loadBalance();
  }

  Future<void> _loadDetail() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
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
      final newTabCount = detail.hasBatch ? 6 : 5;
      final needsRebuild = _tabController.length != newTabCount;
      setState(() {
        _detail = detail;
        _selectedUOM = detail.baseUOM;
        _loading = false;
        _locationBalances = [];
        _specificByLocation.clear();
        _locationExpanded.clear();
        _specificLoading.clear();
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
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    if (_detail == null) return;
    setState(() {
      _balanceLoading = true;
      _balanceError = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getStockBalance,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'stockID': _detail!.stockID,
          'uom': _selectedUOM,
        },
      );

      List<StockLocationBalance> locations = [];
      if (response is List<dynamic>) {
        locations = response
            .whereType<Map<String, dynamic>>()
            .map(StockLocationBalance.fromJson)
            .toList();
      }

      setState(() {
        _locationBalances = locations;
        _specificByLocation.clear();
        _locationExpanded.clear();
        _specificLoading.clear();
        _specificError.clear();
        _balanceLoading = false;
        _balanceLoadedForUOM = true;
        _balanceError = null;
      });
    } catch (e) {
      setState(() {
        _balanceLoading = false;
        _balanceLoadedForUOM = true;
        _balanceError = e.toString();
      });
    }
  }

  Future<void> _loadSpecificBalance(int locationID, String location) async {
    if (_specificLoading[locationID] == true) return;
    if (_specificByLocation.containsKey(locationID)) return;
    setState(() => _specificLoading[locationID] = true);
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getSpecificStockBalance,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'stockCode': _detail!.stockCode,
          'uom': _selectedUOM,
          'location': location,
        },
      );
      List<StockSpecificBalance> rows = [];
      if (response is List<dynamic>) {
        rows = response
            .whereType<Map<String, dynamic>>()
            .map(StockSpecificBalance.fromJson)
            .toList();
      }
      setState(() {
        _specificByLocation[locationID] = rows;
        _specificLoading[locationID] = false;
      });
    } catch (e) {
      setState(() {
        _specificError[locationID] = e.toString();
        _specificLoading[locationID] = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    if (_detail == null) return;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final endpoint = _historySales
          ? ApiEndpoints.getStockSalesHistory
          : ApiEndpoints.getStockPurchaseHistory;
      final response = await BaseClient.post(
        endpoint,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'isFilterByCreatedDateTime': true,
          'fromDate': _historyFromDate.toIso8601String(),
          'toDate': _historyToDate.toIso8601String(),
          'stockID': _detail!.stockID,
        },
      );
      List<StockHistoryItem> items = [];
      if (response is List<dynamic>) {
        items = response
            .whereType<Map<String, dynamic>>()
            .map(StockHistoryItem.fromJson)
            .toList();
      }
      setState(() {
        _historyItems = items;
        _historyLoading = false;
        _historyLoaded = true;
        _historyError = null;
      });
    } catch (e) {
      setState(() {
        _historyLoading = false;
        _historyLoaded = true;
        _historyError = e.toString();
      });
    }
  }

  void _selectUOM(String uom) {
    if (uom == _selectedUOM) return;
    setState(() {
      _selectedUOM = uom;
      _locationBalances = [];
      _specificByLocation.clear();
      _locationExpanded.clear();
      _specificLoading.clear();
      _balanceLoadedForUOM = false;
      _balanceError = null;
    });
    _loadBalance();
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
                fontSize: 15,
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
            onTap: (index) {
              if (index == _tabController.index) _scrollCurrentTabToTop();
            },
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
              const Tab(
                icon: Icon(Icons.history_outlined, size: 18),
                text: 'History',
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
    int i = 0;
    return [
      _buildInfoTab(detail, _scrollControllers[i++]),
      _buildPricingTab(_scrollControllers[i++]),
      _buildBarcodeTab(_scrollControllers[i++]),
      if (detail.hasBatch) _buildBatchTab(detail, _scrollControllers[i++]),
      _buildBalanceTab(_scrollControllers[i++]),
      _buildHistoryTab(_scrollControllers[i]),
    ];
  }

  // ── Info ────────────────────────────────────────────────────────────

  Widget _buildInfoTab(StockDetail detail, ScrollController sc) {
    return ListView(
      controller: sc,
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
            label: 'Tax Type',
            value: detail.taxCode.isNotEmpty ? '${detail.taxCode} (${_qtyFmt.format(detail.taxRate)}%)' : '—'),
        _SectionHeader(title: 'OTHERS'),
        _DetailRow(
            label: 'Supplier Code',
            value:
                detail.supplierCode.isNotEmpty ? detail.supplierCode : '—'),
      ],
    );
  }

  // ── Pricing ─────────────────────────────────────────────────────────

  Widget _buildPricingTab(ScrollController sc) {
    final uom = _currentUOM;
    if (uom == null) {
      return const _Placeholder(
        icon: Icons.sell_outlined,
        title: 'No Pricing Data',
      );
    }
    return ListView(
      controller: sc,
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
        if (_canShowCost)
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

  Widget _buildBarcodeTab(ScrollController sc) {
    final barcodes = _currentUOM?.stockBarcodeDtoList ?? [];
    if (barcodes.isEmpty) {
      return const _Placeholder(
        icon: Icons.qr_code_outlined,
        title: 'No barcodes found for this UOM.',
      );
    }
    return ListView.separated(
      controller: sc,
      itemCount: barcodes.length + 1,
      separatorBuilder: (_, i) => i == 0
          ? const SizedBox.shrink()
          : const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        if (i == 0) {
          return _DetailRow(
            label: 'No of Barcode',
            value: '${barcodes.length}',
          );
        }
        final b = barcodes[i - 1];
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

  Widget _buildBatchTab(StockDetail detail, ScrollController sc) {
    final batches = detail.stockBatchDtoList;
    if (batches.isEmpty) {
      return const _Placeholder(
        icon: Icons.layers_outlined,
        title: 'No batch records found for this item.',
      );
    }
    return ListView.separated(
      controller: sc,
      itemCount: batches.length + 1,
      separatorBuilder: (_, i) => i == 0
          ? const SizedBox.shrink()
          : const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        if (i == 0) {
          return _DetailRow(
            label: 'No of Batch',
            value: '${batches.length}',
          );
        }
        final b = batches[i - 1];
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

  Widget _buildBalanceTab(ScrollController sc) {
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

    if (_locationBalances.isEmpty) {
      return const _Placeholder(
        icon: Icons.account_balance_wallet_outlined,
        title: 'No stock balance found for this UOM.',
      );
    }

    final cs = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;

    return ListView(
      controller: sc,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        ..._locationBalances.map((loc) {
          final expanded = _locationExpanded[loc.locationID] ?? false;
          final loading = _specificLoading[loc.locationID] ?? false;
          final rows = _specificByLocation[loc.locationID];
          final specificErr = _specificError[loc.locationID];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    final nowExpanded = !(_locationExpanded[loc.locationID] ?? false);
                    setState(() => _locationExpanded[loc.locationID] = nowExpanded);
                    if (nowExpanded && !_specificByLocation.containsKey(loc.locationID)) {
                      _loadSpecificBalance(loc.locationID, loc.location);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.location_on_outlined,
                              color: Colors.orange, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(loc.location.isNotEmpty ? loc.location : '—',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                        Text(_qtyFmt.format(loc.qty),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: cs.primary)),
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(Icons.expand_more,
                              size: 20,
                              color: cs.onSurface.withValues(alpha: 0.4)),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: expanded
                      ? Column(
                          children: [
                            Divider(height: 1, color: cs.outline.withValues(alpha: 0.12)),
                            if (loading)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Center(child: DotsLoading()),
                              )
                            else if (specificErr != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Text('Error: $specificErr',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.error.withValues(alpha: 0.8))),
                              )
                            else if (rows == null || rows.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Text('No storage detail available.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface.withValues(alpha: 0.4))),
                              )
                            else
                              ...rows.map((r) => _buildStorageRow(r, cs)),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStorageRow(StockSpecificBalance r, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: cs.outline.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(Icons.shelves, size: 16, color: cs.onSurface.withValues(alpha: 0.35)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.storageCode.isNotEmpty ? r.storageCode : '—',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                if (_detail?.hasBatch == true)
                  Text('Batch: ${(r.batchNo != null && r.batchNo!.isNotEmpty) ? r.batchNo : ''}',
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurface.withValues(alpha: 0.5))),
              ],
            ),
          ),
          Text(_qtyFmt.format(r.wmsQty),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  // ── History ─────────────────────────────────────────────────────────

  Widget _buildHistoryTab(ScrollController sc) {
    // Auto-trigger load on first render
    if (!_historyLoaded && !_historyLoading && _detail != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_historyLoaded && !_historyLoading) _loadHistory();
      });
    }

    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('dd MMM yyyy');

    return Column(
      children: [
        // ── Filter bar ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sales / Purchase toggle (only if can show cost)
              if (_canShowCost) ...[
                Row(
                  children: [
                    _HistoryTypeChip(
                      label: 'Sales',
                      selected: _historySales,
                      onTap: () {
                        if (_historySales) return;
                        setState(() {
                          _historySales = true;
                          _historyLoaded = false;
                        });
                        _loadHistory();
                      },
                    ),
                    const SizedBox(width: 8),
                    _HistoryTypeChip(
                      label: 'Purchase',
                      selected: !_historySales,
                      onTap: () {
                        if (!_historySales) return;
                        setState(() {
                          _historySales = false;
                          _historyLoaded = false;
                        });
                        _loadHistory();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              // Date range
              Row(
                children: [
                  Expanded(
                    child: _DatePill(
                      label: 'From',
                      date: dateFmt.format(_historyFromDate),
                      primary: cs.primary,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _historyFromDate,
                          firstDate: DateTime(2000),
                          lastDate: _historyToDate,
                        );
                        if (picked != null && picked != _historyFromDate) {
                          setState(() {
                            _historyFromDate = picked;
                            _historyLoaded = false;
                          });
                          _loadHistory();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DatePill(
                      label: 'To',
                      date: dateFmt.format(_historyToDate),
                      primary: cs.primary,
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _historyToDate,
                          firstDate: _historyFromDate,
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && picked != _historyToDate) {
                          setState(() {
                            _historyToDate = picked;
                            _historyLoaded = false;
                          });
                          _loadHistory();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Content ─────────────────────────────────────────────
        Expanded(
          child: _historyLoading
              ? const Center(child: DotsLoading())
              : _historyError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48,
                                color: cs.error.withValues(alpha: 0.6)),
                            const SizedBox(height: 12),
                            Text('Failed to load history',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface.withValues(alpha: 0.6))),
                            const SizedBox(height: 8),
                            Text(_historyError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface.withValues(alpha: 0.4))),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _historyLoaded = false;
                                  _historyError = null;
                                });
                                _loadHistory();
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _historyItems.isEmpty
                      ? _Placeholder(
                          icon: Icons.history_outlined,
                          title: 'No ${_historySales ? 'sales' : 'purchase'} history found.',
                        )
                      : ListView.separated(
                          controller: sc,
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          itemCount: _historyItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) =>
                              _HistoryCard(
                                item: _historyItems[index],
                                priceFmt: _priceFmt,
                                qtyFmt: _qtyFmt,
                              ),
                        ),
        ),
      ],
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

// ─────────────────────────────────────────────────────────────────────
// History type chip (Sales / Purchase toggle)
// ─────────────────────────────────────────────────────────────────────

class _HistoryTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HistoryTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? primary : primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primary : primary.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : primary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Date pill (From / To date picker button)
// ─────────────────────────────────────────────────────────────────────

class _DatePill extends StatelessWidget {
  final String label;
  final String date;
  final VoidCallback onTap;
  final Color primary;

  const _DatePill({
    required this.label,
    required this.date,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                date,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded,
                size: 16, color: primary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// History card (one transaction row)
// ─────────────────────────────────────────────────────────────────────

class _HistoryCard extends StatelessWidget {
  final StockHistoryItem item;
  final NumberFormat priceFmt;
  final NumberFormat qtyFmt;

  const _HistoryCard({
    required this.item,
    required this.priceFmt,
    required this.qtyFmt,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;
    final dateFmt = DateFormat('dd MMM yyyy');
    String formattedDate = item.docDate;
    try {
      formattedDate = dateFmt.format(DateTime.parse(item.docDate));
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.5),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: docNo + total
          Row(
            children: [
              Text(
                item.docNo,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              const Spacer(),
              Text(
                priceFmt.format(item.total),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Row 2: customer/supplier name + date
          Row(
            children: [
              Expanded(
                child: Text(
                  item.customerSupplierName.isNotEmpty
                      ? item.customerSupplierName
                      : item.customerSupplierCode,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 3: qty × price, UOM, discount badge, location
          Row(
            children: [
              Text(
                '${qtyFmt.format(item.qty)} × ${priceFmt.format(item.unitPrice)}',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.uom,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (item.discount > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '-${qtyFmt.format(item.discount)}%',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (item.location != null && item.location!.isNotEmpty) ...[
                const Spacer(),
                Icon(Icons.location_on_outlined,
                    size: 11,
                    color: cs.onSurface.withValues(alpha: 0.35)),
                const SizedBox(width: 2),
                Text(
                  item.location!,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
