import 'dart:convert';
import 'dart:io';
import 'package:cubehous/common/my_color.dart';
import 'package:cubehous/view/Common/common_dialog.dart';
import 'package:cubehous/view/Common/decoration.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';
import '../../../models/collection.dart';
import 'collection_form.dart';

class CollectionDetailPage extends StatefulWidget {
  final int docID;
  const CollectionDetailPage({super.key, required this.docID});

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';
  List<String> _accessRights = [];

  CollectionDoc? _doc;
  bool _loading = true;
  bool _pdfLoading = false;
  String? _error;

  late String _currency = '';
  late NumberFormat _salesFmt;
  late DateFormat _dateFmt;

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
      SessionManager.getSalesDecimalPoint(),
      SessionManager.getCurrencySymbol(),
      SessionManager.getDateFormat(),
    ]);
    _apiKey = results[0] as String;
    _companyGUID = results[1] as String;
    _userID = results[2] as int;
    _userSessionID = results[3] as String;
    _accessRights = results[4] as List<String>;
    final dp = results[5] as int;
    _salesFmt = NumberFormat('#,##0.${'0' * dp}');
    _currency = results[6] as String;
    final dF = results[7] as String;
    _dateFmt = DateFormat(dF);
    await _loadDoc();
  }

  Future<void> _downloadPdf() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    setState(() => _pdfLoading = true);
    try {
      final bytes = await BaseClient.postBytes(
        ApiEndpoints.getCollectionReport,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': widget.docID,
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
    if (!_accessRights.contains('COLLECT_DELETE')){
      CommonDialog.showNoAccessRightDialog(context);
      return;
    }
    final confirmed = await CommonDialog.confirmDeleteDialog(context, _doc!.docNo, 'Collection');
    if (confirmed != true) return;

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
          'docID': _doc!.docID,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Collection deleted'),
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
        ApiEndpoints.getCollection,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': widget.docID,
        },
      );
      setState(() {
        _doc = CollectionDoc.fromJson(json as Map<String, dynamic>);
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
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _doc?.docNo ?? 'Collection',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
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
                        case 'edit':
                          if (!_accessRights.contains('COLLECT_EDIT')) {
                            CommonDialog.showNoAccessRightDialog(context);
                            return;
                          }
                          final updated = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CollectionFormPage(initialDoc: _doc),
                            ),
                          );
                          if (updated == true && mounted) await _loadDoc();
                        case 'pdf':
                          _downloadPdf();
                        case 'delete':
                          if (!_accessRights.contains('COLLECT_DELETE')) {
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
                                style: TextStyle(color: Colors.red)),
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
                    icon: Icon(Icons.receipt_long_outlined, size: 18),
                    text: 'Orders',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.attachment_outlined, size: 18),
                    text: 'Attachment',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                ],
                labelColor: cs.primary,
                unselectedLabelColor:
                    cs.onSurface.withValues(alpha: 0.35),
                indicatorColor: cs.primary,
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
                          _buildOrdersTab(_doc!),
                          _buildAttachmentTab(_doc!),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── Totals summary bar ───────────────────────────────────────────────

  Widget _buildTotalsBar(CollectionDoc doc) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            'Payment Total',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: primary),
          ),
          const Spacer(),
          Text(
            '$_currency ${_salesFmt.format(doc.paymentTotal)}',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: primary),
          ),
        ],
      ),
    );
  }

  // ── Info tab ──────────────────────────────────────────────────────────

  Widget _buildInfoTab(CollectionDoc doc) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    DateTime? docDate;
    try {
      docDate = DateTime.parse(doc.docDate);
    } catch (_) {}

    final addressLines =
        [doc.address1, doc.address2, doc.address3, doc.address4]
            .where((l) => (l ?? '').isNotEmpty)
            .cast<String>()
            .toList();

    return ListView(
      children: [
        DetailSectionHeader(title: 'DOCUMENT'),
        DetailDetailRow(label: 'Doc No', value: doc.docNo),
        DetailDetailRow(label: 'Date', value: docDate != null ? _dateFmt.format(docDate) : doc.docDate,),
        DetailDetailRow(label: 'Sales Agent', value: (doc.salesAgent ?? '').isEmpty ? '-' : doc.salesAgent ?? ''),
        DetailDetailRow(label: 'Reference No', value: (doc.refNo ?? '').isEmpty ? '-' : doc.refNo ?? ''),
        Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text('Payment Type',
                      style: TextStyle(
                          fontSize: 12,
                          color: muted,
                          fontWeight: FontWeight.w500)),
                ),
                Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    doc.paymentType!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        DetailSectionHeader(title: 'CUSTOMER'),
        DetailDetailRow(label: 'Code', value: doc.customerCode),
        DetailDetailRow(label: 'Name', value: doc.customerName),
        if (addressLines.isNotEmpty)
          DetailAddressRow(label: 'Address', lines: addressLines),
        const SizedBox(height: 10),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Orders tab ────────────────────────────────────────────────────────

  Widget _buildOrdersTab(CollectionDoc doc) {
    if (doc.collectMappings.isEmpty) {
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
                      .withValues(alpha: 0.18)),
              const SizedBox(height: 14),
              Text(
                'No orders attached',
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
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: doc.collectMappings.length,
      itemBuilder: (_, i) => _OrderMappingCard(
        index: i,
        mapping: doc.collectMappings[i],
        salesFmt: _salesFmt,
        dateFmt: _dateFmt,
        primary: primary,
      ),
    );
  }

  // ── Receipt tab ───────────────────────────────────────────────────────

  Widget _buildAttachmentTab(CollectionDoc doc) {
    if ((doc.image ?? '').isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_outlined,
                  size: 52,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.18)),
              const SizedBox(height: 14),
              Text(
                'No attachment',
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

    try {
      final bytes = base64Decode(doc.image!);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Unable to load image'),
            ),
          ),
        ),
      );
    } catch (_) {
      return const Center(child: Text('Unable to decode image'));
    }
  }

  // ── Error ─────────────────────────────────────────────────────────────

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
            const Text('Failed to load collection',
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
                      .withValues(alpha: 0.4)),
            ),
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
// Mapping card (like _ItemTile in quotation_detail)
// ─────────────────────────────────────────────────────────────────────

class _OrderMappingCard extends StatefulWidget {
  final int index;
  final CollectMapping mapping;
  final NumberFormat salesFmt;
  final DateFormat dateFmt;
  final Color primary;

  const _OrderMappingCard({
    required this.index,
    required this.mapping,
    required this.salesFmt,
    required this.dateFmt,
    required this.primary,
  });

  @override
  State<_OrderMappingCard> createState() => _OrderMappingCardState();
}

class _OrderMappingCardState extends State<_OrderMappingCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = widget.mapping;
    final primary = widget.primary;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);

    DateTime? saleDate;
    try {
      saleDate = DateTime.parse(m.salesDocDate);
    } catch (_) {}

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
              badge,
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: DocNo | Date
                    Row(
                      children: [
                        Text(
                          m.salesDocNo,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: primary),
                        ),
                        const SizedBox(width: 6),
                        const Spacer(),
                        Text(
                          saleDate != null
                              ? widget.dateFmt.format(saleDate)
                              : m.salesDocDate,
                          style: TextStyle(fontSize: 11, color: muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 3: payment amt
                    Row(
                      children: [
                        Text(
                      m.salesAgent ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                        const Spacer(),
                        Text(
                          widget.salesFmt.format(m.editPaymentAmt),
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
                          'Sales Total',
                          widget.salesFmt.format(m.salesFinalTotal),
                          cs,
                          valueColor: muted),
                      const SizedBox(height: 3),
                      breakdownRow(
                          'Outstanding',
                          widget.salesFmt.format(m.editOutstanding),
                          cs,
                          valueColor: m.editOutstanding > 0 ? Mycolor.discountTextColor : muted),
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

