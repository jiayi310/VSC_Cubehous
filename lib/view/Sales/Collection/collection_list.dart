import 'package:cubehous/view/Common/common_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/date_pill.dart';
import '../../../common/direction_chip.dart';
import '../../../common/dots_loading.dart';
import '../../../common/pagination_bar.dart';
import '../../../common/session_manager.dart';
import '../../../models/collection.dart';
import 'collection_detail.dart';
import 'collection_form.dart';

const _sortOptions = [
  ('Doc No', 'DocNo'),
  ('Doc Date', 'DocDate'),
  ('Customer', 'CustomerName'),
  ('Total', 'PaymentTotal'),
];

class CollectionListPage extends StatefulWidget {
  const CollectionListPage({super.key});

  @override
  State<CollectionListPage> createState() => _CollectionListPageState();
}

class _CollectionListPageState extends State<CollectionListPage> {
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
  List<CollectionListItem> _collections = [];
  bool _isLoading = false;
  bool _hasDraft = false;
  String? _error;

  // Search & sort
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'DocNo';
  bool _sortAsc = false;

  // Date filter
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  final _dateFmt = DateFormat('dd/MM/yyyy');
  late NumberFormat _amtFmt;

  final _scrollController = ScrollController();

  // Only count non-default state: sortBy changed OR direction flipped to ascending
  int get _activeFilters =>
      (_sortBy != 'DocNo' ? 1 : 0) + (_sortAsc ? 1 : 0);

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
    ]);
    _apiKey = results[0] as String;
    _companyGUID = results[1] as String;
    _userID = results[2] as int;
    _userSessionID = results[3] as String;
    _accessRights = results[4] as List<String>;
    _itemsPerPage = results[5] as int;
    final dp = results[6] as int;
    _amtFmt = NumberFormat('#,##0.${'0' * dp}');
    await Future.wait([
      _fetchCollections(page: 0),
      _refreshDraftFlag(),
    ]);
  }

  Future<void> _refreshDraftFlag() async {
    final has = await SessionManager.hasCollectionDraft();
    if (mounted) setState(() => _hasDraft = has);
  }

  bool _hasAccess(String right) => _accessRights.contains(right);

  Future<void> _fetchCollections({required int page}) async {
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
        ApiEndpoints.getCollectionList,
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

      final result =
          CollectionResponse.fromJson(response as Map<String, dynamic>);
      final items = result.data ?? [];
      final totalRecord = result.pagination?.totalRecord ?? items.length;
      final pageSize = result.pagination?.pageSize ?? _itemsPerPage;

      if (mounted) {
        setState(() {
          _collections = items;
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
    _fetchCollections(page: 0);
  }

  Future<bool> _deleteCollection(int docID) async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    try {
      await BaseClient.post(
        ApiEndpoints.removeCollection,
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

  Future<void> _onRefresh() => _fetchCollections(page: 0);
  
  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: _toDate,
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
      _fetchCollections(page: 0);
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
      _fetchCollections(page: 0);
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
          _fetchCollections(page: 0);
        },
        onReset: () {
          setState(() {
            _sortBy = 'DocNo';
            _sortAsc = false;
          });
          _fetchCollections(page: 0);
        },
      ),
    );
  }

  Future<void> _onEditTap(CollectionListItem item) async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    if (!_hasAccess('COLLECT_EDIT')) {
      if (!mounted) return;
      CommonDialog.showNoAccessRightDialog(context);
      return;
    }
    CollectionDoc? doc;
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getCollection,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': item.docID,
        },
      );
      doc = CollectionDoc.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Failed to load collection: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
      return;
    }
    if (!mounted) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionFormPage(initialDoc: doc),
      ),
    );
    if (updated == true && mounted) _fetchCollections(page: _currentPage);
  }

  Future<void> _onDeleteTap(CollectionListItem item) async {
    if (!_hasAccess('COLLECT_DELETE')) {
      CommonDialog.showNoAccessRightDialog(context);
      return;
    }
    final confirmed = await CommonDialog.confirmDeleteDialog(context, item.docNo, 'Collection');
    if (confirmed != true) return;
    final ok = await _deleteCollection(item.docID);
    if (ok && mounted) {
      setState(() => _collections.removeWhere((e) => e.docID == item.docID));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Collection deleted'),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Collection',
            onPressed: () async {
              if (!_hasAccess('COLLECT_ADD')) {
                CommonDialog.showNoAccessRightDialog(context);
                return;
              }
              final created = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const CollectionFormPage()),
              );
              if (created == true) _fetchCollections(page: 0);
              _refreshDraftFlag();
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
                          hintText: 'Search collections...',
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    _fetchCollections(page: 0);
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
                    // Filter / sort button
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: DotsLoading());
    if (_error != null) return _buildError();
    final primary = Theme.of(context).colorScheme.primary;
    final start = _currentPage * _itemsPerPage + 1;
    final end = ((_currentPage + 1) * _itemsPerPage).clamp(0, _totalCount);
    return Column(
      children: [
        if (_hasDraft) _DraftBanner(
          onContinue: () async {
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const CollectionFormPage()),
            );
            _fetchCollections(page: 0);
            _refreshDraftFlag();
          },
          onDiscard: () async {
            await SessionManager.clearCollectionDraft();
            setState(() => _hasDraft = false);
          },
        ),
        if (_collections.isEmpty)
          Expanded(child: _buildEmpty())
        else
          Expanded(child: _buildList(start: start, end: end)),
        PaginationBar(
          currentPage: _currentPage,
          totalPages: _totalPages,
          isLoading: _isLoading,
          primary: primary,
          onPrev: _currentPage > 0
              ? () => _fetchCollections(page: _currentPage - 1)
              : null,
          onNext: _currentPage < _totalPages - 1
              ? () => _fetchCollections(page: _currentPage + 1)
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
          itemCount: _collections.length + 1,
          itemBuilder: (context, i) {
            if (i == _collections.length) {
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
            final item = _collections[i];
            return Slidable(
              key: ValueKey(item.docID),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.48,
                children: [
                  CustomSlidableAction(
                    onPressed: (_) => _onEditTap(item),
                    backgroundColor:const Color(0xFF1565C0).withValues(alpha: 0.12),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.edit_outlined, size: 26, color: Color(0xFF1565C0)),
                        SizedBox(height: 4),
                        Text('Edit',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1565C0))),
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
              child: _CollectionTile(
                item: item,
                amtFmt: _amtFmt,
                dateFmt: _dateFmt,
                onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CollectionDetailPage(docID: item.docID),
                ),
              ),
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
            const Text('Failed to load collections',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
              onPressed: () => _fetchCollections(page: 0),
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
            Icon(Icons.payments_outlined,
                size: 52,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2)),
            const SizedBox(height: 14),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No collections found',
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
// Collection Tile
// ─────────────────────────────────────────────────────────────────────

class _CollectionTile extends StatelessWidget {
  final CollectionListItem item;
  final NumberFormat amtFmt;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  const _CollectionTile({
    required this.item,
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
      docDate = DateTime.parse(item.docDate);
    } catch (_) {}

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
          children: [
            // Doc icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.payments_outlined,
                size: 22,
                color: primary,
              ),
            ),
            const SizedBox(width: 14),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: DocNo | Date
                  Row(
                    children: [
                      Text(
                        item.docNo,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Spacer(),
                      Text(
                        docDate != null
                            ? dateFmt.format(docDate)
                            : item.docDate,
                        style: TextStyle(fontSize: 11, color: muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Row 2: Customer name
                  Text(
                    item.customerName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Row 3: Payment type chip | Total
                  Row(
                    children: [
                      if ((item.paymentType ?? '').isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.paymentType!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: primary,
                            ),
                          ),
                        ),
                      ] else
                        const SizedBox.shrink(),
                      const Spacer(),
                      Text(
                        'RM ${amtFmt.format(item.paymentTotal)}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700),
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
                Text('You have a collection in progress.',
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
