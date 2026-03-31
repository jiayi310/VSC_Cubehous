import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/date_pill.dart';
import '../../common/direction_chip.dart';
import '../../common/dots_loading.dart';
import '../../common/pagination_bar.dart';
import '../../common/session_manager.dart';
import '../../models/purchase_order.dart';
import 'purchase_detail.dart';

const _sortOptions = [
  ('Doc No', 'DocNo'),
  ('Doc Date', 'DocDate'),
  ('Supplier', 'SupplierName'),
  ('Total', 'FinalTotal'),
];

class PurchaseListPage extends StatefulWidget {
  const PurchaseListPage({super.key});

  @override
  State<PurchaseListPage> createState() => _PurchaseListPageState();
}

class _PurchaseListPageState extends State<PurchaseListPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';
  List<String> _accessRights = [];

  // Settings
  int _itemsPerPage = 20;

  // Data
  List<PurchaseListItem> _purchases = [];
  bool _isLoading = false;
  String? _error;

  // Pagination
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalCount = 0;

  // Search & sort
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'DocNo';
  bool _sortAsc = false;

  // Date filter
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _amtFmt = NumberFormat('#,##0.00');

  final _scrollController = ScrollController();

  int get _activeFilters =>
      (_sortBy != 'DocNo' ? 1 : 0) + (!_sortAsc ? 0 : 1);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      SessionManager.getApiKey(),
      SessionManager.getCompanyGUID(),
      SessionManager.getUserID(),
      SessionManager.getUserSessionID(),
      SessionManager.getUserAccessRight(),
      SessionManager.getItemsPerPage(),
    ]);
    _apiKey = results[0] as String;
    _companyGUID = results[1] as String;
    _userID = results[2] as int;
    _userSessionID = results[3] as String;
    _accessRights = results[4] as List<String>;
    _itemsPerPage = results[5] as int;
    await _fetchPurchases(page: 0);
  }

  bool _hasAccess(String right) => _accessRights.contains(right);

  void _showNoAccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text(
            'You do not have the access right to perform this action.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(String docNo) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 32, color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Purchase Order',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Are you sure you want to delete\n$docNo?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.6),
                      height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
              Divider(
                  height: 1, color: cs.outline.withValues(alpha: 0.15)),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(20)),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface
                                    .withValues(alpha: 0.6))),
                      ),
                    ),
                    VerticalDivider(
                        width: 1,
                        color: cs.outline.withValues(alpha: 0.15)),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(20)),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _deletePurchase(int docID) async {
    try {
      await BaseClient.post(
        ApiEndpoints.removePurchase,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': docID,
        },
      );
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Failed to delete: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
      return false;
    }
  }

  Future<void> _fetchPurchases({required int page}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getPurchaseList,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'isFilterByCreatedDateTime': false,
          'fromDate': _fromDate.toIso8601String(),
          'toDate':
              _toDate.add(const Duration(days: 1)).toIso8601String(),
          'pageIndex': page,
          'pageSize': _itemsPerPage,
          'sortBy': _sortBy,
          'isSortByAscending': _sortAsc,
          'searchTerm': _searchQuery.isEmpty ? null : _searchQuery,
        },
      );

      final result =
          PurchaseResponse.fromJson(response as Map<String, dynamic>);
      final items = result.data ?? [];
      final totalRecord =
          result.pagination?.totalRecord ?? items.length;
      final pageSize =
          result.pagination?.pageSize ?? _itemsPerPage;

      if (mounted) {
        setState(() {
          _purchases = items;
          _currentPage = page;
          _totalCount = totalRecord;
          _totalPages =
              pageSize > 0 ? (totalRecord / pageSize).ceil() : 1;
          if (_totalPages < 1) _totalPages = 1;
        });
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() => _fetchPurchases(page: 0);

  void _onSearchSubmit(String value) {
    setState(() => _searchQuery = value.trim());
    _fetchPurchases(page: 0);
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
      _fetchPurchases(page: 0);
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
      _fetchPurchases(page: 0);
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SortSheet(
        sortBy: _sortBy,
        sortAsc: _sortAsc,
        onApply: (sortBy, sortAsc) {
          setState(() {
            _sortBy = sortBy;
            _sortAsc = sortAsc;
          });
          _fetchPurchases(page: 0);
        },
        onReset: () {
          setState(() {
            _sortBy = 'DocNo';
            _sortAsc = true;
          });
          _fetchPurchases(page: 0);
        },
      ),
    );
  }

  Future<void> _onDeleteTap(PurchaseListItem p) async {
    if (!_hasAccess('PURCHASE_DELETE')) {
      _showNoAccessDialog();
      return;
    }
    final confirmed = await _confirmDelete(p.docNo);
    if (confirmed != true) return;
    final ok = await _deletePurchase(p.docID);
    if (ok && mounted) {
      setState(
          () => _purchases.removeWhere((e) => e.docID == p.docID));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Purchase order deleted'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Purchase Order',
            onPressed: () {
              if (!_hasAccess('PURCHASE_ADD')) {
                _showNoAccessDialog();
                return;
              }
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                  content:
                      Text('Create purchase available on web'),
                  behavior: SnackBarBehavior.floating,
                ));
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              // Date range row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                        child: DatePill(
                      label: 'From',
                      date: _dateFmt.format(_fromDate),
                      onTap: _pickFromDate,
                      primary: primary,
                    )),
                    const SizedBox(width: 8),
                    Expanded(
                        child: DatePill(
                      label: 'To',
                      date: _dateFmt.format(_toDate),
                      onTap: _pickToDate,
                      primary: primary,
                    )),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              // Search + filter row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _onSearchSubmit,
                        onChanged: (v) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search purchase orders...',
                          suffixIcon:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear,
                                          size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(
                                            () => _searchQuery = '');
                                        _fetchPurchases(page: 0);
                                      },
                                    )
                                  : null,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Search button
                    Material(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            _onSearchSubmit(_searchController.text),
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.search, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Filter button
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Material(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _showFilterSheet,
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(Icons.tune_outlined,
                                  size: 20),
                            ),
                          ),
                        ),
                        if (_activeFilters > 0)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$_activeFilters',
                                  style: const TextStyle(
                                      fontSize: 8,
                                      color: Colors.white,
                                      fontWeight:
                                          FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: DotsLoading());
    if (_error != null) return _buildError();
    final primary = Theme.of(context).colorScheme.primary;
    final start = _currentPage * _itemsPerPage + 1;
    final end =
        ((_currentPage + 1) * _itemsPerPage).clamp(0, _totalCount);
    return Column(
      children: [
        if (_purchases.isEmpty)
          Expanded(child: _buildEmpty())
        else
          Expanded(child: _buildList(start: start, end: end)),
        PaginationBar(
          currentPage: _currentPage,
          totalPages: _totalPages,
          isLoading: _isLoading,
          primary: primary,
          onPrev: _currentPage > 0
              ? () => _fetchPurchases(page: _currentPage - 1)
              : null,
          onNext: _currentPage < _totalPages - 1
              ? () => _fetchPurchases(page: _currentPage + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildList({required int start, required int end}) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SlidableAutoCloseBehavior(
        child: ListView.builder(
          controller: _scrollController,
          itemCount: _purchases.length + 1,
          itemBuilder: (context, i) {
            if (i == _purchases.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    'Showing $start–$end of $_totalCount records',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }
            final p = _purchases[i];
            return Slidable(
              key: ValueKey(p.docID),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.26,
                children: [
                  CustomSlidableAction(
                    onPressed: (_) => _onDeleteTap(p),
                    backgroundColor:
                        Colors.red.withValues(alpha: 0.12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.delete_outline,
                            size: 26, color: Colors.red),
                        SizedBox(height: 4),
                        Text('Delete',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
              child: _PurchaseTile(
                purchase: p,
                amtFmt: _amtFmt,
                dateFmt: _dateFmt,
                onTap: () async {
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PurchaseDetailPage(docID: p.docID),
                    ),
                  );
                  if (result == true && mounted) {
                    _fetchPurchases(page: _currentPage);
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildError() {
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
            const Text('Failed to load purchase orders',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4))),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _fetchPurchases(page: 0),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_basket_outlined,
                size: 52,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No purchase orders found',
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
}

// ─────────────────────────────────────────────────────────────────────
// Purchase tile
// ─────────────────────────────────────────────────────────────────────

class _PurchaseTile extends StatelessWidget {
  final PurchaseListItem purchase;
  final NumberFormat amtFmt;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  const _PurchaseTile({
    required this.purchase,
    required this.amtFmt,
    required this.dateFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);

    DateTime? docDate;
    try {
      docDate = DateTime.parse(purchase.docDate);
    } catch (_) {}

    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            // Doc icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: purchase.isVoid
                    ? Colors.red.withValues(alpha: 0.1)
                    : primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.shopping_basket_outlined,
                size: 22,
                color: purchase.isVoid ? Colors.red : primary,
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: DocNo + VOID badge | Date
                  Row(
                    children: [
                      Text(
                        purchase.docNo,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (purchase.isVoid) _VoidBadge(),
                      const Spacer(),
                      Text(
                        docDate != null
                            ? dateFmt.format(docDate)
                            : purchase.docDate,
                        style:
                            TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Row 2: Supplier name
                  Text(
                    purchase.supplierName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Row 3: RECEIVED badge | Total
                  Row(
                    children: [
                      if (purchase.isReceive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'RECEIVED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.green,
                              letterSpacing: 0.5,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      const Spacer(),
                      Text(
                        'RM ${amtFmt.format(purchase.finalTotal)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoidBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'VOID',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.red,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sort bottom sheet
// ─────────────────────────────────────────────────────────────────────

class _SortSheet extends StatefulWidget {
  final String sortBy;
  final bool sortAsc;
  final void Function(String sortBy, bool sortAsc) onApply;
  final VoidCallback onReset;

  const _SortSheet({
    required this.sortBy,
    required this.sortAsc,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_SortSheet> createState() => _SortSheetState();
}

class _SortSheetState extends State<_SortSheet> {
  late String _sortBy;
  late bool _sortAsc;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.sortBy;
    _sortAsc = widget.sortAsc;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.8,
      expand: false,
      builder: (_, scrollCtrl) => Material(
        color: surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
              child: Row(
                children: [
                  const Text('Sort',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onReset();
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text('Sort By',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _sortBy,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(10)),
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                    ),
                    items: _sortOptions
                        .map((o) => DropdownMenuItem(
                            value: o.$2, child: Text(o.$1)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _sortBy = v!),
                  ),
                  const SizedBox(height: 16),
                  Text('Direction',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DirectionChip(
                          label: 'Ascending',
                          icon: Icons.arrow_upward_rounded,
                          selected: _sortAsc,
                          onTap: () =>
                              setState(() => _sortAsc = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DirectionChip(
                          label: 'Descending',
                          icon: Icons.arrow_downward_rounded,
                          selected: !_sortAsc,
                          onTap: () =>
                              setState(() => _sortAsc = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onApply(_sortBy, _sortAsc);
                      },
                      child: const Text('Apply',
                          style: TextStyle(
                              fontWeight: FontWeight.w600)),
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
}
