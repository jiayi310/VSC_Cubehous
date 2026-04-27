import 'package:cubehous/api/api_endpoints.dart';
import 'package:cubehous/common/direction_chip.dart';
import 'package:cubehous/common/dots_loading.dart';
import 'package:cubehous/common/pagination_bar.dart';
import 'package:cubehous/common/session_manager.dart';
import 'package:cubehous/models/receiving.dart';
import 'package:cubehous/api/base_client.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReceivingPOPickerPage extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  const ReceivingPOPickerPage({
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID
  });

  @override
  State<ReceivingPOPickerPage> createState() => _POPickerPageState();
}

class _POPickerPageState extends State<ReceivingPOPickerPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<ReceivingSelectedPO> _items = [];
  bool _loading = true;
  String? _error;

  // Pagination
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalCount = 0;
  final int _pageSize = 20;

  // Sort
  String _sortBy = 'DocDate';
  bool _sortAsc = false;

  DateFormat _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    SessionManager.getDateFormat().then((fmt) {
      if (mounted) setState(() => _dateFmt = DateFormat(fmt));
    });
    _fetch(page: 0);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({required int page}) async {
    if (_loading && page != 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getReceivingPurchaseList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'pageIndex': page,
          'pageSize': _pageSize,
          'sortBy': _sortBy,
          'isSortByAscending': _sortAsc,
          'searchTerm': _searchCtrl.text.trim().isEmpty
              ? null
              : _searchCtrl.text.trim(),
        },
      );

      List<dynamic> raw;
      int totalRecord;
      int pageSize;
      if (response is List) {
        raw = response;
        totalRecord = raw.length;
        pageSize = _pageSize;
      } else if (response is Map<String, dynamic>) {
        raw = (response['data'] as List<dynamic>?) ?? [];
        final pg = response['pagination'] as Map<String, dynamic>?;
        totalRecord = (pg?['totalRecord'] as int?) ?? raw.length;
        pageSize = (pg?['pageSize'] as int?) ?? _pageSize;
      } else {
        raw = [];
        totalRecord = 0;
        pageSize = _pageSize;
      }

      if (mounted) {
        setState(() {
          _items = raw
              .map((e) =>
                  ReceivingSelectedPO.fromJson(e as Map<String, dynamic>))
              .toList();
          _currentPage = page;
          _totalCount = totalRecord;
          _totalPages = pageSize > 0 ? (totalRecord / pageSize).ceil() : 1;
          if (_totalPages < 1) _totalPages = 1;
          _loading = false;
        });
        if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _openSortSheet() {
    String tempSort = _sortBy;
    bool tempAsc = _sortAsc;
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.35,
          maxChildSize: 0.6,
          expand: false,
          builder: (_, sc) => Material(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Text('Sort By',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: tempSort,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'DocDate', child: Text('Doc Date')),
                      DropdownMenuItem(
                          value: 'DocNo', child: Text('Doc No')),
                      DropdownMenuItem(
                          value: 'SupplierName',
                          child: Text('Supplier Name')),
                    ],
                    onChanged: (v) =>
                        setSheet(() => tempSort = v ?? tempSort),
                  ),
                  const SizedBox(height: 12),
                  Text('Direction',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DirectionChip(
                          label: 'Ascending',
                          icon: Icons.arrow_upward_rounded,
                          selected: tempAsc,
                          onTap: () => setSheet(() => tempAsc = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DirectionChip(
                          label: 'Descending',
                          icon: Icons.arrow_downward_rounded,
                          selected: !tempAsc,
                          onTap: () => setSheet(() => tempAsc = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _sortBy = tempSort;
                          _sortAsc = tempAsc;
                        });
                        _fetch(page: 0);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    final start = _currentPage * _pageSize + 1;
    final end = ((_currentPage + 1) * _pageSize).clamp(0, _totalCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Order',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _fetch(page: 0),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search by PO no. or supplier...',
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
                  InkWell(
                    onTap: _openSortSheet,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 44,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.sort_rounded,
                          size: 20, color: primary),
                    ),
                  ),
                ],
              ),
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
              : Column(
                  children: [
                    Expanded(
                      child: _items.isEmpty
                          ? Center(
                              child: Text(
                                'No purchase orders available',
                                style: TextStyle(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.4)),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollCtrl,
                              itemCount: _items.length + 1,
                              itemBuilder: (_, i) {
                                if (i == _items.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    child: Center(
                                      child: Text(
                                        'Showing $start–$end of $_totalCount records',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.5)),
                                      ),
                                    ),
                                  );
                                }
                                final po = _items[i];
                                DateTime? d;
                                try {
                                  d = DateTime.parse(po.docDate);
                                } catch (_) {}
                                return InkWell(
                                  onTap: () => Navigator.pop(context, po),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: cs.outline
                                              .withValues(alpha: 0.08),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                              Icons.shopping_basket_outlined,
                                              size: 20,
                                              color: primary),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      po.docNo,
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
                                                          color: primary),
                                                    ),
                                                  ),
                                                  if (d != null)
                                                    Text(
                                                      _dateFmt.format(d),
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: cs.onSurface
                                                              .withValues(alpha: 0.5)),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                po.supplierName,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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
                ),
    );
  }
}
