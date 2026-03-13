import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../common/session_manager.dart';
import '../../models/Quotation.dart';
import 'quotation_detail.dart';
import 'quotation_form.dart';

const _sortOptions = [
  ('Doc No', 'DocNo'),
  ('Doc Date', 'DocDate'),
  ('Customer', 'CustomerName'),
  ('Total', 'FinalTotal'),
];

class QuotationListPage extends StatefulWidget {
  const QuotationListPage({super.key});

  @override
  State<QuotationListPage> createState() => _QuotationListPageState();
}

class _QuotationListPageState extends State<QuotationListPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  // Data
  List<QuotationListItem> _quotations = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  // Pagination
  int _currentPage = 0;
  int _totalCount = 0;
  static const _pageSize = 20;
  bool get _hasMore => _quotations.length < _totalCount;

  // Search & sort
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'DocNo';
  bool _sortAsc = true;

  // Date filter
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _amtFmt = NumberFormat('#,##0.00');

  final _scrollController = ScrollController();

  int get _activeFilters =>
      (_sortBy != 'DocNo' ? 1 : 0) + (!_sortAsc ? 1 : 0);

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
    await _fetchQuotations(reset: true);
  }

  Future<void> _fetchQuotations({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 0;
      });
    }
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getQuotationList,
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
          'sortBy': _sortBy,
          'isSortByAscending': _sortAsc,
          'searchTerm': _searchQuery.isEmpty ? null : _searchQuery,
        },
      );

      final result =
          QuotationResponse.fromJson(response as Map<String, dynamic>);
      final newItems = result.data ?? [];

      setState(() {
        if (reset) {
          _quotations = newItems;
        } else {
          _quotations = [..._quotations, ...newItems];
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
    await _fetchQuotations(reset: false);
  }

  Future<void> _onRefresh() => _fetchQuotations(reset: true);

  void _onSearchSubmit(String value) {
    setState(() => _searchQuery = value.trim());
    _fetchQuotations(reset: true);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _fetchQuotations(reset: true);
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
      _fetchQuotations(reset: true);
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
      _fetchQuotations(reset: true);
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
          _fetchQuotations(reset: true);
        },
        onReset: () {
          setState(() {
            _sortBy = 'DocNo';
            _sortAsc = true;
          });
          _fetchQuotations(reset: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotations',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Quotation',
            onPressed: () async {
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => const QuotationFormPage()),
              );
              if (created == true) _fetchQuotations(reset: true);
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
                    Expanded(child: _DatePill(
                      label: 'From',
                      date: _dateFmt.format(_fromDate),
                      onTap: _pickFromDate,
                      primary: primary,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: _DatePill(
                      label: 'To',
                      date: _dateFmt.format(_toDate),
                      onTap: _pickToDate,
                      primary: primary,
                    )),
                  ],
                ),
              ),
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
                          hintText: 'Search quotations...',
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
    if (_quotations.isEmpty) return _buildEmpty();
    return _buildList();
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _quotations.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _quotations.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: DotsLoading()),
            );
          }
          final q = _quotations[i];
          return _QuotationTile(
            quotation: q,
            amtFmt: _amtFmt,
            dateFmt: _dateFmt,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuotationDetailPage(docID: q.docID),
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
            const Text('Failed to load quotations',
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
              onPressed: () => _fetchQuotations(reset: true),
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
                  : 'No quotations found',
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
// Date pill
// ─────────────────────────────────────────────────────────────────────

class _DatePill extends StatelessWidget {
  final String label;
  final String date;
  final VoidCallback onTap;
  final Color primary;

  const _DatePill({
    required this.label,
    required this.date,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: primary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                date,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: primary,
                ),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 16, color: primary.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Quotation tile
// ─────────────────────────────────────────────────────────────────────

class _QuotationTile extends StatelessWidget {
  final QuotationListItem quotation;
  final NumberFormat amtFmt;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  const _QuotationTile({
    required this.quotation,
    required this.amtFmt,
    required this.dateFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    DateTime? docDate;
    try {
      docDate = DateTime.parse(quotation.docDate);
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
                color: quotation.isVoid
                    ? Colors.red.withValues(alpha: 0.1)
                    : primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 22,
                color: quotation.isVoid ? Colors.red : primary,
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
                        quotation.docNo,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (quotation.isVoid) _VoidBadge(),
                      const Spacer(),
                      Icon(Icons.calendar_today_outlined, size: 11, color: muted),
                      const SizedBox(width: 3),
                      Text(
                        docDate != null ? dateFmt.format(docDate) : quotation.docDate,
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Row 2: Customer name
                  Text(
                    quotation.customerName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Row 3: Sales agent | Total
                  Row(
                    children: [
                      if ((quotation.salesAgent ?? '').isNotEmpty) ...[
                        Icon(Icons.person_outline, size: 12, color: muted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            quotation.salesAgent!,
                            style: TextStyle(fontSize: 12, color: muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      Text(
                        'RM ${amtFmt.format(quotation.finalTotal)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
                    value: _sortBy,
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
          color:
              selected ? primary.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
              color: selected
                  ? primary
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.4)),
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
