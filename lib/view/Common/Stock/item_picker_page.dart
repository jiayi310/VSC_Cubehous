import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/direction_chip.dart';
import '../../../common/dots_loading.dart';
import '../../../common/pagination_bar.dart';
import '../../../models/stock.dart';
import '../../../models/stock_detail.dart';
import '../../../models/stock_filter.dart';

const _sortOptions = [
  ('Stock Code', 'StockCode'),
  ('Description', 'Description'),
  ('Description 2', 'Desc2'),
  ('UOM', 'BaseUOM'),
  ('Price', 'BaseUOMPrice1'),
  ('Group', 'StockGroupID'),
  ('Type', 'StockTypeID'),
  ('Category', 'StockCategoryID'),
];

// ─────────────────────────────────────────────────────────────────────
// Item picker page
// ─────────────────────────────────────────────────────────────────────

class ItemPickerPage extends StatefulWidget {
  final String module;
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  /// When provided, tapping an item shows a qty/UOM sheet and calls this
  /// callback — the page stays open so the user can keep adding items.
  /// When null, tapping an item pops the page with the selected [Stock].
  final void Function(Stock stock, String uom, double qty)? onItemAdded;

  const ItemPickerPage({
    super.key,
    required this.module,
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
    this.onItemAdded,
  });

  @override
  State<ItemPickerPage> createState() => _ItemPickerPageState();
}

class _ItemPickerPageState extends State<ItemPickerPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _qtyFmt = NumberFormat('#,##0.##');
  List<Stock> _items = [];
  bool _loading = true;
  bool _scanning = false;
  bool _scanSearching = false;
  String? _error;
  int _currentPage = 0;
  int _totalCount = 0;
  int _totalPages = 1;
  static const _pageSize = 20;

  // Sort state
  String _sortBy = 'StockCode';
  bool _sortAsc = true;

  // Filter state
  List<StockGroup> _groups = [];
  List<StockType> _types = [];
  List<StockCategory> _categories = [];
  List<int> _selectedGroupIDs = [];
  List<int> _selectedTypeIDs = [];
  List<int> _selectedCategoryIDs = [];
  int get _activeFilters =>
      (_sortBy != 'StockCode' ? 1 : 0) +
      (!_sortAsc ? 1 : 0) +
      _selectedGroupIDs.length +
      _selectedTypeIDs.length +
      _selectedCategoryIDs.length;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _fetch(page: 0);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Qty / UOM sheet (used when onItemAdded is provided) ──────────
  Future<void> _showDetailsSheet(Stock stock) async {
    // Pre-load UOM list
    List<String> uomList = [stock.baseUOM];
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getStock,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'stockID': stock.stockID,
        },
      );
      final detail = StockDetail.fromJson(json as Map<String, dynamic>);
      if (detail.stockUOMDtoList.isNotEmpty) {
        uomList = detail.stockUOMDtoList.map((u) => u.uom).toList();
      }
    } catch (_) {}
    if (!mounted) return;

    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final qtyController = TextEditingController(text: '1');
    double qty = 1.0;
    String selectedUom = uomList.contains(stock.baseUOM)
        ? stock.baseUOM
        : uomList.first;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(stock.stockCode,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primary)),
                const SizedBox(height: 2),
                Text(stock.description,
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.65))),
                const SizedBox(height: 20),
                // ── UOM chips ──────────────────────────────────────
                Text('UOM',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: uomList.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final u = uomList[i];
                      final selected = u == selectedUom;
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedUom = u),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? primary
                                : primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: selected
                                    ? primary
                                    : primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(u,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected ? Colors.white : primary)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // ── Qty stepper ────────────────────────────────────
                Text('Quantity',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _stepBtn(Icons.remove_rounded, () {
                      final v = double.tryParse(qtyController.text) ?? 1.0;
                      final newV = (v - 1.0).clamp(1.0, double.infinity);
                      qtyController.text = _qtyFmt.format(newV);
                      setSheetState(() => qty = newV);
                    }, primary, cs),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.]')),
                        ],
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                BorderSide(color: primary, width: 1.5),
                          ),
                        ),
                        onChanged: (v) {
                          final parsed = double.tryParse(v);
                          if (parsed != null) {
                            qty = parsed.clamp(1.0, double.infinity);
                          }
                        },
                        onEditingComplete: () {
                          final v =
                              double.tryParse(qtyController.text) ?? 1.0;
                          qty = v.clamp(1.0, double.infinity);
                          qtyController.text = _qtyFmt.format(qty);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    _stepBtn(Icons.add_rounded, () {
                      final v = double.tryParse(qtyController.text) ?? 1.0;
                      final newV = v + 1.0;
                      qtyController.text = _qtyFmt.format(newV);
                      setSheetState(() => qty = newV);
                    }, primary, cs),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Add',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final finalQty =
          (double.tryParse(qtyController.text) ?? qty)
              .clamp(1.0, double.infinity);
      widget.onItemAdded!(stock, selectedUom, finalQty);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${stock.stockCode} added'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ));
    }
  }

  Widget _stepBtn(
      IconData icon, VoidCallback onTap, Color primary, ColorScheme cs) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: primary, size: 20),
      ),
    );
  }

  Future<void> _loadFilterOptions() async {
    try {
      final body = {
        'apiKey': widget.apiKey,
        'companyGUID': widget.companyGUID,
        'userID': widget.userID,
        'userSessionID': widget.userSessionID,
      };
      final results = await Future.wait([
        BaseClient.post(ApiEndpoints.getStockGroupList, body: body),
        BaseClient.post(ApiEndpoints.getStockTypeList, body: body),
        BaseClient.post(ApiEndpoints.getStockCategoryList, body: body),
      ]);
      if (!mounted) return;
      setState(() {
        _groups = (results[0] as List<dynamic>)
            .map((e) => StockGroup.fromJson(e as Map<String, dynamic>))
            .toList();
        _types = (results[1] as List<dynamic>)
            .map((e) => StockType.fromJson(e as Map<String, dynamic>))
            .toList();
        _categories = (results[2] as List<dynamic>)
            .map((e) => StockCategory.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> _fetch({required int page}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getStockList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'pageIndex': page,
          'pageSize': _pageSize,
          'isActiveOnly': true,
          'sortBy': _sortBy,
          'isSortByAscending': _sortAsc,
          'searchTerm': _searchCtrl.text.trim().isEmpty
              ? null
              : _searchCtrl.text.trim(),
          'filterGroupIDs': _selectedGroupIDs,
          'filterTypeIDs': _selectedTypeIDs,
          'filterCategoryIDs': _selectedCategoryIDs,
        },
      );
      final result = StockResponse.fromJson(response as Map<String, dynamic>);
      final data = result.data ?? [];
      final totalRecord = result.pagination?.totalRecord ?? data.length;
      final pageSize = result.pagination?.pageSize ?? _pageSize;
      setState(() {
        _items = data;
        _currentPage = page;
        _totalCount = totalRecord;
        _totalPages = pageSize > 0 ? (totalRecord / pageSize).ceil() : 1;
        if (_totalPages < 1) _totalPages = 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _showFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemPickerFilterSheet(
        sortBy: _sortBy,
        sortAsc: _sortAsc,
        groups: _groups,
        types: _types,
        categories: _categories,
        selectedGroupIDs: List.of(_selectedGroupIDs),
        selectedTypeIDs: List.of(_selectedTypeIDs),
        selectedCategoryIDs: List.of(_selectedCategoryIDs),
        onApply: (sortBy, sortAsc, gIDs, tIDs, cIDs) {
          setState(() {
            _sortBy = sortBy;
            _sortAsc = sortAsc;
            _selectedGroupIDs = gIDs;
            _selectedTypeIDs = tIDs;
            _selectedCategoryIDs = cIDs;
          });
          _fetch(page: 0);
        },
      ),
    );
  }

  Future<void> _onBarcodeDetected(String barcode) async {
    if (_scanSearching) return;
    setState(() {
      _scanning = false;
      _scanSearching = true;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getStockByBarcode,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'search': barcode,
        },
      );
      Stock? found;
      if (response is List && response.isNotEmpty) {
        found = Stock.fromJson(response.first as Map<String, dynamic>);
      } else if (response is Map<String, dynamic>) {
        found = Stock.fromJson(response);
      }
      if (found != null && mounted) {
        Navigator.pop(context, found);
      } else if (mounted) {
        _showNotFound(barcode);
      }
    } catch (e) {
      if (mounted) _showNotFound(barcode);
    } finally {
      if (mounted) setState(() => _scanSearching = false);
    }
  }

  void _showNotFound(String barcode) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('No item found for "$barcode"'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Item',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_outlined),
            tooltip: 'Scan Barcode',
            onPressed: () => setState(() => _scanning = true),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _fetch(page: 0),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search items...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _fetch(page: 0);
                              })
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
                const SizedBox(width: 8),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showFilter,
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
                            color: Color(0xFFFF9700),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$_activeFilters',
                              style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
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
      body: Stack(
        children: [
          _buildContent(primary),
          if (_scanning)
            ScannerOverlay(
              onDetected: _onBarcodeDetected,
              onClose: () => setState(() => _scanning = false),
            ),
          if (_scanSearching)
            Container(
              color: Colors.black45,
              child: const Center(child: DotsLoading()),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(Color primary) {
    if (_loading) return const Center(child: DotsLoading());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error'),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () => _fetch(page: 0), child: const Text('Retry')),
          ],
        ),
      );
    }
    final labelColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    final start = _currentPage * _pageSize + 1;
    final end = ((_currentPage + 1) * _pageSize).clamp(0, _totalCount);
    return Column(
      children: [
        if (_items.isEmpty)
          const Expanded(child: Center(child: Text('No items found')))
        else
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              itemCount: _items.length + 1,
              itemBuilder: (ctx, i) {
                if (i == _items.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 0, 24),
                    child: Center(
                      child: Text(
                        'Showing $start–$end of $_totalCount item${_totalCount == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 12, color: labelColor),
                      ),
                    ),
                  );
                }
                final s = _items[i];
                return ListTile(
                  leading: s.image != null && s.image!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            base64Decode(s.image!.contains(',')
                                ? s.image!.split(',').last
                                : s.image!),
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => _itemIcon(primary),
                          ),
                        )
                      : _itemIcon(primary),
                  title: Text(s.stockCode,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary)),
                  subtitle: Text(s.description,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(s.baseUOM,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5))),
                      Text('RM ${s.baseUOMPrice1.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primary)),
                    ],
                  ),
                  onTap: () => widget.onItemAdded != null
                      ? _showDetailsSheet(s)
                      : Navigator.pop(context, s),
                );
              },
            ),
          ),
        PaginationBar(
          currentPage: _currentPage,
          totalPages: _totalPages,
          isLoading: _loading,
          primary: primary,
          onPrev: _currentPage > 0
              ? () => _fetch(page: _currentPage - 1)
              : null,
          onNext: _currentPage < _totalPages - 1
              ? () => _fetch(page: _currentPage + 1)
              : null,
        ),
      ],
    );
  }

  Widget _itemIcon(Color primary) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.inventory_2_outlined,
            size: 22, color: primary.withValues(alpha: 0.4)),
      );
}

// ─────────────────────────────────────────────────────────────────────
// Item picker filter & sort sheet
// ─────────────────────────────────────────────────────────────────────

class _ItemPickerFilterSheet extends StatefulWidget {
  final String sortBy;
  final bool sortAsc;
  final List<StockGroup> groups;
  final List<StockType> types;
  final List<StockCategory> categories;
  final List<int> selectedGroupIDs;
  final List<int> selectedTypeIDs;
  final List<int> selectedCategoryIDs;
  final void Function(
    String sortBy,
    bool sortAsc,
    List<int> gIDs,
    List<int> tIDs,
    List<int> cIDs,
  ) onApply;

  const _ItemPickerFilterSheet({
    required this.sortBy,
    required this.sortAsc,
    required this.groups,
    required this.types,
    required this.categories,
    required this.selectedGroupIDs,
    required this.selectedTypeIDs,
    required this.selectedCategoryIDs,
    required this.onApply,
  });

  @override
  State<_ItemPickerFilterSheet> createState() => _ItemPickerFilterSheetState();
}

class _ItemPickerFilterSheetState extends State<_ItemPickerFilterSheet> {
  late String _sortBy;
  late bool _sortAsc;
  late List<int> _groupIDs;
  late List<int> _typeIDs;
  late List<int> _categoryIDs;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.sortBy;
    _sortAsc = widget.sortAsc;
    _groupIDs = List.of(widget.selectedGroupIDs);
    _typeIDs = List.of(widget.selectedTypeIDs);
    _categoryIDs = List.of(widget.selectedCategoryIDs);
  }

  void _toggle(List<int> list, int id) {
    setState(() {
      if (list.contains(id)) {
        list.remove(id);
      } else {
        list.add(id);
      }
    });
  }

  void _clear() => setState(() {
        _sortBy = 'StockCode';
        _sortAsc = true;
        _groupIDs.clear();
        _typeIDs.clear();
        _categoryIDs.clear();
      });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final hasAny = _sortBy != 'StockCode' ||
        !_sortAsc ||
        _groupIDs.isNotEmpty ||
        _typeIDs.isNotEmpty ||
        _categoryIDs.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Text('Filter & Sort',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface)),
                  const Spacer(),
                  if (hasAny)
                    TextButton(onPressed: _clear, child: const Text('Reset')),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  // ── Sort By ──────────────────────────────────────
                  _filterLabel('Sort By', cs),
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

                  // ── Sort Direction ────────────────────────────────
                  _filterLabel('Sort Direction', cs),
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

                  // ── Group ─────────────────────────────────────────
                  if (widget.groups.isNotEmpty) ...[
                    _filterLabel('Group', cs),
                    _chipWrap(widget.groups, (g) => g.id,
                        (g) => g.description.isNotEmpty ? g.description : g.shortCode,
                        _groupIDs, primary, cs),
                    const SizedBox(height: 16),
                  ],

                  // ── Type ──────────────────────────────────────────
                  if (widget.types.isNotEmpty) ...[
                    _filterLabel('Type', cs),
                    _chipWrap(widget.types, (t) => t.id,
                        (t) => t.description.isNotEmpty ? t.description : t.shortCode,
                        _typeIDs, primary, cs),
                    const SizedBox(height: 16),
                  ],

                  // ── Category ──────────────────────────────────────
                  if (widget.categories.isNotEmpty) ...[
                    _filterLabel('Category', cs),
                    _chipWrap(widget.categories, (c) => c.id,
                        (c) => c.description.isNotEmpty ? c.description : c.shortCode,
                        _categoryIDs, primary, cs),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    widget.onApply(_sortBy, _sortAsc, _groupIDs, _typeIDs, _categoryIDs);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Apply',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterLabel(String label, ColorScheme cs) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: cs.onSurface.withValues(alpha: 0.45)),
        ),
      );

  Widget _chipWrap<T>(
    List<T> items,
    int Function(T) getId,
    String Function(T) getLabel,
    List<int> selected,
    Color primary,
    ColorScheme cs,
  ) =>
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final id = getId(item);
          final isSelected = selected.contains(id);
          return GestureDetector(
            onTap: () => _toggle(selected, id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(20),
                border: isSelected
                    ? null
                    : Border.all(color: cs.outline.withValues(alpha: 0.3)),
              ),
              child: Text(
                getLabel(item),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : cs.onSurface),
              ),
            ),
          );
        }).toList(),
      );
}

// ─────────────────────────────────────────────────────────────────────
// Direction chip
// ─────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────
// Scanner overlay (shared — also imported by quotation_form.dart)
// ─────────────────────────────────────────────────────────────────────

class ScannerOverlay extends StatefulWidget {
  final void Function(String barcode) onDetected;
  final VoidCallback onClose;

  const ScannerOverlay({super.key, required this.onDetected, required this.onClose});

  @override
  State<ScannerOverlay> createState() => _ScannerOverlayState();
}

class _ScannerOverlayState extends State<ScannerOverlay> {
  final MobileScannerController _controller = MobileScannerController();
  bool _detected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_detected) return;
              final barcode = capture.barcodes.firstOrNull?.rawValue;
              if (barcode != null && barcode.isNotEmpty) {
                _detected = true;
                widget.onDetected(barcode);
              }
            },
          ),
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: widget.onClose,
            ),
          ),
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Text(
              'Point camera at barcode',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
