import 'dart:io';

import 'package:cubehous/common/my_color.dart';
import 'package:cubehous/view/Common/common_dialog.dart';
import 'package:cubehous/view/Common/decoration.dart';
import 'package:cubehous/view/Sales/Sales/sales_form.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';
import '../../../models/sales.dart';

class SalesDetailPage extends StatefulWidget {
  final int docID;
  const SalesDetailPage({super.key, required this.docID});

  @override
  State<SalesDetailPage> createState() => _SalesDetailPageState();
}

class _SalesDetailPageState extends State<SalesDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scrollControllers = List.generate(3, (_) => ScrollController());

  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';
  List<String> _accessRights = [];

  SalesDoc? _doc;
  bool _loading = true;
  bool _pdfLoading = false;
  String? _error;
  String _imageMode = 'show';

  late String _currency = '';
  late NumberFormat _amtFmt;
  late NumberFormat _qtyFmt;
  late DateFormat _dateFmt = DateFormat('dd MM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _scrollControllers) { c.dispose(); }
    super.dispose();
  }

  void _scrollToTop() {
    final sc = _scrollControllers[_tabController.index];
    if (sc.hasClients) sc.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  Future<void> _init() async {
    final results = await Future.wait([
      SessionManager.getApiKey(),
      SessionManager.getCompanyGUID(),
      SessionManager.getUserID(),
      SessionManager.getUserSessionID(),
      SessionManager.getUserAccessRight(),
      SessionManager.getImageMode(),
      SessionManager.getSalesDecimalPoint(),
      SessionManager.getQuantityDecimalPoint(),
      SessionManager.getCurrencySymbol(),
      SessionManager.getDateFormat(),
    ]);
    _apiKey = results[0] as String;
    _companyGUID = results[1] as String;
    _userID = results[2] as int;
    _userSessionID = results[3] as String;
    _accessRights = results[4] as List<String>;
    _imageMode = results[5] as String;
    final dp = results[6] as int;
    _amtFmt = NumberFormat('#,##0.${'0' * dp}');
    final dp2 = results[7] as int;
    _qtyFmt = NumberFormat('#,##0.${'0' * dp2}');
    _currency = results[8] as String;
    final dF = results[9] as String;
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
        ApiEndpoints.getSalesReport,
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
        dir = (await getExternalStorageDirectory()) ?? await getTemporaryDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
      final fileName = '${timestamp}_${_doc!.docNo.replaceAll('/', '-')}.pdf';
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
    if (!_accessRights.contains('SALES_DELETE')) {
      CommonDialog.showNoAccessRightDialog(context);
      return;
    }
    final confirmed = await CommonDialog.confirmDeleteDialog(context, _doc!.docNo, 'Sales Order');
    if (confirmed != true) return;

    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();

    try {
      await BaseClient.post(
        ApiEndpoints.removeSales,
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
          content: Text('Sales order deleted'),
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
    final lines = _doc!.salesDetails;
    if (lines.isEmpty) return;

    final linesByStockId = <int, List<SalesDetailLine>>{};
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
        ApiEndpoints.getSales,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': widget.docID,
        },
      );
      setState(() {
        _doc = SalesDoc.fromJson(json as Map<String, dynamic>);
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
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _scrollToTop,
          child: SizedBox(
            width: double.infinity,
            child: Text(
              _doc?.docNo ?? 'Sales Order',
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          if (_doc != null && _doc!.isVoid)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                          if (!_accessRights.contains('SALES_EDIT')) {
                            CommonDialog.showNoAccessRightDialog(context);
                            return;
                          }
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SalesFormPage(initialDoc: _doc),
                            ),
                          );
                          if (updated == true && mounted) {
                            await _loadDoc();
                            if (_imageMode == 'show') _loadImages();
                          }
                        case 'copy':
                          if (!mounted) return;
                          await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SalesFormPage(copyFrom: _doc),
                            ),
                          );
                        case 'pdf':
                          _downloadPdf();
                        case 'delete':
                          if (!_accessRights.contains('SALES_DELETE')) {
                            CommonDialog.showNoAccessRightDialog(context);
                            return;
                          }
                          _deleteDoc();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'pdf',
                        child: ListTile(
                          leading: Icon(Icons.picture_as_pdf_outlined),
                          title: Text('Download PDF'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy',
                        child: ListTile(
                          leading: Icon(Icons.copy_outlined),
                          title: Text('Copy'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: Colors.red),
                          title: Text('Delete', style: TextStyle(color: Colors.red)),
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
                    icon: Icon(Icons.person_outline, size: 18),
                    text: 'Customer',
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
                          _buildCustomerTab(_doc!),
                          _buildItemsTab(_doc!),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── Totals summary bar ───────────────────────────────────────────────

  Widget _buildTotalsBar(SalesDoc doc) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Total Amt',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: primary)),
              const Spacer(),
              Text(
                '$_currency ${_amtFmt.format(doc.finalTotal)}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: primary),
              ),
            ],
          ),
          if (doc.outstanding > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paid: $_currency ${_amtFmt.format(doc.paymentTotal)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  'Outstanding: $_currency ${_amtFmt.format(doc.outstanding)}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Info tab ──────────────────────────────────────────────────────

  Widget _buildInfoTab(SalesDoc doc) {
    DateTime? docDate;
    try {
      docDate = DateTime.parse(doc.docDate);
    } catch (_) {}

    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return ListView(
      controller: _scrollControllers[0],
      children: [
        DetailSectionHeader(title: 'DOCUMENT'),
        DetailDetailRow(label: 'Doc No', value: doc.docNo),
        DetailDetailRow(label: 'Date', value: docDate != null ? _dateFmt.format(docDate) : doc.docDate),
        DetailDetailRow(label: 'Sales Agent', value: doc.salesAgent ?? '-'),
        DetailDetailRow(label: 'Description', value: doc.description ?? '-'),
        DetailDetailRow(label: 'Remark', value: doc.remark ?? '-'),
        if ((doc.qtDocNo ?? '').isNotEmpty)
          DetailDetailRow(label: 'Quotation Ref', value: doc.qtDocNo!),
        DetailDetailRow(label: 'Shipping', value: doc.shippingMethodDescription ?? '-'),
        if (doc.isPicking || doc.isPacking)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                if (doc.isPicking)
                  _StatusChip(label: 'Picking', color: Colors.blue),
                if (doc.isPicking && doc.isPacking)
                  const SizedBox(width: 8),
                if (doc.isPacking)
                  _StatusChip(label: 'Packing', color: Colors.purple),
              ],
            ),
          ),
        const SizedBox(height: 10),
        DetailSectionHeader(title: 'TOTAL'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              DetailTotalPriceSummaryRow(
                label: 'Subtotal',
                value: _amtFmt.format(doc.subtotal),
                muted: muted,
                valueColor: muted),
              Builder(builder: (_) {
                final discAmt = doc.salesDetails.fold(0.0, (s, l) => s + l.qty * l.unitPrice * l.discount / 100);
                return DetailTotalPriceSummaryRow(
                  label: 'Discount',
                  value: '- ${_amtFmt.format(discAmt)}',
                  muted: muted,
                  valueColor: discAmt == 0 ? muted : Mycolor.discountTextColor,
                );
              }),
              if (doc.taxAmt != 0)
                DetailTotalPriceSummaryRow(
                  label: 'Tax Amt',
                  value: _amtFmt.format(doc.taxAmt),
                  muted: muted,
                  valueColor: doc.taxAmt == 0 ? muted : Mycolor.taxTextColor),
              if (doc.taxableAmt != 0)
                DetailTotalPriceSummaryRow(
                  label: 'Taxable Amt',
                  value: _amtFmt.format(doc.taxableAmt),
                  muted: muted,
                  valueColor: muted),
              const Divider(height: 5),
              DetailTotalPriceSummaryRow(
                label: 'Total Amt ($_currency)',
                value: _amtFmt.format(doc.finalTotal),
                muted: muted,
                valueColor: doc.taxAmt == 0 ? muted : Mycolor.primary),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Customer tab ──────────────────────────────────────────────────────

  Widget _buildCustomerTab(SalesDoc doc) {
    final billingLines = [doc.address1, doc.address2, doc.address3, doc.address4]
        .where((l) => (l ?? '').isNotEmpty).cast<String>().toList();
    final deliveryLines = [doc.deliverAddr1, doc.deliverAddr2, doc.deliverAddr3, doc.deliverAddr4]
        .where((l) => (l ?? '').isNotEmpty).cast<String>().toList();

    return ListView(
      controller: _scrollControllers[1],
      children: [
        DetailSectionHeader(title: 'CUSTOMER'),
        DetailDetailRow(label: 'Code', value: doc.customerCode),
        DetailDetailRow(label: 'Name', value: doc.customerName),
        if (billingLines.isNotEmpty)
          DetailAddressRow(label: 'Billing Address', lines: billingLines),
        if (deliveryLines.isNotEmpty)
          DetailAddressRow(label: 'Delivery Address', lines: deliveryLines),
        if ((doc.attention ?? '').isNotEmpty)
          DetailDetailRow(label: 'Attention', value: doc.attention!),
        if ((doc.phone ?? '').isNotEmpty)
          DetailDetailRow(label: 'Phone', value: doc.phone!),
        if ((doc.fax ?? '').isNotEmpty)
          DetailDetailRow(label: 'Fax', value: doc.fax!),
        if ((doc.email ?? '').isNotEmpty)
          DetailDetailRow(label: 'Email', value: doc.email!),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Items tab ────────────────────────────────────────────────────────

  Widget _buildItemsTab(SalesDoc doc) {
    if (doc.salesDetails.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical:10),
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

    final primary = Theme.of(context).colorScheme.primary;
    return ListView.builder(
            controller: _scrollControllers[2],
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: doc.salesDetails.length,
            itemBuilder: (_, i) => _ItemTile(
              index: i,
              line: doc.salesDetails[i],
              salesFmt: _amtFmt,
              qtyFmt: _qtyFmt,
              imageMode: _imageMode,
              image: doc.salesDetails[i].image,
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
            const Text('Failed to load sales order',
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
  final SalesDetailLine line;
  final NumberFormat salesFmt;
  final NumberFormat qtyFmt;
  final String imageMode;
  final String? image;

  const _ItemTile({
    required this.index,
    required this.line,
    required this.salesFmt,
    required this.qtyFmt,
    required this.imageMode,
    this.image,
  });

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _expanded = false;

  String _fmtNum(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final line = widget.line;
    final salesFmt = widget.salesFmt;
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
              fontSize: 13, fontWeight: FontWeight.w700, color: primary),
        ),
      ),
    );

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 50,
        height: 50,
        child: ItemImage(base64: widget.image),
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
            border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              widget.imageMode == 'show' ? image : badge,
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
                    // Row 3: UOM + badges | total
                    Row(
                      children: [
                        Text(line.uom,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                        if ((line.discountText ?? "").isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              line.discountText ?? '',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                        if ((line.taxCode ?? '').isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
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
                        const Spacer(),
                        Text(
                          salesFmt.format(line.total + line.taxAmt),
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
                      breakdownRow(
                          'UnitPrice',
                          salesFmt.format(line.unitPrice),
                          cs),
                      const SizedBox(height: 3),
                      breakdownRow(
                          'Subtotal',
                          salesFmt.format(line.qty * line.unitPrice),
                          cs),
                      if (discAmt > 0) ...[
                        const SizedBox(height: 3),
                        breakdownRow(
                            'Discount',
                            '- ${salesFmt.format(discAmt)}',
                            cs,
                            labelColor: Mycolor.discountTextColor,
                            valueColor: Mycolor.discountTextColor),
                      ],
                      if ((line.taxCode ?? '').isNotEmpty) ...[
                        const SizedBox(height: 3),
                        breakdownRow(
                            'Tax (${_fmtNum(line.taxRate)}%)',
                            '+ ${salesFmt.format(line.taxAmt)}',
                            cs,
                            labelColor: Mycolor.taxTextColor,
                            valueColor: Mycolor.taxTextColor),
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
// Picking/Packing status chip
// ─────────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
