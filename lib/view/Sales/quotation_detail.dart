import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../common/session_manager.dart';
import '../../models/Quotation.dart';

class QuotationDetailPage extends StatefulWidget {
  final int docID;
  const QuotationDetailPage({super.key, required this.docID});

  @override
  State<QuotationDetailPage> createState() => _QuotationDetailPageState();
}

class _QuotationDetailPageState extends State<QuotationDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  QuotationDoc? _doc;
  bool _loading = true;
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
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    await _loadDoc();
  }

  Future<void> _loadDoc() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getQuotation,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': widget.docID,
        },
      );
      setState(() {
        _doc = QuotationDoc.fromJson(json as Map<String, dynamic>);
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
          _doc?.docNo ?? 'Quotation',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_doc != null && _doc!.isVoid)
            Padding(
              padding: const EdgeInsets.only(right: 12),
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
        ],
        bottom: _loading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.info_outline, size: 18),
                    text: 'Details',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.list_alt_outlined, size: 18),
                    text: 'Items',
                    iconMargin: EdgeInsets.only(bottom: 2),
                  ),
                  Tab(
                    icon: Icon(Icons.location_on_outlined, size: 18),
                    text: 'Address',
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
                          _buildDetailsTab(_doc!),
                          _buildItemsTab(_doc!),
                          _buildAddressTab(_doc!),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  // ── Totals summary bar ───────────────────────────────────────────────

  Widget _buildTotalsBar(QuotationDoc doc) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _TotalChip(
              label: 'Subtotal',
              value: 'RM ${_amtFmt.format(doc.subtotal)}',
              primary: primary),
          const SizedBox(width: 12),
          _TotalChip(
              label: 'Tax',
              value: 'RM ${_amtFmt.format(doc.taxAmt)}',
              primary: primary),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              Text(
                'RM ${_amtFmt.format(doc.finalTotal)}',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Details tab ──────────────────────────────────────────────────────

  Widget _buildDetailsTab(QuotationDoc doc) {
    DateTime? docDate;
    try {
      docDate = DateTime.parse(doc.docDate);
    } catch (_) {}

    return ListView(
      children: [
        _SectionHeader(title: 'DOCUMENT'),
        _DetailRow(label: 'Doc No', value: doc.docNo),
        _DetailRow(
            label: 'Date',
            value: docDate != null
                ? _dateFmt.format(docDate)
                : doc.docDate),
        if ((doc.description ?? '').isNotEmpty)
          _DetailRow(label: 'Description', value: doc.description!),
        if ((doc.remark ?? '').isNotEmpty)
          _DetailRow(label: 'Remark', value: doc.remark!),
        if ((doc.shippingMethodDescription ?? '').isNotEmpty)
          _DetailRow(
              label: 'Shipping',
              value: doc.shippingMethodDescription!),
        _SectionHeader(title: 'CUSTOMER'),
        _DetailRow(label: 'Code', value: doc.customerCode),
        _DetailRow(label: 'Name', value: doc.customerName),
        if ((doc.attention ?? '').isNotEmpty)
          _DetailRow(label: 'Attention', value: doc.attention!),
        if ((doc.phone ?? '').isNotEmpty)
          _DetailRow(label: 'Phone', value: doc.phone!),
        if ((doc.fax ?? '').isNotEmpty)
          _DetailRow(label: 'Fax', value: doc.fax!),
        if ((doc.email ?? '').isNotEmpty)
          _DetailRow(label: 'Email', value: doc.email!),
        if ((doc.salesAgent ?? '').isNotEmpty) ...[
          _SectionHeader(title: 'SALES'),
          _DetailRow(label: 'Sales Agent', value: doc.salesAgent!),
        ],
      ],
    );
  }

  // ── Items tab ────────────────────────────────────────────────────────

  Widget _buildItemsTab(QuotationDoc doc) {
    if (doc.quotationDetails.isEmpty) {
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

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: doc.quotationDetails.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, i) =>
          _ItemTile(line: doc.quotationDetails[i], amtFmt: _amtFmt, qtyFmt: _qtyFmt),
    );
  }

  // ── Address tab ──────────────────────────────────────────────────────

  Widget _buildAddressTab(QuotationDoc doc) {
    final billingLines = [
      doc.address1, doc.address2, doc.address3, doc.address4,
    ].where((l) => (l ?? '').isNotEmpty).toList();

    final deliveryLines = [
      doc.deliverAddr1, doc.deliverAddr2, doc.deliverAddr3, doc.deliverAddr4,
    ].where((l) => (l ?? '').isNotEmpty).toList();

    return ListView(
      children: [
        if (billingLines.isNotEmpty) ...[
          _SectionHeader(title: 'BILLING ADDRESS'),
          ...billingLines.map((l) => _AddressLine(text: l!)),
        ],
        if (deliveryLines.isNotEmpty) ...[
          _SectionHeader(title: 'DELIVERY ADDRESS'),
          ...deliveryLines.map((l) => _AddressLine(text: l!)),
        ],
        if (billingLines.isEmpty && deliveryLines.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(48),
              child: Text(
                'No address information',
                style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4)),
              ),
            ),
          ),
      ],
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
            const Text('Failed to load quotation',
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
// Item tile
// ─────────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final QuotationDetailLine line;
  final NumberFormat amtFmt;
  final NumberFormat qtyFmt;

  const _ItemTile(
      {required this.line, required this.amtFmt, required this.qtyFmt});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.stockCode,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line.description,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'RM ${amtFmt.format(line.total)}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Chip(label: '${qtyFmt.format(line.qty)} ${line.uom}'),
              const SizedBox(width: 8),
              _Chip(label: 'RM ${amtFmt.format(line.unitPrice)}/unit'),
              if (line.discount > 0) ...[
                const SizedBox(width: 8),
                _Chip(
                    label: '${qtyFmt.format(line.discount)}% disc',
                    color: Colors.orange),
              ],
              if ((line.taxCode ?? '').isNotEmpty) ...[
                const SizedBox(width: 8),
                _Chip(label: line.taxCode!, color: Colors.teal),
              ],
            ],
          ),
          if ((line.location ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 12, color: muted),
                const SizedBox(width: 3),
                Text(line.location!,
                    style: TextStyle(fontSize: 12, color: muted)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color? color;
  const _Chip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: c),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────

class _TotalChip extends StatelessWidget {
  final String label;
  final String value;
  final Color primary;
  const _TotalChip(
      {required this.label, required this.value, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5))),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
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
          fontSize: 11,
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

class _AddressLine extends StatelessWidget {
  final String text;
  const _AddressLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
      ),
    );
  }
}
