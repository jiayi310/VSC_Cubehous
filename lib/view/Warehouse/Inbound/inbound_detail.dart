import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';
import '../../../models/inbound.dart';
import '../../../common/my_color.dart';
import '../../Common/decoration.dart';

class InboundDetailPage extends StatefulWidget {
  final int docID;
  const InboundDetailPage({super.key, required this.docID});

  @override
  State<InboundDetailPage> createState() => _InboundDetailPageState();
}

class _InboundDetailPageState extends State<InboundDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _scrollControllers = List.generate(2, (_) => ScrollController());

  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  InboundDoc? _doc;
  bool _loading = true;
  String? _error;

  late NumberFormat _amtFmt;
  late NumberFormat _qtyFmt;
  late DateFormat _dateFmt;
  String _imageMode = 'show';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
      SessionManager.getSalesDecimalPoint(),
      SessionManager.getQuantityDecimalPoint(),
      SessionManager.getDateFormat(),
      SessionManager.getImageMode(),
    ]);
    _apiKey = results[0] as String;
    _companyGUID = results[1] as String;
    _userID = results[2] as int;
    _userSessionID = results[3] as String;
    final dp = results[4] as int;
    _amtFmt = NumberFormat('#,##0.${'0' * dp}');
    final dp2 = results[5] as int;
    _qtyFmt = NumberFormat('#,##0.${'0' * dp2}');
    final dF = results[6] as String;
    _dateFmt = DateFormat(dF);
    _imageMode = results[7] as String;
    await _loadDoc();
  }

  Future<void> _loadDoc() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getInbound,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': widget.docID,
        },
      );
      if (mounted) {
        setState(() {
          _doc = InboundDoc.fromJson(json as Map<String, dynamic>);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: _scrollToTop,
          child: SizedBox(
            width: double.infinity,
            child: Text(
              _doc?.docNo ?? 'Inbound',
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          if (_doc != null && _doc!.isVoid)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: const Text('VOID',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.red,
                          letterSpacing: 0.5)),
                ),
              ),
            ),
        ],
        bottom: _loading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline, size: 18), text: 'Info', iconMargin: EdgeInsets.only(bottom: 2)),
                  Tab(icon: Icon(Icons.list_alt_outlined, size: 18), text: 'Items', iconMargin: EdgeInsets.only(bottom: 2)),
                ],
                labelColor: cs.primary,
                unselectedLabelColor: cs.onSurface.withValues(alpha: 0.35),
                indicatorColor: cs.primary,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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

  Widget _buildTotalsBar(InboundDoc doc) {
    final cs = Theme.of(context).colorScheme;
    final typeColor = doc.docType == 'GRN'
        ? const Color(0xFF1565C0)
        : doc.docType == 'PUT'
            ? const Color(0xFF00695C)
            : cs.primary;
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(doc.docType,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: typeColor, letterSpacing: 0.4)),
          ),
          const SizedBox(width: 10),
          Text('${doc.lines.length} item${doc.lines.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildInfoTab(InboundDoc doc) {
    DateTime? docDate;
    try { docDate = DateTime.parse(doc.docDate); } catch (_) {}

    return ListView(
      controller: _scrollControllers[0],
      children: [
        DetailSectionHeader(title: 'DOCUMENT'),
        DetailDetailRow(label: 'Doc No', value: doc.docNo),
        DetailDetailRow(label: 'Type', value: doc.docType),
        DetailDetailRow(label: 'Date', value: docDate != null ? _dateFmt.format(docDate) : doc.docDate),
        if ((doc.description ?? '').isNotEmpty)
          DetailDetailRow(label: 'Description', value: doc.description!),
        if ((doc.remark ?? '').isNotEmpty)
          DetailDetailRow(label: 'Remark', value: doc.remark!),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildItemsTab(InboundDoc doc) {
    if (doc.lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.18)),
              const SizedBox(height: 12),
              Text('No items',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollControllers[1],
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: doc.lines.length,
      itemBuilder: (_, i) => _ItemTile(
        index: i,
        line: doc.lines[i],
        amtFmt: _amtFmt,
        qtyFmt: _qtyFmt,
        imageMode: _imageMode,
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
                size: 52, color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            const Text('Failed to load document',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
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

// ── Item tile ─────────────────────────────────────────────────────────

class _ItemTile extends StatefulWidget {
  final int index;
  final InboundDetailLine line;
  final NumberFormat amtFmt;
  final NumberFormat qtyFmt;
  final String imageMode;

  const _ItemTile({
    required this.index,
    required this.line,
    required this.amtFmt,
    required this.qtyFmt,
    required this.imageMode,
  });

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  bool _expanded = false;

  static String _fmtNum(double v) {
    if (v == v.truncateToDouble()) return v.toStringAsFixed(0);
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final line = widget.line;
    final discAmt = line.qty * line.unitPrice - line.total + line.taxAmt;

    final badge = Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text('${widget.index + 1}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primary)),
      ),
    );

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: 50, height: 50, child: ItemImage(base64: line.image)),
    );

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.imageMode == 'show' ? image : badge,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: stockCode | qty
                      Row(children: [
                        Text(line.stockCode,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primary)),
                        const Spacer(),
                        Text(widget.qtyFmt.format(line.qty),
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primary)),
                      ]),
                      const SizedBox(height: 3),
                      // Row 2: description
                      Text(line.description,
                          style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.55)),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      // Row 3: UOM + badges | total
                      Row(children: [
                        Text(line.uom,
                            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                        if (discAmt > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('DISC',
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
                          ),
                        ],
                        if ((line.taxCode ?? '').isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00897B).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(line.taxCode!,
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF00897B), fontWeight: FontWeight.w600)),
                          ),
                        ],
                        const Spacer(),
                        Text(widget.amtFmt.format(line.total),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Divider(color: cs.outline.withValues(alpha: 0.15), height: 1),
              const SizedBox(height: 8),
              if ((line.location ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: breakdownRow('Location', line.location!, cs),
                ),
              breakdownRow('Subtotal', widget.amtFmt.format(line.qty * line.unitPrice), cs),
              if (discAmt > 0) ...[
                const SizedBox(height: 3),
                breakdownRow('Discount', '- ${widget.amtFmt.format(discAmt)}', cs,
                    labelColor: Mycolor.discountTextColor, valueColor: Mycolor.discountTextColor),
              ],
              if ((line.taxCode ?? '').isNotEmpty) ...[
                const SizedBox(height: 3),
                breakdownRow('Tax (${_fmtNum(line.taxRate)}%)', '+ ${widget.amtFmt.format(line.taxAmt)}', cs,
                    labelColor: Mycolor.taxTextColor, valueColor: Mycolor.taxTextColor),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
