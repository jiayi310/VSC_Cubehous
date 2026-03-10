import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/base_client.dart';
import '../../common/my_color.dart';
import '../../common/session_manager.dart';
import '../../models/stock.dart';

// ─────────────────────────────────────────────
// Sort options
// ─────────────────────────────────────────────

const _sortOptions = [
  ('Stock Code', 'StockCode'),
  ('Description', 'Description'),
  ('Description 2', 'Desc2'),
  ('UOM', 'BaseUOM'),
  ('Price', 'BaseUOMPrice1'),
  ('Has Batch', 'HasBatch'),
  ('Group', 'StockGroupID'),
  ('Type', 'StockTypeID'),
  ('Category', 'StockCategoryID'),
  ('Is Active', 'IsActive'),
];

// ─────────────────────────────────────────────
// Stock Item Page
// ─────────────────────────────────────────────

class StockItemPage extends StatefulWidget {
  const StockItemPage({super.key});

  @override
  State<StockItemPage> createState() => _StockItemPageState();
}

class _StockItemPageState extends State<StockItemPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  // Settings
  String _displayMode = 'grid';
  int _itemsPerPage = 20;

  // Data
  List<Stock> _stocks = [];
  bool _isLoading = false;
  String? _error;

  // Pagination
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalCount = 0;

  // Search & filter
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'StockCode';
  bool _sortAsc = true;
  double? _minPrice;
  double? _maxPrice;

  // Active filter count badge
  int get _activeFilters =>
      (_minPrice != null ? 1 : 0) +
      (_maxPrice != null ? 1 : 0) +
      (_sortBy != 'StockCode' ? 1 : 0);

  final _scrollController = ScrollController();
  final _priceFormatter = NumberFormat('#,##0.00');

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
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    _displayMode = await SessionManager.getDisplayMode();
    _itemsPerPage = await SessionManager.getItemsPerPage();
    if (mounted) setState(() {});
    await _fetch(page: 0);
  }

  Future<void> _fetch({int? page}) async {
    if (_isLoading) return;
    final targetPage = page ?? _currentPage;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final body = <String, dynamic>{
        'apiKey': _apiKey,
        'companyGUID': _companyGUID,
        'userID': _userID.toString(),
        'userSessionID': _userSessionID,
        'pageIndex': targetPage,
        'pageSize': _itemsPerPage,
        'sortBy': _sortBy,
        'isSortByAscending': _sortAsc,
        'searchTerm': _searchQuery ?? null,
        'filterMinPrice': _minPrice ?? 0,
        'filterMaxPrice': _maxPrice ?? 0,
      };

      final response = await BaseClient.post(
        '/Stock/GetStockListByCompanyId',
        body: body,
      ) as Map<String, dynamic>;

      final stockResponse = StockResponse.fromJson(response);

      if (mounted) {
        final pg = stockResponse.pagination;
        final totalRecord = pg?.totalRecord ?? 0;
        final pageSize = pg?.pageSize ?? _itemsPerPage;
        setState(() {
          _stocks = stockResponse.data ?? [];
          _currentPage = targetPage;
          _totalCount = totalRecord;
          _totalPages = pageSize > 0 ? (totalRecord / pageSize).ceil() : 1;
          if (_totalPages < 1) _totalPages = 1;
        });
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      }
    } catch (e) {
      print('Error: ' + e.toString());
      if (mounted) setState(() => _error = 'Failed to load items. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setDisplayMode(String mode) async {
    await SessionManager.saveDisplayMode(mode);
    if (mounted) setState(() => _displayMode = mode);
  }

  void _onSearchSubmit(String query) {
    setState(() => _searchQuery = query.trim());
    _fetch(page: 0);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _fetch(page: 0);
  }

  void _showFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        sortBy: _sortBy,
        sortAsc: _sortAsc,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        onApply: (sortBy, sortAsc, minPrice, maxPrice) {
          setState(() {
            _sortBy = sortBy;
            _sortAsc = sortAsc;
            _minPrice = minPrice;
            _maxPrice = maxPrice;
          });
          _fetch(page: 0);
        },
        onReset: () {
          setState(() {
            _sortBy = 'StockCode';
            _sortAsc = true;
            _minPrice = null;
            _maxPrice = null;
          });
          _fetch(page: 0);
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Item',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          // Filter
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_outlined),
                tooltip: 'Filter',
                onPressed: _showFilter,
              ),
              if (_activeFilters > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Mycolor.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFilters',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmit,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: _clearSearch,
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: () => _fetch(page: 0));
    }
    if (_stocks.isEmpty) {
      return const _EmptyState();
    }

    final labelColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        // Info bar: count + display mode toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
          child: Row(
            children: [
              Text(
                '$_totalCount item${_totalCount == 1 ? '' : 's'} found',
                style: TextStyle(fontSize: 12, color: labelColor),
              ),
              const Spacer(),
              // Display mode toggle
              _ModeButton(
                icon: Icons.grid_view_rounded,
                active: _displayMode == 'grid',
                onTap: () => _setDisplayMode('grid'),
              ),
              const SizedBox(width: 4),
              _ModeButton(
                icon: Icons.view_list_outlined,
                active: _displayMode == 'list',
                onTap: () => _setDisplayMode('list'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _displayMode == 'grid' ? _buildGrid() : _buildList(),
        ),
        // Pagination bar
        _PaginationBar(
          currentPage: _currentPage,
          totalPages: _totalPages,
          isLoading: _isLoading,
          primary: primary,
          onPrev: _currentPage > 0 ? () => _fetch(page: _currentPage - 1) : null,
          onNext: _currentPage < _totalPages - 1 ? () => _fetch(page: _currentPage + 1) : null,
        ),
      ],
    );
  }

  // ── Grid View ─────────────────────────────────

  Widget _buildGrid() {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 3 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 210,
      ),
      itemCount: _stocks.length,
      itemBuilder: (_, i) => _GridCard(
        stock: _stocks[i],
        priceFormatter: _priceFormatter,
      ),
    );
  }

  // ── List View ─────────────────────────────────

  Widget _buildList() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: _stocks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ListCard(
        stock: _stocks[i],
        priceFormatter: _priceFormatter,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Grid card (with image)
// ─────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final Stock stock;
  final NumberFormat priceFormatter;
  const _GridCard({required this.stock, required this.priceFormatter});

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
        onTap: () {}, // TODO: detail page
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 110,
                width: double.infinity,
                child: _StockImage(base64: stock.image),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stock.stockCode,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stock.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stock.baseUOM,
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                      Text(
                        priceFormatter.format(stock.baseUOMPrice1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (!stock.isActive) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Inactive',
                        style: TextStyle(fontSize: 9, color: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// List card (no image)
// ─────────────────────────────────────────────

class _ListCard extends StatelessWidget {
  final Stock stock;
  final NumberFormat priceFormatter;
  const _ListCard({required this.stock, required this.priceFormatter});

  @override
  Widget build(BuildContext context) {
    final cardColor =
        Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface;
    final primary = Theme.of(context).colorScheme.primary;

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(12),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {}, // TODO: detail page
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stock.stockCode,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                        if (!stock.isActive) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Inactive',
                              style:
                                  TextStyle(fontSize: 9, color: Colors.red),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stock.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.75),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (stock.desc2.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(
                        stock.desc2,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    priceFormatter.format(stock.baseUOMPrice1),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stock.baseUOM,
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stock image (base64 → Image.memory)
// ─────────────────────────────────────────────

class _StockImage extends StatelessWidget {
  final String? base64;
  const _StockImage({this.base64});

  @override
  Widget build(BuildContext context) {
    if (base64 != null && base64!.isNotEmpty) {
      try {
        // Strip data URI prefix if present (e.g. "data:image/png;base64,...")
        final raw = base64!.contains(',') ? base64!.split(',').last : base64!;
        final bytes = base64Decode(raw);
        return Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true);
      } catch (_) {
        // Fall through to placeholder
      }
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
      child: Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 36,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 52,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_outlined, size: 52,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25)),
          const SizedBox(height: 16),
          Text('No items found',
              style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Display mode toggle button
// ─────────────────────────────────────────────

class _ModeButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ModeButton({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: active ? primary.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18,
            color: active
                ? primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Pagination bar
// ─────────────────────────────────────────────

class _PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final Color primary;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.isLoading,
    required this.primary,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: isLoading ? null : onPrev,
            style: IconButton.styleFrom(
              foregroundColor: onPrev != null ? primary : null,
            ),
          ),
          const SizedBox(width: 8),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Text(
              'Page ${currentPage + 1} of $totalPages',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isLoading ? null : onNext,
            style: IconButton.styleFrom(
              foregroundColor: onNext != null ? primary : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Filter bottom sheet
// ─────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String sortBy;
  final bool sortAsc;
  final double? minPrice;
  final double? maxPrice;
  final void Function(String sortBy, bool sortAsc, double? minPrice, double? maxPrice) onApply;
  final VoidCallback onReset;

  const _FilterSheet({
    required this.sortBy,
    required this.sortAsc,
    required this.minPrice,
    required this.maxPrice,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _sortBy;
  late bool _sortAsc;
  late TextEditingController _minCtrl;
  late TextEditingController _maxCtrl;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.sortBy;
    _sortAsc = widget.sortAsc;
    _minCtrl = TextEditingController(
        text: widget.minPrice != null ? widget.minPrice!.toStringAsFixed(2) : '');
    _maxCtrl = TextEditingController(
        text: widget.maxPrice != null ? widget.maxPrice!.toStringAsFixed(2) : '');
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Row(
              children: [
                const Text('Filter & Sort',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
            const SizedBox(height: 16),

            // Sort By
            Text('Sort By',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _sortBy,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              items: _sortOptions
                  .map((o) =>
                      DropdownMenuItem(value: o.$2, child: Text(o.$1)))
                  .toList(),
              onChanged: (v) => setState(() => _sortBy = v!),
            ),
            const SizedBox(height: 12),

            // Sort direction
            Text('Sort Direction',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _DirectionChip(
                    label: 'Ascending',
                    icon: Icons.arrow_upward_rounded,
                    selected: _sortAsc,
                    onTap: () => setState(() => _sortAsc = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DirectionChip(
                    label: 'Descending',
                    icon: Icons.arrow_downward_rounded,
                    selected: !_sortAsc,
                    onTap: () => setState(() => _sortAsc = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Price range
            Text('Price Range',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Min',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('—'),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _maxCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Max',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Apply button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final minP = double.tryParse(_minCtrl.text);
                  final maxP = double.tryParse(_maxCtrl.text);
                  Navigator.pop(context);
                  widget.onApply(_sortBy, _sortAsc, minP, maxP);
                },
                child: const Text('Apply',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _DirectionChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? primary.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
              color: selected ? primary : Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? primary : null),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? primary : null)),
          ],
        ),
      ),
    );
  }
}
