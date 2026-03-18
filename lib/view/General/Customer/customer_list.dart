import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';
import '../../../models/customer.dart';
import '../../../models/customer_type.dart';
import '../../../models/sales_agent.dart';
import 'customer_detail.dart';
import 'customer_form.dart';

const _sortOptions = [
  ('Customer Code', 'CustomerCode'),
  ('Name', 'Name'),
  ('Customer Type', 'CustomerType'),
  ('Sales Agent', 'SalesAgent'),
];

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({super.key});

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  // Data
  List<Customer> _customers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  // Pagination
  int _currentPage = 0;
  int _totalCount = 0;
  static const _pageSize = 20;
  bool get _hasMore => _customers.length < _totalCount;

  // Search, sort & filters
  final _searchController = TextEditingController();
  String _searchQuery = '';
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
    await _fetchCustomers(reset: true);
  }

  Future<void> _fetchCustomers({required bool reset}) async {
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
        ApiEndpoints.getCustomerList,
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
          'filterCustomerTypeIdList': _filterCustomerTypeIDs.isEmpty ? null : _filterCustomerTypeIDs,
          'filterSalesAgentIdList': _filterSalesAgentIDs.isEmpty ? null : _filterSalesAgentIDs,
          'filterPriceCategoryList': _filterPriceCategoryList.isEmpty ? null : _filterPriceCategoryList,
        },
      );

      final result =
          CustomerResponse.fromJson(response as Map<String, dynamic>);
      final newItems = result.data ?? [];

      setState(() {
        if (reset) {
          _customers = newItems;
        } else {
          _customers = [..._customers, ...newItems];
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
    await _fetchCustomers(reset: false);
  }

  Future<void> _onRefresh() => _fetchCustomers(reset: true);

  void _onSearchSubmit(String value) {
    setState(() => _searchQuery = value.trim());
    _fetchCustomers(reset: true);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _fetchCustomers(reset: true);
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        sortBy: _sortBy,
        sortAsc: _sortAsc,
        selectedCustomerTypeIDs: _filterCustomerTypeIDs,
        selectedSalesAgentIDs: _filterSalesAgentIDs,
        selectedPriceCategoryList: _filterPriceCategoryList,
        apiKey: _apiKey,
        companyGUID: _companyGUID,
        userID: _userID,
        userSessionID: _userSessionID,
        onApply: (sortBy, sortAsc, customerTypeIDs, salesAgentIDs, priceCategoryList) {
          setState(() {
            _sortBy = sortBy;
            _sortAsc = sortAsc;
            _filterCustomerTypeIDs = customerTypeIDs;
            _filterSalesAgentIDs = salesAgentIDs;
            _filterPriceCategoryList = priceCategoryList;
          });
          _fetchCustomers(reset: true);
        },
        onReset: () {
          setState(() {
            _sortBy = 'CustomerCode';
            _sortAsc = true;
            _filterCustomerTypeIDs = [];
            _filterSalesAgentIDs = [];
            _filterPriceCategoryList = [];
          });
          _fetchCustomers(reset: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'New Customer',
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerFormPage(),
                ),
              );
              if (created == true) _fetchCustomers(reset: true);
            },
          ),
        ],
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
                      hintText: 'Search customers...',
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
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
    if (_customers.isEmpty) {
      return _buildEmpty();
    }
    return _buildList();
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _customers.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _customers.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: DotsLoading()),
            );
          }
          return _CustomerTile(
            customer: _customers[i],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerDetailPage(
                    customerCode: _customers[i].customerCode,
                  ),
                ),
              );
            },
            onEdit: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CustomerFormPage(customer: _customers[i]),
                ),
              );
              if (updated == true) _fetchCustomers(reset: true);
            },
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
            const Text('Failed to load customers',
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
              onPressed: () => _fetchCustomers(reset: true),
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
            Icon(Icons.people_outline,
                size: 52,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No customers found',
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
// Customer tile with slide-to-edit
// ─────────────────────────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _CustomerTile({
    required this.customer,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Slidable(
      key: ValueKey(customer.customerID),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.22,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Edit',
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: InkWell(
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
              _CustomerAvatar(name: customer.name),
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
                          customer.customerCode,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primary,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const Spacer(),
                        if (customer.customerType.isNotEmpty)
                          _TypeBadge(label: customer.customerType),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Name
                    Text(
                      customer.name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 3),

                    // Phone
                    _IconRow(
                        icon: Icons.phone_outlined,
                        text: customer.phone1 ?? '-',
                      ),

                    // Sales agent
                    _IconRow(
                        icon: Icons.support_agent_outlined,
                        text: customer.salesAgent.isNotEmpty ? customer.salesAgent : '-',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Avatar circle with initials
// ─────────────────────────────────────────────────────────────────────

class _CustomerAvatar extends StatelessWidget {
  final String name;
  const _CustomerAvatar({required this.name});

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
    final color = _palette[name.codeUnitAt(0) % _palette.length];
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
// Customer type badge
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

  const _FilterSheet({
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
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
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

                            // ── Customer Type ─────────────────────────
                            if (_customerTypes.isNotEmpty) ...[
                              _label('Customer Type', primary),
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
                              _label('Sales Agent', primary),
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
                            _label('Price Category', primary),
                            const SizedBox(height: 8),
                            _buildChips(
                              items: _priceCategories
                                  .map((c) => (id: c, label: '$c'))
                                  .toList(),
                              selected: _selectedPriceCategoryList,
                            ),
                            const SizedBox(height: 24),

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
            if (v) { selected.add(item.id); }
            else { selected.remove(item.id); }
          }),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
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
