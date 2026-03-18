import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../models/stock.dart';
import '../../models/stock_filter.dart';

// ─────────────────────────────────────────────────────────────────────
// Item picker page
// ─────────────────────────────────────────────────────────────────────

class ItemPickerPage extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  const ItemPickerPage({
    super.key,
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
  });

  @override
  State<ItemPickerPage> createState() => _ItemPickerPageState();
}

class _ItemPickerPageState extends State<ItemPickerPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Stock> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _scanning = false;
  bool _scanSearching = false;
  String? _error;
  int _page = 0;
  int _total = 0;
  static const _pageSize = 20;
  bool get _hasMore => _items.length < _total;

  // Filter state
  List<StockGroup> _groups = [];
  List<StockType> _types = [];
  List<StockCategory> _categories = [];
  List<int> _selectedGroupIDs = [];
  List<int> _selectedTypeIDs = [];
  List<int> _selectedCategoryIDs = [];
  int get _activeFilters =>
      _selectedGroupIDs.length +
      _selectedTypeIDs.length +
      _selectedCategoryIDs.length;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadFilterOptions();
    _fetch(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetch({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 0;
      });
    }
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getStockList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'pageIndex': reset ? 0 : _page,
          'pageSize': _pageSize,
          'isActiveOnly': true,
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
      final total = result.pagination?.totalRecord ?? data.length;
      setState(() {
        _items = reset ? data : [..._items, ...data];
        _total = total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _page++;
    });
    await _fetch(reset: false);
  }

  void _showFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemPickerFilterSheet(
        groups: _groups,
        types: _types,
        categories: _categories,
        selectedGroupIDs: List.of(_selectedGroupIDs),
        selectedTypeIDs: List.of(_selectedTypeIDs),
        selectedCategoryIDs: List.of(_selectedCategoryIDs),
        onApply: (gIDs, tIDs, cIDs) {
          setState(() {
            _selectedGroupIDs = gIDs;
            _selectedTypeIDs = tIDs;
            _selectedCategoryIDs = cIDs;
          });
          _fetch(reset: true);
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
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune_outlined),
                tooltip: 'Filter',
                onPressed: _showFilter,
              ),
              if (_activeFilters > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF9700),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$_activeFilters',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _fetch(reset: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search items...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _fetch(reset: true);
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
        ),
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: DotsLoading())
              : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Error: $_error'),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: () => _fetch(reset: true),
                              child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _items.isEmpty
                      ? const Center(child: Text('No items found'))
                      : ListView.builder(
                          controller: _scrollCtrl,
                          itemCount: _items.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: DotsLoading()),
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
                                        errorBuilder: (_, __, ___) =>
                                            _itemIcon(primary),
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
                                  Text(
                                      'RM ${s.baseUOMPrice1.toStringAsFixed(2)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: primary)),
                                ],
                              ),
                              onTap: () => Navigator.pop(context, s),
                            );
                          },
                        ),

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
// Item picker filter sheet
// ─────────────────────────────────────────────────────────────────────

class _ItemPickerFilterSheet extends StatefulWidget {
  final List<StockGroup> groups;
  final List<StockType> types;
  final List<StockCategory> categories;
  final List<int> selectedGroupIDs;
  final List<int> selectedTypeIDs;
  final List<int> selectedCategoryIDs;
  final void Function(List<int> gIDs, List<int> tIDs, List<int> cIDs) onApply;

  const _ItemPickerFilterSheet({
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
  late List<int> _groupIDs;
  late List<int> _typeIDs;
  late List<int> _categoryIDs;

  @override
  void initState() {
    super.initState();
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
        _groupIDs.clear();
        _typeIDs.clear();
        _categoryIDs.clear();
      });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final hasAny = _groupIDs.isNotEmpty ||
        _typeIDs.isNotEmpty ||
        _categoryIDs.isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
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
                  Text('Filter Items',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface)),
                  const Spacer(),
                  if (hasAny)
                    TextButton(
                        onPressed: _clear,
                        child: const Text('Clear All')),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (widget.groups.isNotEmpty) ...[
                    _filterLabel('Group', cs),
                    _chipWrap(widget.groups, (g) => g.id,
                        (g) => g.description.isNotEmpty ? g.description : g.shortCode,
                        _groupIDs, primary, cs),
                    const SizedBox(height: 16),
                  ],
                  if (widget.types.isNotEmpty) ...[
                    _filterLabel('Type', cs),
                    _chipWrap(widget.types, (t) => t.id,
                        (t) => t.description.isNotEmpty ? t.description : t.shortCode,
                        _typeIDs, primary, cs),
                    const SizedBox(height: 16),
                  ],
                  if (widget.categories.isNotEmpty) ...[
                    _filterLabel('Category', cs),
                    _chipWrap(widget.categories, (c) => c.id,
                        (c) => c.description.isNotEmpty ? c.description : c.shortCode,
                        _categoryIDs, primary, cs),
                    const SizedBox(height: 16),
                  ],
                  if (widget.groups.isEmpty && widget.types.isEmpty && widget.categories.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No filter options available'),
                      ),
                    ),
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
                    widget.onApply(_groupIDs, _typeIDs, _categoryIDs);
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    hasAny ? 'Apply Filter' : 'Apply',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
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
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? Colors.white : cs.onSurface),
              ),
            ),
          );
        }).toList(),
      );
}

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
