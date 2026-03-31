import 'dart:io';
import 'package:cubehous/models/stock_adjustment.dart';
import 'package:cubehous/view/Common/common_dialog.dart';
import 'package:cubehous/view/Common/decoration.dart';
import 'package:cubehous/view/Warehouse/StockAdjustment/stock_adjustment_form.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';

class StockAdjustmentDetailPage extends StatefulWidget {
  final StockAdjustmentListItem item;
  const StockAdjustmentDetailPage({super.key, required this.item});

  @override
  State<StockAdjustmentDetailPage> createState() => _StockAdjustmentDetailPageState();
}

class _StockAdjustmentDetailPageState extends State<StockAdjustmentDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';
  List<String> _accessRights = [];

  StockAdjustmentDoc? _doc;
  bool _loading = true;
  bool _pdfLoading = false;
  String? _error;
  String _imageMode = 'show';

  late NumberFormat _qtyFmt;
  late DateFormat _dateFmt = DateFormat('dd MM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      SessionManager.getApiKey(),
      SessionManager.getCompanyGUID(),
      SessionManager.getUserID(),
      SessionManager.getUserSessionID(),
      SessionManager.getUserAccessRight(),
      SessionManager.getImageMode(),
      SessionManager.getQuantityDecimalPoint(),
      SessionManager.getDateFormat(),
    ]);
    _apiKey = results[0] as String;
    _companyGUID = results[1] as String;
    _userID = results[2] as int;
    _userSessionID = results[3] as String;
    _accessRights = results[4] as List<String>;
    _imageMode = results[5] as String;
    final dp2 = results[6] as int;
    _qtyFmt = NumberFormat('#,##0.${'0' * dp2}');
    final dF = results[7] as String;
    _dateFmt = DateFormat(dF);
    await _loadDoc();
    if (_imageMode == 'show') _loadImages();
  }

  Future<void> _downloadPdf() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    setState(() => _pdfLoading = true);
    try {
      final bytes = await BaseClient.postBytes(
        ApiEndpoints.getStockAdjustmentReport,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': _doc!.docID.toString(),
        },
      );

      Directory dir;
      if (Platform.isAndroid) {
        dir = (await getExternalStorageDirectory()) ??
            await getTemporaryDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
      final fileName =
          '${timestamp}_${_doc!.docNo.replaceAll('/', '-')}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Failed to download PDF: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  Future<void> _deleteDoc() async {
    if (!_accessRights.contains('STOCKADJUSTMENT_DELETE')){
      CommonDialog.showNoAccessRightDialog(context);
      return;
    }
    final confirmed = await CommonDialog.confirmDeleteDialog(context, _doc!.docNo, 'Stock Adjustment');
    if (confirmed != true) return;

    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();

    try {
      await BaseClient.post(
        ApiEndpoints.removeStockAdjustment,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': _doc!.docID,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Stock Adjustment deleted'),
          behavior: SnackBarBehavior.floating,
        ));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is BadRequestException ? e.message : 'Failed to delete: $e';
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
        ));
    }
  }

  Future<void> _loadImages() async {
    if (_doc == null) return;
    final lines = _doc!.stockAdjustmentDetails;
    if (lines.isEmpty) return;

    final linesByStockId = <int, List<StockAdjustmentDetailLine>>{};
    for (final line in lines) {
      linesByStockId.putIfAbsent(line.stockID, () => []).add(line);
    }

    final ids = linesByStockId.keys.toList();
    final futures = ids.map((id) => BaseClient.post(
          ApiEndpoints.getStock,
          body: {
            'apiKey': _apiKey,
            'companyGUID': _companyGUID,
            'userID': _userID,
            'userSessionID': _userSessionID,
            'stockID': id,
          },
        ));
    final results = await Future.wait(futures, eagerError: false);
    for (var i = 0; i < ids.length; i++) {
      try {
        final img = (results[i] as Map<String, dynamic>)['image'] as String?;
        for (final line in linesByStockId[ids[i]]!) {
          line.image = img;
        }
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadDoc() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getStockAdjustment,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': widget.item.docID,
        },
      );
      setState(() {
        _doc = StockAdjustmentDoc.fromJson(json as Map<String, dynamic>);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _doc?.docNo ?? 'Stock Adjustment',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_doc != null && _doc!.isVoid)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'VOID',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.red,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          if (_doc != null)
            _pdfLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                  )
                : PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          if (!_accessRights.contains('STOCKADJUSTMENT_EDIT')) {
                            CommonDialog.showNoAccessRightDialog(context);
                            return;
                          }
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StockAdjustmentFormPage(initialDoc: _doc),
                            ),
                          );
                          if (updated == true && mounted) await _loadDoc();
                        case 'pdf':
                          _downloadPdf();
                        case 'delete':
                          if (!_accessRights.contains('STOCKADJUSTMENT_DELETE')) {
                            CommonDialog.showNoAccessRightDialog(context);
                            return;
                          }
                          _deleteDoc();
                      }
                    },
                    itemBuilder: (_) => [
                      // const PopupMenuItem(
                      //   value: 'edit',
                      //   child: ListTile(
                      //     leading: Icon(Icons.edit_outlined),
                      //     title: Text('Edit'),
                      //     contentPadding: EdgeInsets.zero,
                      //     visualDensity: VisualDensity.compact,
                      //   ),
                      // ),
                      // const PopupMenuItem(
                      //   value: 'pdf',
                      //   child: ListTile(
                      //     leading: Icon(Icons.picture_as_pdf_outlined),
                      //     title: Text('Download PDF'),
                      //     contentPadding: EdgeInsets.zero,
                      //     visualDensity: VisualDensity.compact,
                      //   ),
                      // ),
                      // const PopupMenuItem(
                      //   value: 'delete',
                      //   child: ListTile(
                      //     leading: Icon(Icons.delete_outline, color: Colors.red),
                      //     title: Text('Delete', style: TextStyle(color: Colors.red)),
                      //     contentPadding: EdgeInsets.zero,
                      //     visualDensity: VisualDensity.compact,
                      //   ),
                      // ),
                    ],
                  ),
        ],
        bottom: _loading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.info_outline, size: 18),
                    text: 'Info',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.list_alt_outlined, size: 18),
                    text: 'Items',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                ],
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.35),
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
              ),
      ),
      body: _loading
          ? const Center(child: DotsLoading())
          : _error != null
              ? _buildError()
              : Column(
                  children: [
                    _buildTotalsBar(_doc!),
                    const Divider(height: 1),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildInfoTab(_doc!),
                          _buildItemsTab(_doc!),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── Totals bar ────────────────────────────────────────────────────

  Widget _buildTotalsBar(StockAdjustmentDoc doc) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    final itemCount = doc.stockAdjustmentDetails.length;
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('Total Items',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: primary)),
          const Spacer(),
          Text(
            '$itemCount',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: primary),
          ),
        ],
      ),
    );
  }

  // ── Info tab ──────────────────────────────────────────────────────

  Widget _buildInfoTab(StockAdjustmentDoc doc) {
    DateTime? docDate;
    try {
      docDate = DateTime.parse(doc.docDate);
    } catch (_) {}


    return ListView(
      children: [
        DetailSectionHeader(title: 'DOCUMENT'),
        DetailDetailRow(label: 'Doc No', value: doc.docNo),
        DetailDetailRow(label: 'Date', value: docDate != null ? _dateFmt.format(docDate) : doc.docDate),
        DetailDetailRow(label: 'Location', value: doc.location),
        DetailDetailRow(label: 'Description', value: doc.description ?? '-'),
        DetailDetailRow(label: 'Remark', value: doc.remark ?? '-'),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Items tab ─────────────────────────────────────────────────────

  Widget _buildItemsTab(StockAdjustmentDoc doc) {
    if (doc.stockAdjustmentDetails.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 52,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.18)),
              const SizedBox(height: 14),
              Text(
                'No items',
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

    // Build ordered group map by storageCode (preserves first-seen order)
    final groupMap = <String, List<StockAdjustmentDetailLine>>{};
    for (final line in doc.stockAdjustmentDetails) {
      final key = line.storageCode.isNotEmpty ? line.storageCode : 'No Storage';
      groupMap.putIfAbsent(key, () => []).add(line);
    }

    // If everything is in one storage, fall back to flat list with no headers
    if (groupMap.length == 1 && groupMap.containsKey('No Storage')) {
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: doc.stockAdjustmentDetails.length,
        itemBuilder: (_, i) => _ItemTile(
          index: i,
          line: doc.stockAdjustmentDetails[i],
          qtyFmt: _qtyFmt,
        ),
      );
    }

    final groups = groupMap.entries.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: groups.length,
      itemBuilder: (_, i) => _GroupSection(
        groupName: groups[i].key,
        lines: groups[i].value,
        qtyFmt: _qtyFmt,
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
            const Text('Failed to load stock adjustment',
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
              onPressed: _loadDoc,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Group Section (collapsible)
// ─────────────────────────────────────────────────────────────────────

class _GroupSection extends StatefulWidget {
  final String groupName;
  final List<StockAdjustmentDetailLine> lines;
  final NumberFormat qtyFmt;

  const _GroupSection({
    required this.groupName,
    required this.lines,
    required this.qtyFmt,
  });

  @override
  State<_GroupSection> createState() => _GroupSectionState();
}

class _GroupSectionState extends State<_GroupSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // ── Group header ────────────────────────────────────────
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius: _expanded
                  ? const BorderRadius.vertical(top: Radius.circular(12))
                  : BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.07),
                  borderRadius: _expanded
                      ? const BorderRadius.vertical(top: Radius.circular(12))
                      : BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shelves, size: 16, color: primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.groupName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.lines.length} items',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: primary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
            // ── Items ───────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                      child: Column(
                        children: [
                          for (var i = 0; i < widget.lines.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                  bottom:
                                      i < widget.lines.length - 1 ? 8 : 0),
                              child: _ItemTile(
                                index: i,
                                line: widget.lines[i],
                                qtyFmt: widget.qtyFmt,
                              ),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Item Tile (Items tab)
// ─────────────────────────────────────────────────────────────────────

class _ItemTile extends StatefulWidget {
  final int index;
  final StockAdjustmentDetailLine line;
  final NumberFormat qtyFmt;

  const _ItemTile({
    required this.index,
    required this.line,
    required this.qtyFmt,
  });

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile>{

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final line = widget.line;
    final qtyFmt = widget.qtyFmt;

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 50,
        height: 50,
        child: ItemImage(base64: widget.line.image),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: (Theme.of(context).cardTheme.color ?? cs.surface)
              .withValues(alpha: 0.5),
          border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            image,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: stockCode | qty
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          line.stockCode,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'x ${qtyFmt.format(line.qty)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: primary),
                      ),
                    ],
                  ),
                  // Row 2: description
                  const SizedBox(height: 2),
                  Text(
                    line.description,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.65)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Row 3: UOM | storageCode badge | qty
                  Row(
                    children: [
                      Text(line.uom,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.5))),
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
