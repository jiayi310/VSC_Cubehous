import 'package:cubehous/view/Common/customer_picker_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/date_pill.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';
import '../../../models/customer.dart';
import '../../../models/sales.dart';

class CustomerHistoryPage extends StatefulWidget {
  const CustomerHistoryPage({super.key});

  @override
  State<CustomerHistoryPage> createState() => _CustomerHistoryPageState();
}

class _CustomerHistoryPageState extends State<CustomerHistoryPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  // Customer
  Customer? _selectedCustomer;

  // Data
  List<CustomerPurchaseStock> _items = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  // Pagination
  int _currentPage = 0;
  int _totalCount = 0;
  static const _pageSize = 20;
  bool get _hasMore => _items.length < _totalCount;

  // Date filter
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _amtFmt = NumberFormat('#,##0.00');
  final _qtyFmt = NumberFormat('#,##0.##');

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSession();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetchHistory({required bool reset}) async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    if (_selectedCustomer == null) return;
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 0;
      });
    }
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getCustomerPurchaseStock,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'isFilterByCreatedDateTime': false,
          'fromDate': _fromDate.toIso8601String(),
          'toDate': _toDate.add(const Duration(days: 1)).toIso8601String(),
          'pageIndex': reset ? 0 : _currentPage,
          'pageSize': _pageSize,
          'sortBy': 'StockID',
          'isSortByAscending': true,
          'searchTerm': null,
          'customerID': _selectedCustomer!.customerID,
        },
      );

      List<CustomerPurchaseStock> newItems;
      int total;

      if (response is List) {
        newItems = response
            .map((e) =>
                CustomerPurchaseStock.fromJson(e as Map<String, dynamic>))
            .toList();
        total = newItems.length;
      } else {
        final result = CustomerPurchaseResponse.fromJson(
            response as Map<String, dynamic>);
        newItems = result.data ?? [];
        total = result.pagination?.totalRecord ?? newItems.length;
      }

      setState(() {
        if (reset) {
          _items = newItems;
        } else {
          _items = [..._items, ...newItems];
        }
        _totalCount = total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await _fetchHistory(reset: false);
  }

  Future<void> _pickCustomer() async {
    final picked = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerPickerPage(
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedCustomer = picked;
        _items = [];
        _totalCount = 0;
        _currentPage = 0;
        _error = null;
      });
      await _fetchHistory(reset: true);
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: _toDate,
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      _fetchHistory(reset: true);
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate,
      firstDate: _fromDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
      _fetchHistory(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer History',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Customer picker card ─────────────────────────────────────
          GestureDetector(
            onTap: _pickCustomer,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: _selectedCustomer == null
                    ? Border.all(
                        color: primary.withValues(alpha: 0.3),
                        style: BorderStyle.solid,
                        width: 1.5,
                      )
                    : Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  if (_selectedCustomer != null) ...[
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          primary.withValues(alpha: 0.12),
                      child: Text(
                        _selectedCustomer!.name.isNotEmpty
                            ? _selectedCustomer!.name[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedCustomer!.name,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _selectedCustomer!.customerCode,
                            style: TextStyle(
                                fontSize: 12, color: primary),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.person_search_outlined,
                        size: 22, color: primary.withValues(alpha: 0.5)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tap to select customer',
                        style: TextStyle(
                            fontSize: 14, color: muted),
                      ),
                    ),
                  ],
                  Icon(Icons.chevron_right,
                      size: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3)),
                ],
              ),
            ),
          ),

          // ── Date filter row ──────────────────────────────────────────
          if (_selectedCustomer != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: DatePill(
                      label: 'From',
                      date: _dateFmt.format(_fromDate),
                      onTap: _pickFromDate,
                      primary: primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DatePill(
                      label: 'To',
                      date: _dateFmt.format(_toDate),
                      onTap: _pickToDate,
                      primary: primary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1),

          // ── List area ────────────────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_selectedCustomer == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_search_outlined,
                  size: 56,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2)),
              const SizedBox(height: 16),
              Text(
                'Select a customer to view\ntheir purchase history',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45)),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) return const Center(child: DotsLoading());

    if (_error != null) {
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
              Text(_error ?? '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.4))),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _fetchHistory(reset: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_bag_outlined,
                  size: 52,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2)),
              const SizedBox(height: 14),
              Text(
                'No purchase history found',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45)),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchHistory(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: DotsLoading()),
            );
          }
          return _PurchaseStockTile(
            item: _items[i],
            amtFmt: _amtFmt,
            qtyFmt: _qtyFmt,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Purchase stock tile
// ─────────────────────────────────────────────────────────────────────

class _PurchaseStockTile extends StatelessWidget {
  final CustomerPurchaseStock item;
  final NumberFormat amtFmt;
  final NumberFormat qtyFmt;

  const _PurchaseStockTile({
    required this.item,
    required this.amtFmt,
    required this.qtyFmt,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_outlined,
                size: 22, color: primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: stockCode | total
                Row(
                  children: [
                    Text(
                      item.stockCode,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'RM ${amtFmt.format(item.totalAmt)}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Row 2: description
                Text(
                  item.description,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                // Row 3: UOM chip | qty chip | unit price
                Row(
                  children: [
                    _PillChip(label: item.uom),
                    const SizedBox(width: 6),
                    _PillChip(
                        label: 'x${qtyFmt.format(item.totalQty)}'),
                    const Spacer(),
                    Text(
                      'RM ${amtFmt.format(item.unitPrice)}/unit',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PillChip extends StatelessWidget {
  final String label;
  const _PillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.7)),
      ),
    );
  }
}
