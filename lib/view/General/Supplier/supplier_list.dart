import 'package:flutter/material.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';
import '../../../models/suppplier.dart';
import 'supplier_detail.dart';

const _sortOptions = [
  ('Supplier Code', 'SupplierCode'),
  ('Name', 'Name'),
  ('Supplier Type', 'SupplierType'),
];

class SupplierListPage extends StatefulWidget {
  const SupplierListPage({super.key});

  @override
  State<SupplierListPage> createState() => _SupplierListPageState();
}

class _SupplierListPageState extends State<SupplierListPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  // Data
  List<Supplier> _suppliers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  // Pagination
  int _currentPage = 0;
  int _totalCount = 0;
  static const _pageSize = 20;
  bool get _hasMore => _suppliers.length < _totalCount;

  // Search, sort & filters
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'SupplierCode';
  bool _sortAsc = true;
  List<int> _filterSupplierTypeIDs = [];

  int get _activeFilters =>
      (_sortBy != 'SupplierCode' ? 1 : 0) +
      (!_sortAsc ? 1 : 0) +
      (_filterSupplierTypeIDs.isNotEmpty ? 1 : 0);

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _init() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    await _fetchSuppliers(reset: true);
  }

  Future<void> _fetchSuppliers({required bool reset}) async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 0;
      });
    }

    try {
      final response = await BaseClient.post(
        ApiEndpoints.getSupplierList,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'pageIndex': reset ? 0 : _currentPage,
          'pageSize': _pageSize,
          'sortBy': _sortBy,
          'isSortByAscending': _sortAsc,
          'searchTerm': _searchQuery.isEmpty ? null : _searchQuery,
          'filterSupplierTypeIdList': _filterSupplierTypeIDs.isEmpty ? null : _filterSupplierTypeIDs,
        },
      );

      final result = SupplierResponse.fromJson(response as Map<String, dynamic>);
      final newItems = result.data ?? [];

      setState(() {
        if (reset) {
          _suppliers = newItems;
        } else {
          _suppliers = [..._suppliers, ...newItems];
        }
        _totalCount = result.pagination?.totalRecord ?? newItems.length;
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
    await _fetchSuppliers(reset: false);
  }

  Future<void> _onRefresh() => _fetchSuppliers(reset: true);

  void _onSearchSubmit(String value) {
    setState(() => _searchQuery = value.trim());
    _fetchSuppliers(reset: true);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _fetchSuppliers(reset: true);
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        sortBy: _sortBy,
        sortAsc: _sortAsc,
        selectedSupplierTypeIDs: _filterSupplierTypeIDs,
        apiKey: _apiKey,
        companyGUID: _companyGUID,
        userID: _userID,
        userSessionID: _userSessionID,
        onApply: (sortBy, sortAsc, supplierTypeIDs) {
          setState(() {
            _sortBy = sortBy;
            _sortAsc = sortAsc;
            _filterSupplierTypeIDs = supplierTypeIDs;
          });
          _fetchSuppliers(reset: true);
        },
        onReset: () {
          setState(() {
            _sortBy = 'SupplierCode';
            _sortAsc = true;
            _filterSupplierTypeIDs = [];
          });
          _fetchSuppliers(reset: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suppliers',
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
                      hintText: 'Search suppliers...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: _clearSearch,
                            )
                          : null,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
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
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showSortSheet,
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: DotsLoading());
    }
    if (_error != null) {
      return _buildError();
    }
    if (_suppliers.isEmpty) {
      return _buildEmpty();
    }
    return _buildList();
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _suppliers.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _suppliers.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: DotsLoading()),
            );
          }
          return _SupplierTile(
            supplier: _suppliers[i],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SupplierDetailPage(supplier: _suppliers[i]),
              ),
            ),
          );
        },
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
            const Text('Failed to load suppliers',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _fetchSuppliers(reset: true),
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
            Icon(Icons.store_outlined,
                size: 52,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No suppliers found',
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
// Supplier tile (view-only)
// ─────────────────────────────────────────────────────────────────────

class _SupplierTile extends StatelessWidget {
  final Supplier supplier;
  final VoidCallback onTap;

  const _SupplierTile({required this.supplier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final name = supplier.name ?? '';

    return InkWell(
      onTap: onTap,
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            _SupplierAvatar(name: name),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Code row with type badge on the right
                  Row(
                    children: [
                      Text(
                        supplier.supplierCode ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),
                      if ((supplier.supplierType?.description ?? '').isNotEmpty)
                        _TypeBadge(
                            label: supplier.supplierType!.description!),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Name
                  Text(
                    name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 3),

                  // Phone
                  _IconRow(
                    icon: Icons.phone_outlined,
                    text: supplier.phone1 ?? '-',
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
// Avatar circle with initials
// ─────────────────────────────────────────────────────────────────────

class _SupplierAvatar extends StatelessWidget {
  final String name;
  const _SupplierAvatar({required this.name});

  static const _palette = [
    Color(0xFF5C6BC0),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
    Color(0xFF29B6F6),
    Color(0xFFFF7043),
    Color(0xFF66BB6A),
    Color(0xFFEC407A),
  ];

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final color = name.isNotEmpty
        ? _palette[name.codeUnitAt(0) % _palette.length]
        : _palette[0];
    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Supplier type badge
// ─────────────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String label;
  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Icon + text row
// ─────────────────────────────────────────────────────────────────────

class _IconRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.45);
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: muted),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Filter & Sort bottom sheet
// ─────────────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String sortBy;
  final bool sortAsc;
  final List<int> selectedSupplierTypeIDs;
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;
  final void Function(String sortBy, bool sortAsc, List<int> supplierTypeIDs) onApply;
  final VoidCallback onReset;

  const _FilterSheet({
    required this.sortBy,
    required this.sortAsc,
    required this.selectedSupplierTypeIDs,
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _sortBy;
  late bool _sortAsc;
  late Set<int> _selectedSupplierTypeIDs;

  List<SupplierType> _supplierTypes = [];
  bool _isLoading = true;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.sortBy;
    _sortAsc = widget.sortAsc;
    _selectedSupplierTypeIDs = Set.from(widget.selectedSupplierTypeIDs);
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() { _isLoading = true; _loadError = false; });
    try {
      final body = {
        'apiKey': widget.apiKey,
        'companyGUID': widget.companyGUID,
        'userID': widget.userID.toString(),
        'userSessionID': widget.userSessionID,
      };
      final result = await BaseClient.post(ApiEndpoints.getSupplierTypeList, body: body);
      if (!mounted) return;
      setState(() {
        _supplierTypes = (result as List<dynamic>)
            .map((e) => SupplierType.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _loadError = true; });
    }
  }

  void _apply() {
    Navigator.pop(context);
    widget.onApply(_sortBy, _sortAsc, _selectedSupplierTypeIDs.toList());
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
              child: Row(
                children: [
                  const Text('Filter & Sort',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
              child: _isLoading
                  ? const Center(child: DotsLoading())
                  : _loadError
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.cloud_off_outlined,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                              const SizedBox(height: 8),
                              const Text('Failed to load filter options'),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _loadOptions,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                          children: [
                            // ── Sort By ──────────────────────────────
                            _label('Sort By', primary),
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
                                  .map((o) => DropdownMenuItem(value: o.$2, child: Text(o.$1)))
                                  .toList(),
                              onChanged: (v) => setState(() => _sortBy = v!),
                            ),
                            const SizedBox(height: 16),

                            // ── Sort Direction ────────────────────────
                            _label('Sort Direction', primary),
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
                            const SizedBox(height: 20),

                            // ── Supplier Type ─────────────────────────
                            if (_supplierTypes.isNotEmpty) ...[
                              _label('Supplier Type', primary),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: _supplierTypes.map((t) {
                                  final isSel = _selectedSupplierTypeIDs.contains(t.supplierTypeID);
                                  return FilterChip(
                                    label: Text(t.description ?? '', style: const TextStyle(fontSize: 12)),
                                    selected: isSel,
                                    onSelected: (v) => setState(() {
                                      if (v) { _selectedSupplierTypeIDs.add(t.supplierTypeID); }
                                      else { _selectedSupplierTypeIDs.remove(t.supplierTypeID); }
                                    }),
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 20),
                            ],

                            // ── Apply ─────────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _apply,
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

  Widget _label(String text, Color color) => Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
      );
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
              color: selected
                  ? primary
                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
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
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? primary : null)),
          ],
        ),
      ),
    );
  }
}
