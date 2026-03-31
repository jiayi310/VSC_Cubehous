import 'package:cubehous/api/api_endpoints.dart';
import 'package:cubehous/api/base_client.dart';
import 'package:cubehous/common/direction_chip.dart';
import 'package:cubehous/common/dots_loading.dart';
import 'package:cubehous/common/my_color.dart';
import 'package:cubehous/common/pagination_bar.dart';
import 'package:cubehous/common/session_manager.dart';
import 'package:cubehous/models/sales.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _sortOptions = [
  ('Doc No', 'DocNo'),
  ('Doc Date', 'DocDate'),
  ('Total', 'FinalTotal'),
  ('Outstanding', 'Outstanding'),
];

class CollectionSalesPickerPage extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final String userSessionID;
  final int userID;
  final int customerID;
  final List<SalesListItem> initialSelected;

  const CollectionSalesPickerPage({
    super.key,
    required this.apiKey,
    required this.companyGUID,
    required this.userSessionID,
    required this.userID,
    required this.customerID,
    required this.initialSelected,
  });

  @override
  State<CollectionSalesPickerPage> createState() =>
      _CollectionSalesPickerPageState();
}

class _CollectionSalesPickerPageState
    extends State<CollectionSalesPickerPage> {
  // Pagination
  int _itemsPerPage = 20;
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalCount = 0;

  // Data
  List<SalesListItem> _sales = [];
  bool _isLoading = false;
  String? _error;

  // Selection
  Set<int> _selected = {};

  // Search & sort
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'DocDate';
  bool _sortAsc = false;

  final _scrollController = ScrollController();
  late NumberFormat _amtFmt;
  final _dateFmt = DateFormat('dd/MM/yyyy');

  int get _activeFilters =>
      (_sortBy != 'DocDate' ? 1 : 0) + (_sortAsc ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.map((s) => s.docID).toSet();
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
      SessionManager.getSalesDecimalPoint(),
      SessionManager.getItemsPerPage(),
    ]);
    _amtFmt = NumberFormat('#,##0.${'0' * results[0]}');
    _itemsPerPage = results[1];
    _fetch(page: 0);
  }

  Future<void> _fetch({required int page}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getSalesListForCollect,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'pageIndex': page,
          'pageSize': _itemsPerPage,
          'sortBy': _sortBy,
          'isSortByAscending': _sortAsc,
          'searchTerm': _searchQuery.isEmpty ? null : _searchQuery,
          'customerID': widget.customerID,
        },
      );
      final raw = response as Map<String, dynamic>;
      final data = (raw['data'] as List<dynamic>?)
              ?.map((e) => SalesListItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final pagination = raw['paginationOpt'] as Map<String, dynamic>?;
      final totalRecord = (pagination?['totalRecord'] as int?) ?? data.length;
      final pageSize = (pagination?['pageSize'] as int?) ?? _itemsPerPage;

      if (mounted) {
        setState(() {
          _sales = data;
          _currentPage = page;
          _totalCount = totalRecord;
          _totalPages = pageSize > 0 ? (totalRecord / pageSize).ceil() : 1;
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

  void _onSearchSubmit(String value) {
    setState(() => _searchQuery = value.trim());
    _fetch(page: 0);
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
          _fetch(page: 0);
        },
        onReset: () {
          setState(() {
            _sortBy = 'DocDate';
            _sortAsc = false;
          });
          _fetch(page: 0);
        },
      ),
    );
  }

  void _confirm() {
    final result = _sales.where((s) => _selected.contains(s.docID)).toList();
    // Also include initially selected items that may not be on this page
    for (final s in widget.initialSelected) {
      if (_selected.contains(s.docID) &&
          !result.any((r) => r.docID == s.docID)) {
        result.add(s);
      }
    }
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Orders',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
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
                      hintText: 'Search sales orders...',
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                                _fetch(page: 0);
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
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
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _onSearchSubmit(_searchController.text),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.search, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Material(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showFilterSheet,
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(Icons.tune_outlined, size: 20),
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
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            isLoading: _isLoading,
            primary: primary,
            onPrev: _currentPage > 0 ? () => _fetch(page: _currentPage - 1) : null,
            onNext: _currentPage < _totalPages - 1
                ? () => _fetch(page: _currentPage + 1)
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _selected.isEmpty ? null : _confirm,
                  child: Text(
                    _selected.isEmpty
                        ? 'Confirm'
                        : 'Confirm (${_selected.length} selected)',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: DotsLoading());
    if (_error != null) return _buildError();
    if (_sales.isEmpty) return _buildEmpty();

    final start = _currentPage * _itemsPerPage + 1;
    final end = ((_currentPage + 1) * _itemsPerPage).clamp(0, _totalCount);

    return ListView.builder(
      controller: _scrollController,
      itemCount: _sales.length + 1,
      itemBuilder: (context, i) {
        if (i == _sales.length) {
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
        final sale = _sales[i];
        final isSelected = _selected.contains(sale.docID);
        return _SalesTile(
          sale: sale,
          isSelected: isSelected,
          amtFmt: _amtFmt,
          dateFmt: _dateFmt,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selected.remove(sale.docID);
              } else {
                _selected.add(sale.docID);
              }
            });
          },
        );
      },
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
            const Text('Failed to load sales orders',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
              onPressed: () => _fetch(page: _currentPage),
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
            Icon(Icons.receipt_long_outlined,
                size: 52,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No sales orders found',
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
// Sales tile
// ─────────────────────────────────────────────────────────────────────

class _SalesTile extends StatelessWidget {
  final SalesListItem sale;
  final bool isSelected;
  final NumberFormat amtFmt;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  const _SalesTile({
    required this.sale,
    required this.isSelected,
    required this.amtFmt,
    required this.dateFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);

    DateTime? docDate;
    try {
      docDate = DateTime.parse(sale.docDate);
    } catch (_) {}

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primary.withValues(alpha: 0.06) : null,
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
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? primary
                      : Theme.of(context)
                          .colorScheme
                          .outline
                          .withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        sale.docNo,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        docDate != null
                            ? dateFmt.format(docDate)
                            : sale.docDate,
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 12, color: muted),
                        const SizedBox(width: 3),
                        Text(
                          (sale.salesAgent ?? '').isNotEmpty ? sale.salesAgent! : '',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Total: ${amtFmt.format(sale.finalTotal)}',
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                      Spacer(),
                      Text(
                        'O/S: ${amtFmt.format(sale.outstanding)}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Mycolor.secondary),
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
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.75,
      expand: false,
      builder: (_, scrollCtrl) => Material(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                          fontSize: 16, fontWeight: FontWeight.w700)),
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    items: _sortOptions
                        .map((o) =>
                            DropdownMenuItem(value: o.$2, child: Text(o.$1)))
                        .toList(),
                    onChanged: (v) => setState(() => _sortBy = v!),
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
                          onTap: () => setState(() => _sortAsc = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DirectionChip(
                          label: 'Descending',
                          icon: Icons.arrow_downward_rounded,
                          selected: !_sortAsc,
                          onTap: () => setState(() => _sortAsc = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onApply(_sortBy, _sortAsc);
                      },
                      child: const Text('Apply',
                          style: TextStyle(fontWeight: FontWeight.w600)),
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
