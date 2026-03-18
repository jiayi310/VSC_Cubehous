import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../common/my_color.dart';
import '../../common/session_manager.dart';
import '../../models/purchase_order.dart';

class PurchaseDetailPage extends StatefulWidget {
  final int docID;
  const PurchaseDetailPage({super.key, required this.docID});

  @override
  State<PurchaseDetailPage> createState() => _PurchaseDetailPageState();
}

class _PurchaseDetailPageState extends State<PurchaseDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';
  List<String> _accessRights = [];

  PurchaseDoc? _doc;
  bool _loading = true;
  bool _pdfLoading = false;
  String? _error;

  final _amtFmt = NumberFormat('#,##0.00');
  final _qtyFmt = NumberFormat('#,##0.##');
  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    ]);
    _apiKey = results[0] as String;
    _companyGUID = results[1] as String;
    _userID = results[2] as int;
    _userSessionID = results[3] as String;
    _accessRights = results[4] as List<String>;
    await _loadDoc();
  }

  void _showNoAccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text(
            'You do not have the access right to perform this action.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf() async {
    setState(() => _pdfLoading = true);
    try {
      final bytes = await BaseClient.postBytes(
        ApiEndpoints.getPurchaseReport,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': widget.docID.toString(),
        },
      );

      Directory dir;
      if (Platform.isAndroid) {
        dir = (await getExternalStorageDirectory()) ??
            await getTemporaryDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final timestamp =
          DateFormat('yyyyMMddHHmmss').format(DateTime.now());
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

  Future<void> _loadDoc() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getPurchase,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': widget.docID,
        },
      );
      setState(() {
        _doc = PurchaseDoc.fromJson(json as Map<String, dynamic>);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _deletePurchase() async {
    final confirmed = await _confirmDelete(_doc!.docNo);
    if (confirmed != true) return;
    try {
      await BaseClient.post(
        ApiEndpoints.removePurchase,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': widget.docID,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Failed to delete: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    }
  }

  Future<bool?> _confirmDelete(String docNo) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 32, color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delete Purchase Order',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Are you sure you want to delete\n$docNo?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.6),
                      height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
              Divider(
                  height: 1,
                  color: cs.outline.withValues(alpha: 0.15)),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(20)),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(ctx, false),
                        child: Text('Cancel',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface
                                    .withValues(alpha: 0.6))),
                      ),
                    ),
                    VerticalDivider(
                        width: 1,
                        color: cs.outline.withValues(alpha: 0.15)),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 16),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                                bottomRight:
                                    Radius.circular(20)),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _doc?.docNo ?? 'Purchase Order',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_doc != null && _doc!.isVoid)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
                    child: Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))),
                  )
                : PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'pdf':
                          _downloadPdf();
                        case 'delete':
                          if (!_accessRights
                              .contains('PURCHASE_DELETE')) {
                            _showNoAccessDialog();
                            return;
                          }
                          await _deletePurchase();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'pdf',
                        child: ListTile(
                          leading:
                              Icon(Icons.picture_as_pdf_outlined),
                          title: Text('Download PDF'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline,
                              color: Colors.red),
                          title: Text('Delete',
                              style:
                                  TextStyle(color: Colors.red)),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
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
                    icon: Icon(Icons.business_outlined, size: 18),
                    text: 'Supplier',
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
                indicatorColor:
                    Theme.of(context).colorScheme.primary,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    const TextStyle(fontSize: 11),
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
                          _buildSupplierTab(_doc!),
                          _buildItemsTab(_doc!),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── Totals summary bar ────────────────────────────────────────────

  Widget _buildTotalsBar(PurchaseDoc doc) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerLow,
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text('Total Amt',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: primary)),
          const Spacer(),
          Text(
            _amtFmt.format(doc.finalTotal),
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: primary),
          ),
        ],
      ),
    );
  }

  // ── Info tab ──────────────────────────────────────────────────────

  Widget _buildInfoTab(PurchaseDoc doc) {
    DateTime? docDate;
    try {
      docDate = DateTime.parse(doc.docDate);
    } catch (_) {}

    final primary = Theme.of(context).colorScheme.primary;
    final muted = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.5);

    return ListView(
      children: [
        _SectionHeader(title: 'DOCUMENT'),
        _DetailRow(label: 'Doc No', value: doc.docNo),
        _DetailRow(
            label: 'Date',
            value: docDate != null
                ? _dateFmt.format(docDate)
                : doc.docDate),
        // Receive status badge row
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 11),
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
              SizedBox(
                width: 100,
                child: Text(
                  'Status',
                  style: TextStyle(
                      fontSize: 13, color: muted),
                ),
              ),
              const Spacer(),
              doc.isReceive
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green
                            .withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'RECEIVED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                          letterSpacing: 0.4,
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orange
                            .withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PENDING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.orange,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
            ],
          ),
        ),
        if ((doc.description ?? '').isNotEmpty)
          _DetailRow(
              label: 'Description', value: doc.description!),
        if ((doc.remark ?? '').isNotEmpty)
          _DetailRow(label: 'Remark', value: doc.remark!),
        const SizedBox(height: 10),
        _SectionHeader(title: 'SUPPLIER'),
        _DetailRow(label: 'Code', value: doc.supplierCode),
        _DetailRow(label: 'Name', value: doc.supplierName),
        const SizedBox(height: 10),
        _SectionHeader(title: 'TOTAL'),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          child: Column(
            children: [
              _PriceSummaryRow(
                  label: 'Subtotal',
                  value: _amtFmt.format(doc.subtotal),
                  muted: muted),
              if (doc.taxAmt != 0)
                _PriceSummaryRow(
                  label: 'Tax Amt',
                  value: _amtFmt.format(doc.taxAmt),
                  muted: muted,
                  valueColor: Mycolor.taxTextColor,
                ),
              if (doc.taxableAmt != 0)
                _PriceSummaryRow(
                  label: 'Taxable Amt',
                  value: _amtFmt.format(doc.taxableAmt),
                  muted: muted,
                  valueColor: muted,
                ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Amt',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: primary)),
                  Text(
                    _amtFmt.format(doc.finalTotal),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primary),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Supplier tab ──────────────────────────────────────────────────

  Widget _buildSupplierTab(PurchaseDoc doc) {
    final addrLines = [
      doc.address1,
      doc.address2,
      doc.address3,
      doc.address4
    ].where((l) => (l ?? '').isNotEmpty).cast<String>().toList();

    return ListView(
      children: [
        _SectionHeader(title: 'SUPPLIER'),
        _DetailRow(label: 'Code', value: doc.supplierCode),
        _DetailRow(label: 'Name', value: doc.supplierName),
        if (addrLines.isNotEmpty)
          _AddressBlock(label: 'Address', lines: addrLines),
        if ((doc.phone ?? '').isNotEmpty)
          _DetailRow(label: 'Phone', value: doc.phone!),
        if ((doc.fax ?? '').isNotEmpty)
          _DetailRow(label: 'Fax', value: doc.fax!),
        if ((doc.email ?? '').isNotEmpty)
          _DetailRow(label: 'Email', value: doc.email!),
        if ((doc.attention ?? '').isNotEmpty)
          _DetailRow(label: 'Attention', value: doc.attention!),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Items tab ─────────────────────────────────────────────────────

  Widget _buildItemsTab(PurchaseDoc doc) {
    if (doc.purchaseDetails.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: doc.purchaseDetails.length,
      itemBuilder: (_, i) => _ItemTile(
        index: i,
        line: doc.purchaseDetails[i],
        amtFmt: _amtFmt,
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
            const Text('Failed to load purchase order',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
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
// Item tile
// ─────────────────────────────────────────────────────────────────────

class _ItemTile extends StatefulWidget {
  final int index;
  final PurchaseDetailLine line;
  final NumberFormat amtFmt;
  final NumberFormat qtyFmt;

  const _ItemTile({
    required this.index,
    required this.line,
    required this.amtFmt,
    required this.qtyFmt,
  });

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _expanded = false;

  String _fmtNum(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  Widget _breakdownRow(String label, String value, ColorScheme cs,
      {Color? valueColor}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.5))),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color:
                    valueColor ?? cs.onSurface.withValues(alpha: 0.65))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final line = widget.line;
    final fmt = widget.amtFmt;
    final qtyFmt = widget.qtyFmt;
    final discAmt = line.qty * line.unitPrice * line.discount / 100;

    final badge = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${widget.index + 1}',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: primary),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: (Theme.of(context).cardTheme.color ?? cs.surface)
                .withValues(alpha: 0.5),
            border:
                Border.all(color: cs.outline.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              badge,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: stock code | qty
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
                          'x ${_fmtNum(line.qty)}',
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
                          color: cs.onSurface
                              .withValues(alpha: 0.65)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Row 3: UOM + badges | total
                    Row(
                      children: [
                        Text(line.uom,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface
                                    .withValues(alpha: 0.5))),
                        if ((line.taxCode ?? '').isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.teal
                                  .withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Text(
                              line.taxCode!,
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                        if (line.receiveQty > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.green
                                  .withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Rcvd ${qtyFmt.format(line.receiveQty)}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          fmt.format(line.total),
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: primary),
                        ),
                      ],
                    ),
                    // Expandable breakdown
                    if (_expanded) ...[
                      const SizedBox(height: 8),
                      Divider(
                          height: 1,
                          color: cs.outline.withValues(alpha: 0.2)),
                      const SizedBox(height: 8),
                      _breakdownRow(
                          'Subtotal',
                          fmt.format(line.qty * line.unitPrice),
                          cs),
                      if (discAmt > 0) ...[
                        const SizedBox(height: 3),
                        _breakdownRow(
                            'Discount (${_fmtNum(line.discount)}%)',
                            '- ${fmt.format(discAmt)}',
                            cs,
                            valueColor: Colors.orange),
                      ],
                      if ((line.taxCode ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        _breakdownRow(
                            'Tax (${line.taxCode} ${_fmtNum(line.taxRate)}%)',
                            '+ ${fmt.format(line.taxAmt)}',
                            cs,
                            valueColor: Colors.teal),
                      ],
                    ],
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
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────

class _PriceSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color muted;
  final Color? valueColor;

  const _PriceSummaryRow({
    required this.label,
    required this.value,
    required this.muted,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: valueColor ?? muted)),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
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
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressBlock extends StatelessWidget {
  final String label;
  final List<String> lines;
  const _AddressBlock({required this.label, required this.lines});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context)
        .colorScheme
        .onSurface
        .withValues(alpha: 0.5);
    final borderColor = Theme.of(context)
        .colorScheme
        .outline
        .withValues(alpha: 0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(fontSize: 13, color: muted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: lines
                  .map((l) => Text(l,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
