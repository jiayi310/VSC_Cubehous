import 'package:flutter/material.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../models/customer.dart';
import '../../models/customer_type.dart';
import '../../models/sales_agent.dart';

// ─────────────────────────────────────────────────────────────────────
// Customer picker page
// ─────────────────────────────────────────────────────────────────────

class CustomerPickerPage extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  const CustomerPickerPage({
    super.key,
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
  });

  @override
  State<CustomerPickerPage> createState() => _CustomerPickerPageState();
}

class _CustomerPickerPageState extends State<CustomerPickerPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Customer> _customers = [];
  bool _loading = true;
  String? _error;
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalCount = 0;
  static const _pageSize = 20;

  // Filter & sort
  String _sortBy = 'CustomerCode';
  bool _sortAsc = true;
  List<int> _filterCustomerTypeIDs = [];
  List<int> _filterSalesAgentIDs = [];
  List<int> _filterPriceCategoryList = [];

  int get _activeFilters =>
      (_sortBy != 'CustomerCode' ? 1 : 0) +
      (!_sortAsc ? 1 : 0) +
      (_filterCustomerTypeIDs.isNotEmpty ? 1 : 0) +
      (_filterSalesAgentIDs.isNotEmpty ? 1 : 0) +
      (_filterPriceCategoryList.isNotEmpty ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _fetch(page: 0);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({required int page}) async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getCustomerList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'pageIndex': page,
          'pageSize': _pageSize,
          'sortBy': _sortBy,
          'isSortByAscending': _sortAsc,
          'searchTerm': _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
          'filterCustomerTypeIdList': _filterCustomerTypeIDs.isEmpty ? null : _filterCustomerTypeIDs,
          'filterSalesAgentIdList': _filterSalesAgentIDs.isEmpty ? null : _filterSalesAgentIDs,
          'filterPriceCategoryList': _filterPriceCategoryList.isEmpty ? null : _filterPriceCategoryList,
        },
      );
      final raw = response as Map<String, dynamic>;
      final data = (raw['data'] as List<dynamic>?)
              ?.map((e) => Customer.fromJson(e as Map<String, dynamic>))
              .toList() ?? [];
      final total = (raw['paginationOpt']?['totalRecord'] as int?) ?? data.length;
      if (mounted) {
        setState(() {
          _customers = data;
          _currentPage = page;
          _totalCount = total;
          _totalPages = _pageSize > 0 ? (total / _pageSize).ceil() : 1;
          if (_totalPages < 1) _totalPages = 1;
          _loading = false;
        });
        if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustPickerFilterSheet(
        sortBy: _sortBy,
        sortAsc: _sortAsc,
        selectedCustomerTypeIDs: _filterCustomerTypeIDs,
        selectedSalesAgentIDs: _filterSalesAgentIDs,
        selectedPriceCategoryList: _filterPriceCategoryList,
        apiKey: widget.apiKey,
        companyGUID: widget.companyGUID,
        userID: widget.userID,
        userSessionID: widget.userSessionID,
        onApply: (sortBy, sortAsc, typeIDs, agentIDs, priceCategories) {
          setState(() {
            _sortBy = sortBy;
            _sortAsc = sortAsc;
            _filterCustomerTypeIDs = typeIDs;
            _filterSalesAgentIDs = agentIDs;
            _filterPriceCategoryList = priceCategories;
          });
          _fetch(page: 0);
        },
        onReset: () {
          setState(() {
            _sortBy = 'CustomerCode';
            _sortAsc = true;
            _filterCustomerTypeIDs = [];
            _filterSalesAgentIDs = [];
            _filterPriceCategoryList = [];
          });
          _fetch(page: 0);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final start = _currentPage * _pageSize + 1;
    final end = ((_currentPage + 1) * _pageSize).clamp(0, _totalCount);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Customer',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
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
                      hintText: 'Search customers...',
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
      body: _loading
          ? const Center(child: DotsLoading())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: () => _fetch(page: 0),
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : _customers.isEmpty
                  ? const Center(child: Text('No customers found'))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            itemCount: _customers.length,
                            itemBuilder: (ctx, i) {
                              final c = _customers[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: primary.withValues(alpha: 0.1),
                                  child: Text(
                                    c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                    style: TextStyle(color: primary, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                title: Text(c.name,
                                    style: const TextStyle(fontWeight: FontWeight.w500)),
                                subtitle: Text(c.customerCode,
                                    style: TextStyle(fontSize: 12, color: primary)),
                                trailing: Icon(Icons.chevron_right,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                                onTap: () => Navigator.pop(context, c),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Center(
                            child: Text(
                              'Showing $start–$end of $_totalCount records',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        ),
                        _CustomerPickerPaginationBar(
                          currentPage: _currentPage,
                          totalPages: _totalPages,
                          isLoading: _loading,
                          primary: primary,
                          onPrev: _currentPage > 0 ? () => _fetch(page: _currentPage - 1) : null,
                          onNext: _currentPage < _totalPages - 1 ? () => _fetch(page: _currentPage + 1) : null,
                        ),
                      ],
                    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Customer picker — Filter & Sort sheet
// ─────────────────────────────────────────────────────────────────────

const _custSortOptions = [
  ('Customer Code', 'CustomerCode'),
  ('Name', 'Name'),
  ('Customer Type', 'CustomerType'),
  ('Sales Agent', 'SalesAgent'),
];

class _CustPickerFilterSheet extends StatefulWidget {
  final String sortBy;
  final bool sortAsc;
  final List<int> selectedCustomerTypeIDs;
  final List<int> selectedSalesAgentIDs;
  final List<int> selectedPriceCategoryList;
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;
  final void Function(
    String sortBy,
    bool sortAsc,
    List<int> customerTypeIDs,
    List<int> salesAgentIDs,
    List<int> priceCategoryList,
  ) onApply;
  final VoidCallback onReset;

  const _CustPickerFilterSheet({
    required this.sortBy,
    required this.sortAsc,
    required this.selectedCustomerTypeIDs,
    required this.selectedSalesAgentIDs,
    required this.selectedPriceCategoryList,
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_CustPickerFilterSheet> createState() => _CustPickerFilterSheetState();
}

class _CustPickerFilterSheetState extends State<_CustPickerFilterSheet> {
  late String _sortBy;
  late bool _sortAsc;
  late Set<int> _selectedCustomerTypeIDs;
  late Set<int> _selectedSalesAgentIDs;
  late Set<int> _selectedPriceCategoryList;

  List<CustomerType> _customerTypes = [];
  List<SalesAgent> _salesAgents = [];
  bool _isLoading = true;
  bool _loadError = false;

  static const _priceCategories = [1, 2, 3, 4, 5, 6];

  @override
  void initState() {
    super.initState();
    _sortBy = widget.sortBy;
    _sortAsc = widget.sortAsc;
    _selectedCustomerTypeIDs = Set.from(widget.selectedCustomerTypeIDs);
    _selectedSalesAgentIDs = Set.from(widget.selectedSalesAgentIDs);
    _selectedPriceCategoryList = Set.from(widget.selectedPriceCategoryList);
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
      final results = await Future.wait([
        BaseClient.post(ApiEndpoints.getCustomerTypeList, body: body),
        BaseClient.post(ApiEndpoints.getSalesAgentList, body: body),
      ]);
      if (!mounted) return;
      setState(() {
        _customerTypes = (results[0] as List<dynamic>)
            .map((e) => CustomerType.fromJson(e as Map<String, dynamic>))
            .toList();
        _salesAgents = (results[1] as List<dynamic>)
            .map((e) => SalesAgent.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; _loadError = true; });
    }
  }

  void _apply() {
    Navigator.pop(context);
    widget.onApply(
      _sortBy, _sortAsc,
      _selectedCustomerTypeIDs.toList(),
      _selectedSalesAgentIDs.toList(),
      _selectedPriceCategoryList.toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
                width: 40, height: 4,
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
                    onPressed: () { Navigator.pop(context); widget.onReset(); },
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
                              Icon(Icons.cloud_off_outlined, size: 40,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                              const SizedBox(height: 8),
                              const Text('Failed to load filter options'),
                              const SizedBox(height: 12),
                              FilledButton(onPressed: _loadOptions, child: const Text('Retry')),
                            ],
                          ),
                        )
                      : ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                          children: [
                            // ── Sort By ──────────────────────────────
                            _filterLabel('Sort By', primary),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _sortBy,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                              items: _custSortOptions
                                  .map((o) => DropdownMenuItem(value: o.$2, child: Text(o.$1)))
                                  .toList(),
                              onChanged: (v) => setState(() => _sortBy = v!),
                            ),
                            const SizedBox(height: 16),

                            // ── Sort Direction ────────────────────────
                            _filterLabel('Sort Direction', primary),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: PickerDirChip(
                                  label: 'Ascending', icon: Icons.arrow_upward_rounded,
                                  selected: _sortAsc,
                                  onTap: () => setState(() => _sortAsc = true),
                                )),
                                const SizedBox(width: 10),
                                Expanded(child: PickerDirChip(
                                  label: 'Descending', icon: Icons.arrow_downward_rounded,
                                  selected: !_sortAsc,
                                  onTap: () => setState(() => _sortAsc = false),
                                )),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // ── Customer Type ─────────────────────────
                            if (_customerTypes.isNotEmpty) ...[
                              _filterLabel('Customer Type', primary),
                              const SizedBox(height: 8),
                              _buildChips(
                                items: _customerTypes
                                    .map((t) => (id: t.customerTypeID, label: t.customerType))
                                    .toList(),
                                selected: _selectedCustomerTypeIDs,
                              ),
                              const SizedBox(height: 20),
                            ],

                            // ── Sales Agent ───────────────────────────
                            if (_salesAgents.isNotEmpty) ...[
                              _filterLabel('Sales Agent', primary),
                              const SizedBox(height: 8),
                              _buildChips(
                                items: _salesAgents
                                    .map((a) => (id: a.salesAgentID ?? 0, label: a.name ?? ''))
                                    .where((a) => a.id > 0 && a.label.isNotEmpty)
                                    .toList(),
                                selected: _selectedSalesAgentIDs,
                              ),
                              const SizedBox(height: 20),
                            ],

                            // ── Price Category ────────────────────────
                            _filterLabel('Price Category', primary),
                            const SizedBox(height: 8),
                            _buildChips(
                              items: _priceCategories.map((c) => (id: c, label: '$c')).toList(),
                              selected: _selectedPriceCategoryList,
                            ),
                            const SizedBox(height: 24),

                            // ── Apply ─────────────────────────────────
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _apply,
                                child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _filterLabel(String text, Color color) => Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
      );

  Widget _buildChips({
    required List<({int id, String label})> items,
    required Set<int> selected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: items.map((item) {
        final isSel = selected.contains(item.id);
        return FilterChip(
          label: Text(item.label, style: const TextStyle(fontSize: 12)),
          selected: isSel,
          onSelected: (v) => setState(() {
            if (v) { selected.add(item.id); } else { selected.remove(item.id); }
          }),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Shared direction chip (used by customer and sales agent pickers)
// ─────────────────────────────────────────────────────────────────────

class PickerDirChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const PickerDirChip({
    super.key,
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

// ─────────────────────────────────────────────────────────────────────
// Pagination bar
// ─────────────────────────────────────────────────────────────────────

class _CustomerPickerPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final Color primary;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _CustomerPickerPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.isLoading,
    required this.primary,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: isLoading ? null : onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            style: IconButton.styleFrom(
              foregroundColor: onPrev != null ? primary : null,
            ),
          ),
          Text(
            'Page ${currentPage + 1} of $totalPages',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          IconButton(
            onPressed: isLoading ? null : onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            style: IconButton.styleFrom(
              foregroundColor: onNext != null ? primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
