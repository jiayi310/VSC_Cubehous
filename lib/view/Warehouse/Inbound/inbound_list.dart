import 'package:cubehous/api/api_endpoints.dart';
import 'package:cubehous/api/base_client.dart';
import 'package:cubehous/common/direction_chip.dart';
import 'package:cubehous/common/dots_loading.dart';
import 'package:cubehous/common/session_manager.dart';
import 'package:cubehous/models/inbound.dart';
import 'package:cubehous/view/Common/common_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../../common/date_pill.dart';
import '../../../common/pagination_bar.dart';
import 'inbound_detail.dart';
import 'inbound_form.dart';

const _sortOptions = [
  ('Doc No', 'DocNo'),
  ('Doc Date', 'DocDate'),
];

class InboundListPage extends StatefulWidget {
  const InboundListPage({super.key});

  @override
  State<InboundListPage> createState() => _InboundListPageState();
}

class _InboundListPageState extends State<InboundListPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';
  List<String> _accessRights = [];

  // Pagination
  int _itemsPerPage = 20;
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalCount = 0;

    // Data
  List<InboundListItem> _items = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasDraft = false;
  String? _error;

  final _searchController = TextEditingController();
   String _searchQuery = '';
  String _sortBy = 'DocNo';
  bool _sortAsc = false;
  String _docTypeFilter = 'All';
  
  // Date filter
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  late DateFormat _dateFmt;
  late NumberFormat _amtFmt;
  late String _currency;

  final _scrollController = ScrollController();

  int get _activeFilters => (_sortBy != 'DocNo' ? 1 : 0) + (!_sortAsc ? 0 : 1);

  static const _docTypeFilters = ['All', 'RCV', 'PUT'];

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
      SessionManager.getSalesDecimalPoint(),
      SessionManager.getDateFormat(),
      SessionManager.getCurrencySymbol(),
    ]);
    _apiKey = results[0] as String;
    _companyGUID = results[1] as String;
    _userID = results[2] as int;
    _userSessionID = results[3] as String;
    _accessRights = results[4] as List<String>;
    _itemsPerPage = results[5] as int;
    final dp = results[6] as int;
    _amtFmt = NumberFormat('#,##0.${'0' * dp}');
    final de = results[7] as String;
    _dateFmt = DateFormat(de);
    _currency = results[8] as String;
    await Future.wait([
      _fetchInbound(page: 0),
      _refreshDraftFlag(),
    ]);
    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _refreshDraftFlag() async {
    final has = await SessionManager.hasInboundDraft();
    if (mounted) setState(() => _hasDraft = has);
  }

  bool _hasAccess(String right) => _accessRights.contains(right);

  Future<void> _fetchInbound({required int page}) async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getInboundList,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'isFilterByCreatedDateTime': false,
          'fromDate': _fromDate.toIso8601String(),
          'toDate': _toDate.add(const Duration(days: 1)).toIso8601String(),
          'pageIndex': page,
          'pageSize': _itemsPerPage,
          'sortBy': _sortBy,
          'isSortByAscending': _sortAsc,
          'searchTerm': _searchQuery.isEmpty ? null : _searchQuery,
        },
      );

      final result = InboundResponse.fromJson(response as Map<String, dynamic>);
      final items = result.data ?? [];
      final totalRecord = result.pagination?.totalRecord ?? items.length;
      final pageSize = result.pagination?.pageSize ?? _itemsPerPage;

      if (mounted) {
        setState(() {
          _items = items;
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
    _fetchInbound(page: 0);
  }

  Future<bool> _deleteDoc(String module, int docID) async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    try {
      await BaseClient.post(
        ApiEndpoints.removeInbound,
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
            content: Text(e is BadRequestException ? e.message : 'Failed to delete: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
      return false;
    }
  }

  Future<void> _onRefresh() => _fetchInbound(page: 0);

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: _toDate,
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      _fetchInbound(page: 0);
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
      _fetchInbound(page: 0);
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
          _fetchInbound(page: 0);
        },
        onReset: () {
          setState(() {
            _sortBy = 'DocNo';
            _sortAsc = true;
          });
          _fetchInbound(page: 0);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: DotsLoading()));
    }
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onDoubleTap: () {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut);
            }
          },
          child: const Text('Inbound',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Inbound',
            onPressed: () async {
              // if (!_hasAccess('QUOTATION_ADD')) {
              //   CommonDialog.showNoAccessRightDialog(context);
              //   return;
              // }
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (_) => const InboundFormPage()),
              );
              if (created == true) _fetchInbound(page: 0);
              _refreshDraftFlag();
            },
          )
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
                    Expanded(child: DatePill(
                      label: 'From',
                      date: _dateFmt.format(_fromDate),
                      onTap: _pickFromDate,
                      primary: primary,
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: DatePill(
                      label: 'To',
                      date: _dateFmt.format(_toDate),
                      onTap: _pickToDate,
                      primary: primary,
                    )),
                  ],
                ),
              ),
              SizedBox(height: 3),
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
                          hintText: 'Search inbounds...',
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    _fetchInbound(page: 0);
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                    // Filter button
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
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // ── DocType filter chips ──────────────────────────────────
          Container(
            height: 46,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: cs.outline.withValues(alpha: 0.12)),
              ),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              itemCount: _docTypeFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _docTypeFilters[i];
                final selected = _docTypeFilter == t;
                return FilterChip(
                  label: Text(t,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal)),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _docTypeFilter = t),
                  selectedColor: primary.withValues(alpha: 0.12),
                  checkmarkColor: primary,
                  side: BorderSide(
                      color: selected
                          ? primary
                          : cs.outline.withValues(alpha: 0.35)),
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),

          // ── List ─────────────────────────────────────────────────
          Expanded(child: _buildBody(cs, primary)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, Color primary) {
    if (_isLoading) return const Center(child: DotsLoading());
    if (_error != null) return _buildError();
    final start = _currentPage * _itemsPerPage + 1;
    final end = ((_currentPage + 1) * _itemsPerPage).clamp(0, _totalCount);
    return Column(
      children: [
        if (_hasDraft) _DraftBanner(
          onContinue: () async {
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const InboundFormPage()),
            );
            _fetchInbound(page: 0);
            _refreshDraftFlag();
          },
          onDiscard: () async {
            await SessionManager.clearInboundDraft();
            setState(() => _hasDraft = false);
          },
        ),
        if (_items.isEmpty)
          Expanded(child: _buildEmpty())
        else
          Expanded(child: _buildList(start: start, end: end)),
        PaginationBar(
          currentPage: _currentPage,
          totalPages: _totalPages,
          isLoading: _isLoading,
          primary: primary,
          onPrev: _currentPage > 0 ? () => _fetchInbound(page: _currentPage - 1) : null,
          onNext: _currentPage < _totalPages - 1 ? () => _fetchInbound(page: _currentPage + 1) : null,
        ),
      ],
    );
  }

  Future<void> _onEditTap(InboundListItem item) async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    if (!_hasAccess('QUOTATION_EDIT')) {
      if (!mounted) return;
      CommonDialog.showNoAccessRightDialog(context);
      return;
    }
    InboundDoc? doc;
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getInbound,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': item.docID,
        },
      );
      doc = InboundDoc.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Failed to load quotation: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
      return;
    }
    if (!mounted) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InboundFormPage(initialDoc: doc),
      ),
    );
    if (updated == true && mounted) _fetchInbound(page: _currentPage);
  }

  Future<void> _onDeleteTap(InboundListItem item) async {
    if (!_hasAccess('QUOTATION_DELETE')) {
      CommonDialog.showNoAccessRightDialog(context);
      return;
    }
    final confirmed = await CommonDialog.confirmDeleteDialog(context, item.docNo, 'Quotation');
    if (confirmed != true) return;
    final ok = await _deleteDoc(item.docType, item.docID);
    if (ok && mounted) {
      setState(() => _items.removeWhere((e) => e.docID == item.docID));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Quotation deleted'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  Widget _buildList({required int start, required int end}) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: SlidableAutoCloseBehavior(
        child: ListView.builder(
        controller: _scrollController,
        itemCount: _items.length + 1,
        itemBuilder: (context, i) {
          if (i == _items.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'Showing $start–$end of $_totalCount records',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            );
          }
          final item = _items[i];
          return Slidable(
            key: ValueKey(item.docID),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.48,
              children: [
                CustomSlidableAction(
                  onPressed: (_) => _onEditTap(item),
                  backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.edit_outlined, size: 26, color: Color(0xFF1565C0)),
                      SizedBox(height: 4),
                      Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
                    ],
                  ),
                ),
                CustomSlidableAction(
                  onPressed: (_) => _onDeleteTap(item),
                  backgroundColor: Colors.red.withValues(alpha: 0.12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.delete_outline, size: 26, color: Colors.red),
                      SizedBox(height: 4),
                      Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            child: InboundTile(
              item: item,
              amtFmt: _amtFmt,
              dateFmt: _dateFmt,
              currency: _currency,
              onTap: () async {
                final result = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InboundDetailPage(docID: item.docID),
                  ),
                );
                if (result == true && mounted) _fetchInbound(page: _currentPage);
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
            const Text('Failed to load inbounds',
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
              onPressed: () => _fetchInbound(page: 0),
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
                  : 'No inbounds found',
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

// ── Inbound tile (ready for when API is wired up) ─────────────────────

class InboundTile extends StatelessWidget {
  final InboundListItem item;
  final NumberFormat amtFmt;
  final DateFormat dateFmt;
  final String currency;
  final VoidCallback onTap;

  const InboundTile({
    super.key,
    required this.item,
    required this.amtFmt,
    required this.dateFmt,
    required this.currency,
    required this.onTap,
  });

  static Color _typeColor(String type) {
    switch (type) {
      case 'GRN':
        return const Color(0xFF1565C0);
      case 'PUT':
        return const Color(0xFF00695C);
      default:
        return const Color(0xFF546E7A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typeColor = _typeColor(item.docType);

    DateTime? docDate;
    try {
      docDate = DateTime.parse(item.docDate);
    } catch (_) {}

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            // DocType badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                item.docType,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: typeColor,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Doc info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.docNo,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                ],
              ),
            ),
            // Date + status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(docDate != null ? dateFmt.format(docDate) : item.docDate,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftBanner extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onDiscard;

  const _DraftBanner({required this.onContinue, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_note_rounded, size: 22, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unsaved Draft',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primary)),
                Text('You have a inbound in progress.',
                    style: TextStyle(
                        fontSize: 11,
                        color: primary.withValues(alpha: 0.7))),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: primary,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: onDiscard,
            child: const Text('Discard', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 4),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            onPressed: onContinue,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

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

