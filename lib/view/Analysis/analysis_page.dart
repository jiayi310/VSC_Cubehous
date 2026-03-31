import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../common/session_manager.dart';

// ─────────────────────────────────────────────
// Period Enum
// ─────────────────────────────────────────────

enum _Period {
  today(1, 'Today'),
  weekly(2, 'Weekly'),
  monthly(3, 'Monthly'),
  total(4, 'Total');

  final int option;
  final String label;
  const _Period(this.option, this.label);
}

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────

double _toD(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

class _Top10StockItem {
  final String stockCode;
  final String description;
  final double qty;
  _Top10StockItem(
      {required this.stockCode,
      required this.description,
      required this.qty});
  factory _Top10StockItem.fromJson(Map<String, dynamic> j) => _Top10StockItem(
        stockCode: (j['stockCode'] as String?) ?? '',
        description: (j['stockDescription'] as String?) ?? '',
        qty: _toD(j['qty']),
      );
}

class _Top10CustomerItem {
  final String code;
  final String name;
  final double amt;
  _Top10CustomerItem(
      {required this.code, required this.name, required this.amt});
  factory _Top10CustomerItem.fromJson(Map<String, dynamic> j) =>
      _Top10CustomerItem(
        code: (j['customerCode'] as String?) ?? '',
        name: (j['customerName'] as String?) ?? '',
        amt: _toD(j['amt']),
      );
}

class _Top10AgentItem {
  final String name;
  final double amt;
  _Top10AgentItem({required this.name, required this.amt});
  factory _Top10AgentItem.fromJson(Map<String, dynamic> j) => _Top10AgentItem(
        name: (j['salesAgentDescription'] as String?)?.isNotEmpty == true
            ? j['salesAgentDescription'] as String
            : (j['salesAgent'] as String?) ?? '',
        amt: _toD(j['amt']),
      );
}

class _Top10MovementItem {
  final String stockCode;
  final String description;
  final double qty;
  _Top10MovementItem(
      {required this.stockCode,
      required this.description,
      required this.qty});
  factory _Top10MovementItem.fromJson(Map<String, dynamic> j) =>
      _Top10MovementItem(
        stockCode: (j['stockCode'] as String?) ?? '',
        description: (j['stockDescription'] as String?) ??
            (j['itemDescription'] as String?) ??
            (j['description'] as String?) ??
            '',
        qty: _toD(j['qty']),
      );
}

class _RankedItem {
  final int rank;
  final String title;
  final String subtitle;
  final String value;
  final double barValue;
  final double maxValue;

  const _RankedItem({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.barValue,
    required this.maxValue,
  });
}

// ─────────────────────────────────────────────
// Analysis Page
// ─────────────────────────────────────────────

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage>
    with TickerProviderStateMixin {
  late TabController _outerTabController;
  _Period _period = _Period.total;

  final ScrollController _salesScrollController = ScrollController();
  final ScrollController _wmsScrollController = ScrollController();

  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';
  bool _sessionLoaded = false;

  // KPI (shared between Sales & WMS)
  double _salesAmount = 0;
  int _salesCount = 0;
  int _deliveryCount = 0;
  double _stockValue = 0;
  bool _kpiLoading = false;
  String? _kpiError;

  // Outstanding
  double _outstandingTotal = 0;
  int _outstandingCount = 0;
  bool _outstandingLoading = false;
  String? _outstandingError;

  // Sales Top 10
  List<_Top10StockItem> _top10Items = [];
  List<_Top10CustomerItem> _top10Customers = [];
  List<_Top10AgentItem> _top10Agents = [];
  bool _top10Loading = false;
  String? _top10Error;

  // WMS Top 10
  List<_Top10MovementItem> _top10Inbound = [];
  List<_Top10MovementItem> _top10Outbound = [];
  bool _wmsTop10Loading = false;
  String? _wmsTop10Error;

  late NumberFormat _amtFmt;
  late NumberFormat _qtyFmt;

  double get _avgOrderValue =>
      _salesCount > 0 ? _salesAmount / _salesCount : 0;
  double get _fulfillmentRate =>
      _salesCount > 0 ? (_deliveryCount / _salesCount) * 100 : 0;
  double get _collectionRate => _salesAmount > 0
      ? ((_salesAmount - _outstandingTotal) / _salesAmount * 100)
          .clamp(0.0, 100.0)
      : 0;

  @override
  void initState() {
    super.initState();
    _outerTabController = TabController(length: 2, vsync: this);
    _amtFmt = NumberFormat('#,##0.00');
    _qtyFmt = NumberFormat('#,##0.##');
    _loadSession();
  }

  @override
  void dispose() {
    _outerTabController.dispose();
    _salesScrollController.dispose();
    _wmsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final results = await Future.wait([
      SessionManager.getApiKey(),
      SessionManager.getCompanyGUID(),
      SessionManager.getUserID(),
      SessionManager.getUserSessionID(),
    ]);
    if (!mounted) return;
    setState(() {
      _apiKey = results[0] as String;
      _companyGUID = results[1] as String;
      _userID = results[2] as int;
      _userSessionID = results[3] as String;
      _sessionLoaded = true;
    });
    _fetchAll();
  }

  Map<String, dynamic> get _base => {
        'apiKey': _apiKey,
        'companyGUID': _companyGUID,
        'userID': _userID,
        'userSessionID': _userSessionID,
      };

  Map<String, dynamic> get _bodyOpt => {..._base, 'option': _period.option};

  Map<String, dynamic> get _outstandingBody {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfDay =
        DateTime(now.year, now.month, now.day, 23, 59, 59);
    DateTime from;
    switch (_period) {
      case _Period.today:
        from = today;
      case _Period.weekly:
        from = today.subtract(const Duration(days: 6));
      case _Period.monthly:
        from = DateTime(now.year, now.month, 1);
      case _Period.total:
        from = DateTime(2000, 1, 1);
    }
    return {
      ..._base,
      'isFilterByCreatedDateTime': true,
      'fromDate': from.toIso8601String(),
      'toDate': endOfDay.toIso8601String(),
      'customerIdList': <int>[],
    };
  }

  Future<void> _fetchAll() async {
    await Future.wait([
      _fetchKpi(),
      _fetchOutstanding(),
      _fetchSalesTop10(),
      _fetchWmsTop10(),
    ]);
  }

  Future<void> _fetchKpi() async {
    setState(() {
      _kpiLoading = true;
      _kpiError = null;
    });
    try {
      final results = await Future.wait([
        BaseClient.post(ApiEndpoints.getSalesByDateRange, body: _bodyOpt),
        BaseClient.post(ApiEndpoints.getTotalSalesCount, body: _bodyOpt),
        BaseClient.post(ApiEndpoints.getTotalPackingCount, body: _bodyOpt),
        BaseClient.post(ApiEndpoints.getStockValue, body: _base),
      ]);
      if (!mounted) return;
      setState(() {
        _salesAmount = _toD(results[0]);
        _salesCount = _toD(results[1]).toInt();
        _deliveryCount = _toD(results[2]).toInt();
        _stockValue = _toD(results[3]);
        _kpiLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _kpiLoading = false;
          _kpiError = e.toString();
        });
      }
    }
  }

  Future<void> _fetchOutstanding() async {
    setState(() {
      _outstandingLoading = true;
      _outstandingError = null;
    });
    try {
      final result = await BaseClient.post(
        ApiEndpoints.getOutstandingSalesList,
        body: _outstandingBody,
      );
      if (!mounted) return;
      final items = result as List<dynamic>;
      double total = 0;
      for (final item in items) {
        total += _toD((item as Map<String, dynamic>)['outstanding']);
      }
      setState(() {
        _outstandingTotal = total;
        _outstandingCount = items.length;
        _outstandingLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _outstandingLoading = false;
          _outstandingError = e.toString();
        });
      }
    }
  }

  Future<void> _fetchSalesTop10() async {
    setState(() {
      _top10Loading = true;
      _top10Error = null;
    });
    try {
      final results = await Future.wait([
        BaseClient.post(ApiEndpoints.getTop10SalesQtyByStock,
            body: _bodyOpt),
        BaseClient.post(ApiEndpoints.getTop10SalesAmtByCustomer,
            body: _bodyOpt),
        BaseClient.post(ApiEndpoints.getTop10Agent, body: _bodyOpt),
      ]);
      if (!mounted) return;
      setState(() {
        _top10Items = (results[0] as List<dynamic>)
            .map((e) =>
                _Top10StockItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _top10Customers = (results[1] as List<dynamic>)
            .map((e) =>
                _Top10CustomerItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _top10Agents = (results[2] as List<dynamic>)
            .map((e) =>
                _Top10AgentItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _top10Loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _top10Loading = false;
          _top10Error = e.toString();
        });
      }
    }
  }

  Future<void> _fetchWmsTop10() async {
    setState(() {
      _wmsTop10Loading = true;
      _wmsTop10Error = null;
    });
    try {
      final results = await Future.wait([
        BaseClient.post(ApiEndpoints.getTop10StockInbound,
            body: _bodyOpt),
        BaseClient.post(ApiEndpoints.getTop10StockOutbound,
            body: _bodyOpt),
      ]);
      if (!mounted) return;
      setState(() {
        _top10Inbound = (results[0] as List<dynamic>)
            .map((e) =>
                _Top10MovementItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _top10Outbound = (results[1] as List<dynamic>)
            .map((e) =>
                _Top10MovementItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _wmsTop10Loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _wmsTop10Loading = false;
          _wmsTop10Error = e.toString();
        });
      }
    }
  }

  void _onPeriodChange(_Period p) {
    if (_period == p) return;
    setState(() => _period = p);
    _fetchAll();
  }

  void _scrollToTop() {
    final ctrl = _outerTabController.index == 0
        ? _salesScrollController
        : _wmsScrollController;
    if (ctrl.hasClients) {
      ctrl.animateTo(0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut);
    }
  }

  // ── Data converters ───────────────────────────────────────────────────────

  List<_RankedItem> _itemsToRanked() {
    if (_top10Items.isEmpty) return [];
    return _top10Items.asMap().entries.map((e) => _RankedItem(
          rank: e.key + 1,
          title: e.value.description,
          subtitle: e.value.stockCode,
          value: _qtyFmt.format(e.value.qty),
          barValue: e.value.qty,
          maxValue: _top10Items.first.qty,
        )).toList();
  }

  List<_RankedItem> _customersToRanked() {
    if (_top10Customers.isEmpty) return [];
    return _top10Customers.asMap().entries.map((e) => _RankedItem(
          rank: e.key + 1,
          title: e.value.name,
          subtitle: e.value.code,
          value: _amtFmt.format(e.value.amt),
          barValue: e.value.amt,
          maxValue: _top10Customers.first.amt,
        )).toList();
  }

  List<_RankedItem> _agentsToRanked() {
    if (_top10Agents.isEmpty) return [];
    return _top10Agents.asMap().entries.map((e) => _RankedItem(
          rank: e.key + 1,
          title: e.value.name,
          subtitle: '',
          value: _amtFmt.format(e.value.amt),
          barValue: e.value.amt,
          maxValue: _top10Agents.first.amt,
        )).toList();
  }

  List<_RankedItem> _inboundToRanked() {
    if (_top10Inbound.isEmpty) return [];
    return _top10Inbound.asMap().entries.map((e) => _RankedItem(
          rank: e.key + 1,
          title: e.value.description,
          subtitle: e.value.stockCode,
          value: _qtyFmt.format(e.value.qty),
          barValue: e.value.qty,
          maxValue: _top10Inbound.first.qty,
        )).toList();
  }

  List<_RankedItem> _outboundToRanked() {
    if (_top10Outbound.isEmpty) return [];
    return _top10Outbound.asMap().entries.map((e) => _RankedItem(
          rank: e.key + 1,
          title: e.value.description,
          subtitle: e.value.stockCode,
          value: _qtyFmt.format(e.value.qty),
          barValue: e.value.qty,
          maxValue: _top10Outbound.first.qty,
        )).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: GestureDetector(
          onDoubleTap: _scrollToTop,
          behavior: HitTestBehavior.opaque,
          child: const SizedBox(
            width: double.infinity,
            child: Text('Analysis',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _fetchAll,
          ),
        ],
        bottom: TabBar(
          controller: _outerTabController,
          tabs: const [
            Tab(text: 'Sales'),
            Tab(text: 'Warehouse'),
          ],
        ),
      ),
      body: !_sessionLoaded
          ? const Center(child: DotsLoading())
          : TabBarView(
              controller: _outerTabController,
              children: [
                _buildSalesTab(primary, cs, scaffoldBg),
                _buildWmsTab(primary, cs, scaffoldBg),
              ],
            ),
    );
  }

  // ─────────────────────────────────────────────
  // Sales Tab
  // ─────────────────────────────────────────────

  Widget _buildSalesTab(
      Color primary, ColorScheme cs, Color scaffoldBg) {
    return DefaultTabController(
      length: 3,
      child: NestedScrollView(
        controller: _salesScrollController,
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PeriodSelector(
                    selected: _period,
                    onChanged: _onPeriodChange,
                    primary: primary,
                    cs: cs,
                  ),
                  _buildHeroCard(primary, cs),
                  const SizedBox(height: 10),
                  _buildSalesSecondaryRow(primary, cs),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'Outstanding & Collection',
                    Icons.account_balance_wallet_outlined,
                    const Color(0xFFE65100),
                    cs,
                  ),
                  const SizedBox(height: 10),
                  _buildOutstandingCard(primary, cs),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'Top 10 Rankings',
                    Icons.leaderboard_rounded,
                    primary,
                    cs,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            Material(
              color: scaffoldBg,
              child: TabBar(
                labelColor: primary,
                unselectedLabelColor:
                    cs.onSurface.withValues(alpha: 0.45),
                indicatorColor: primary,
                indicatorWeight: 2.5,
                dividerColor: cs.outline.withValues(alpha: 0.12),
                tabs: const [
                  Tab(text: 'Items'),
                  Tab(text: 'Customers'),
                  Tab(text: 'Agents'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTop10Tab(
                    _itemsToRanked(), const Color(0xFF1565C0),
                    cs, primary,
                    loading: _top10Loading,
                    error: _top10Error,
                    onRetry: _fetchSalesTop10,
                  ),
                  _buildTop10Tab(
                    _customersToRanked(), const Color(0xFF2E7D32),
                    cs, primary,
                    loading: _top10Loading,
                    error: null,
                    onRetry: _fetchSalesTop10,
                  ),
                  _buildTop10Tab(
                    _agentsToRanked(), const Color(0xFFE65100),
                    cs, primary,
                    loading: _top10Loading,
                    error: null,
                    onRetry: _fetchSalesTop10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // WMS Tab
  // ─────────────────────────────────────────────

  Widget _buildWmsTab(
      Color primary, ColorScheme cs, Color scaffoldBg) {
    const inboundColor = Color(0xFF1565C0);
    const outboundColor = Color(0xFFE65100);

    return DefaultTabController(
      length: 2,
      child: NestedScrollView(
        controller: _wmsScrollController,
        headerSliverBuilder: (ctx, _) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PeriodSelector(
                    selected: _period,
                    onChanged: _onPeriodChange,
                    primary: primary,
                    cs: cs,
                  ),
                  _buildSectionHeader(
                    'Warehouse Overview',
                    Icons.warehouse_outlined,
                    primary,
                    cs,
                  ),
                  const SizedBox(height: 10),
                  _buildWmsKpiRow(primary, cs),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    'Top 10 Stock Movement',
                    Icons.swap_vert_rounded,
                    primary,
                    cs,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
        body: Column(
          children: [
            Material(
              color: scaffoldBg,
              child: TabBar(
                labelColor: primary,
                unselectedLabelColor:
                    cs.onSurface.withValues(alpha: 0.45),
                indicatorColor: primary,
                indicatorWeight: 2.5,
                dividerColor: cs.outline.withValues(alpha: 0.12),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_downward_rounded,
                            size: 14, color: inboundColor),
                        SizedBox(width: 5),
                        Text('Inbound'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_upward_rounded,
                            size: 14, color: outboundColor),
                        SizedBox(width: 5),
                        Text('Outbound'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildTop10Tab(
                    _inboundToRanked(), inboundColor, cs, primary,
                    loading: _wmsTop10Loading,
                    error: _wmsTop10Error,
                    onRetry: _fetchWmsTop10,
                  ),
                  _buildTop10Tab(
                    _outboundToRanked(), outboundColor, cs, primary,
                    loading: _wmsTop10Loading,
                    error: null,
                    onRetry: _fetchWmsTop10,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── WMS KPI Row ───────────────────────────────────────────────────────────

  Widget _buildWmsKpiRow(Color primary, ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _SmallKpiCard(
            icon: Icons.local_shipping_outlined,
            iconColor: const Color(0xFFE65100),
            label: 'Deliveries',
            value: _deliveryCount.toString(),
            isLoading: _kpiLoading,
            cs: cs,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallKpiCard(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF795548),
            label: 'Stock Value',
            value: _amtFmt.format(_stockValue),
            isLoading: _kpiLoading,
            cs: cs,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallKpiCard(
            icon: Icons.receipt_outlined,
            iconColor: const Color(0xFF1565C0),
            label: 'Orders',
            value: _salesCount.toString(),
            isLoading: _kpiLoading,
            cs: cs,
          ),
        ),
      ],
    );
  }

  // ── Hero Card ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard(Color primary, ColorScheme cs) {
    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_rounded,
                        size: 13, color: primary),
                    const SizedBox(width: 4),
                    Text('Total Sales',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primary)),
                  ],
                ),
              ),
              const Spacer(),
              if (_kpiLoading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary.withValues(alpha: 0.35)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_kpiError != null)
            _errorWidget(_kpiError!, _fetchKpi, cs)
          else if (_kpiLoading && _salesAmount == 0)
            Container(
              height: 38,
              width: 180,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
            )
          else
            Text(
              _amtFmt.format(_salesAmount),
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: primary,
                letterSpacing: -0.5,
              ),
            ),
          const SizedBox(height: 16),
          Divider(
              height: 1,
              color: cs.outline.withValues(alpha: 0.12)),
          const SizedBox(height: 14),
          Row(
            children: [
              _heroMetric(
                icon: Icons.receipt_outlined,
                iconColor: const Color(0xFF1565C0),
                label: 'Orders',
                value: _salesCount.toString(),
                isLoading: _kpiLoading,
                cs: cs,
              ),
              Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: cs.outline.withValues(alpha: 0.13)),
              _heroMetric(
                icon: Icons.calculate_outlined,
                iconColor: const Color(0xFF6A1B9A),
                label: 'Avg Order Value',
                value: _amtFmt.format(_avgOrderValue),
                isLoading: _kpiLoading,
                cs: cs,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required bool isLoading,
    required ColorScheme cs,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.45))),
            const SizedBox(height: 2),
            isLoading
                ? Container(
                    height: 13,
                    width: 56,
                    decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4)))
                : Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: iconColor)),
          ],
        ),
      ],
    );
  }

  // ── Sales Secondary KPI Row ───────────────────────────────────────────────

  Widget _buildSalesSecondaryRow(Color primary, ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _SmallKpiCard(
            icon: Icons.local_shipping_outlined,
            iconColor: const Color(0xFFE65100),
            label: 'Deliveries',
            value: _deliveryCount.toString(),
            isLoading: _kpiLoading,
            cs: cs,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallKpiCard(
            icon: Icons.percent_rounded,
            iconColor: const Color(0xFF00695C),
            label: 'Fulfillment',
            value: '${_fulfillmentRate.toStringAsFixed(1)}%',
            isLoading: _kpiLoading,
            cs: cs,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SmallKpiCard(
            icon: Icons.inventory_2_outlined,
            iconColor: const Color(0xFF795548),
            label: 'Stock Value',
            value: _amtFmt.format(_stockValue),
            isLoading: _kpiLoading,
            cs: cs,
          ),
        ),
      ],
    );
  }

  // ── Outstanding Card ──────────────────────────────────────────────────────

  Widget _buildOutstandingCard(Color primary, ColorScheme cs) {
    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;
    const orangeColor = Color(0xFFE65100);
    const greenColor = Color(0xFF2E7D32);

    if (_outstandingError != null) {
      return _errorWidget(_outstandingError!, _fetchOutstanding, cs);
    }

    final rateColor = _collectionRate >= 80 ? greenColor : orangeColor;
    final rateLabel = _collectionRate >= 80
        ? 'Good'
        : _collectionRate >= 50
            ? 'Fair'
            : 'Low';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: _outstandingLoading
          ? _skeletonBox(cs, height: 90)
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Outstanding Amount',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface
                                      .withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 5),
                          Text(_amtFmt.format(_outstandingTotal),
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: orangeColor)),
                          const SizedBox(height: 3),
                          Text(
                            '$_outstandingCount unpaid order${_outstandingCount == 1 ? '' : 's'}',
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface
                                    .withValues(alpha: 0.45)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 68,
                      height: 68,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _collectionRate / 100,
                            strokeWidth: 6,
                            backgroundColor:
                                cs.onSurface.withValues(alpha: 0.07),
                            valueColor:
                                AlwaysStoppedAnimation(rateColor),
                          ),
                          Text(
                            '${_collectionRate.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: rateColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                    height: 1,
                    color: cs.outline.withValues(alpha: 0.1)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 12,
                        color: cs.onSurface.withValues(alpha: 0.35)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                          'Collection Rate = Collected ÷ Total Sales',
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface
                                  .withValues(alpha: 0.4))),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: rateColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(rateLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: rateColor)),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  // ── Top 10 Tab Content ────────────────────────────────────────────────────

  Widget _buildTop10Tab(
    List<_RankedItem> items,
    Color color,
    ColorScheme cs,
    Color primary, {
    required bool loading,
    required String? error,
    required VoidCallback onRetry,
  }) {
    if (loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [_top10Skeleton(cs)],
      );
    }
    if (error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_errorWidget(error, onRetry, cs)],
      );
    }
    if (items.isEmpty) {
      return ListView(children: [_emptyTop10(cs)]);
    }

    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;
    final top3 = items.take(3).toList();
    final rest = items.skip(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        _buildPodium(top3, color, cs, primary, cardColor),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: cs.outline.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: rest.asMap().entries.map((e) {
                final isLast = e.key == rest.length - 1;
                return Column(
                  children: [
                    _buildRankRow(e.value, color, cs, primary),
                    if (!isLast)
                      Divider(
                          height: 1,
                          indent: 48,
                          color:
                              cs.outline.withValues(alpha: 0.1)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  // ── Podium (Top 3) ────────────────────────────────────────────────────────

  Widget _buildPodium(List<_RankedItem> top3, Color color,
      ColorScheme cs, Color primary, Color cardColor) {
    final arranged = [
      top3.length > 1 ? top3[1] : null,
      top3.first,
      top3.length > 2 ? top3[2] : null,
    ];

    const podiumHeights = [72.0, 100.0, 52.0];
    const medals = ['🥈', '🥇', '🥉'];
    const podiumColors = [
      Color(0xFF9E9E9E),
      Color(0xFFFFB300),
      Color(0xFFBF6B2A),
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            final item = arranged[i];
            final isCenter = i == 1;

            if (item == null) {
              return Expanded(
                  child: SizedBox(height: podiumHeights[i]));
            }

            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(medals[i],
                      style:
                          TextStyle(fontSize: isCenter ? 38 : 28)),
                  const SizedBox(height: 6),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: isCenter ? 12 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6),
                      child: Text(
                        item.subtitle,
                        style: TextStyle(
                            fontSize: 10,
                            color: primary.withValues(alpha: 0.6)),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: isCenter ? 13 : 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: podiumHeights[i],
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          podiumColors[i].withValues(alpha: 0.25),
                          podiumColors[i].withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(10)),
                      border: Border(
                        top: BorderSide(
                            color: podiumColors[i]
                                .withValues(alpha: 0.65),
                            width: 2),
                        left: BorderSide(
                            color: podiumColors[i]
                                .withValues(alpha: 0.25),
                            width: 1),
                        right: BorderSide(
                            color: podiumColors[i]
                                .withValues(alpha: 0.25),
                            width: 1),
                      ),
                    ),
                    alignment: Alignment.topCenter,
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      '${item.rank}',
                      style: TextStyle(
                        fontSize: isCenter ? 22 : 18,
                        fontWeight: FontWeight.w800,
                        color:
                            podiumColors[i].withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Rank Row (4–10) ───────────────────────────────────────────────────────

  Widget _buildRankRow(
      _RankedItem item, Color color, ColorScheme cs, Color primary) {
    final barFraction =
        item.maxValue > 0 ? item.barValue / item.maxValue : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('${item.rank}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.45))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(item.subtitle,
                      style: TextStyle(
                          fontSize: 11,
                          color: primary.withValues(alpha: 0.7))),
                ],
                const SizedBox(height: 5),
                LayoutBuilder(
                  builder: (_, c) => Stack(children: [
                    Container(
                        height: 3,
                        width: c.maxWidth,
                        decoration: BoxDecoration(
                            color:
                                cs.onSurface.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(2))),
                    Container(
                        height: 3,
                        width: c.maxWidth * barFraction,
                        decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(2))),
                  ]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(item.value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  // ── Section Header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
      String title, IconData icon, Color color, ColorScheme cs) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color)),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
              color: color.withValues(alpha: 0.2), thickness: 1),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _errorWidget(
      String err, VoidCallback retry, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text('Failed to load',
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontSize: 13))),
          TextButton(
              onPressed: retry,
              child: const Text('Retry',
                  style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _top10Skeleton(ColorScheme cs) {
    return Column(
      children: List.generate(
          5,
          (_) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _skeletonBox(cs, height: 54),
              )),
    );
  }

  Widget _skeletonBox(ColorScheme cs, {required double height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _emptyTop10(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text('No data for this period',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.4),
                fontStyle: FontStyle.italic)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Period Selector
// ─────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final _Period selected;
  final void Function(_Period) onChanged;
  final Color primary;
  final ColorScheme cs;

  const _PeriodSelector({
    required this.selected,
    required this.onChanged,
    required this.primary,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: _Period.values.map((p) {
          final sel = p == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? primary
                      : primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  p.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : primary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Small KPI Card
// ─────────────────────────────────────────────

class _SmallKpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool isLoading;
  final ColorScheme cs;

  const _SmallKpiCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.isLoading,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardTheme.color ?? cs.surface;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 3),
          isLoading
              ? Container(
                  height: 13,
                  width: 48,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ))
              : Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ],
      ),
    );
  }
}
