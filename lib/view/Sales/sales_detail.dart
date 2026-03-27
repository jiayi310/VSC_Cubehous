import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../common/status_badge.dart';
import '../../common/session_manager.dart';
import '../../models/sales.dart';

class SalesDetailPage extends StatefulWidget {
  final int docID;
  const SalesDetailPage({super.key, required this.docID});

  @override
  State<SalesDetailPage> createState() => _SalesDetailPageState();
}

class _SalesDetailPageState extends State<SalesDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  SalesDoc? _doc;
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
        title: Text(
          _doc?.docNo ?? 'Sales Order',
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
                labelStyle:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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

  // ── Totals bar ───────────────────────────────────────────────────────

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
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500)),
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
          if (doc.outstanding > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paid: RM ${_amtFmt.format(doc.paymentTotal)}',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500),
                ),
                Text(
                  'Outstanding: RM ${_amtFmt.format(doc.outstanding)}',
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

  // ── Details tab ──────────────────────────────────────────────────────

  Widget _buildDetailsTab(SalesDoc doc) {
    DateTime? docDate;
    try {
      docDate = DateTime.parse(doc.docDate);
    } catch (_) {}

    return ListView(
      children: [
        _SectionHeader(title: 'DOCUMENT'),
        _InfoRow(
            icon: Icons.tag_outlined,
            label: 'Doc No',
            value: doc.docNo),
        _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Doc Date',
            value: docDate != null ? _dateFmt.format(docDate) : doc.docDate),
        if ((doc.description ?? '').isNotEmpty)
          _InfoRow(
              icon: Icons.notes_outlined,
              label: 'Description',
              value: doc.description!),
        if ((doc.remark ?? '').isNotEmpty)
          _InfoRow(
              icon: Icons.comment_outlined,
              label: 'Remark',
              value: doc.remark!),
        if ((doc.qtDocNo ?? '').isNotEmpty)
          _InfoRow(
              icon: Icons.receipt_long_outlined,
              label: 'Quotation Ref',
              value: doc.qtDocNo!),
        if ((doc.shippingMethodDescription ?? '').isNotEmpty)
          _InfoRow(
              icon: Icons.local_shipping_outlined,
              label: 'Shipping',
              value: doc.shippingMethodDescription!),
        if (doc.isPicking || doc.isPacking) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                if (doc.isPicking)
                  StatusBadge(label: 'Picking', color: Colors.blue),
                if (doc.isPicking && doc.isPacking)
                  const SizedBox(width: 8),
                if (doc.isPacking)
                  StatusBadge(label: 'Packing', color: Colors.purple),
              ],
            ),
          ),
        ],
        _SectionHeader(title: 'CUSTOMER'),
        _InfoRow(
            icon: Icons.badge_outlined,
            label: 'Customer Code',
            value: doc.customerCode),
        _InfoRow(
            icon: Icons.person_outline,
            label: 'Customer Name',
            value: doc.customerName),
        if ((doc.salesAgent ?? '').isNotEmpty)
          _InfoRow(
              icon: Icons.support_agent_outlined,
              label: 'Sales Agent',
              value: doc.salesAgent!),
        if ((doc.phone ?? '').isNotEmpty)
          _InfoRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: doc.phone!),
        if ((doc.email ?? '').isNotEmpty)
          _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: doc.email!),
      ],
    );
  }

  // ── Items tab ────────────────────────────────────────────────────────

  Widget _buildItemsTab(SalesDoc doc) {
    if (doc.salesDetails.isEmpty) {
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
      itemCount: doc.salesDetails.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color:
            Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
      ),
      itemBuilder: (context, i) => _ItemTile(
          line: doc.salesDetails[i],
          amtFmt: _amtFmt,
          qtyFmt: _qtyFmt),
    );
  }

  // ── Address tab ──────────────────────────────────────────────────────

  Widget _buildAddressTab(SalesDoc doc) {
    final billingLines = [
      doc.address1,
      doc.address2,
      doc.address3,
      doc.address4,
    ].where((l) => (l ?? '').isNotEmpty).cast<String>().toList();

    final deliveryLines = [
      doc.deliverAddr1,
      doc.deliverAddr2,
      doc.deliverAddr3,
      doc.deliverAddr4,
    ].where((l) => (l ?? '').isNotEmpty).cast<String>().toList();

    return ListView(
      children: [
        _SectionHeader(title: 'BILLING ADDRESS'),
        if (billingLines.isNotEmpty)
          _AddressBlock(
            lines: billingLines,
            phone: doc.phone,
            fax: doc.fax,
            email: doc.email,
            attention: doc.attention,
          )
        else
          _EmptyAddressHint(label: 'No billing address'),
        _SectionHeader(title: 'DELIVERY ADDRESS'),
        if (deliveryLines.isNotEmpty)
          _AddressBlock(
            lines: deliveryLines,
            phone: null,
            fax: null,
            email: null,
            attention: null,
          )
        else
          _EmptyAddressHint(label: 'No delivery address'),
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
            const Text('Failed to load sales order',
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
  final SalesDetailLine line;
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
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _Chip(
                  label:
                      '${qtyFmt.format(line.qty)} ${line.uom}'),
              _Chip(
                  label:
                      'RM ${amtFmt.format(line.unitPrice)}/unit'),
              if (line.discount > 0)
                _Chip(
                    label:
                        '${qtyFmt.format(line.discount)}% disc',
                    color: Colors.orange),
              if ((line.taxCode ?? '').isNotEmpty)
                _Chip(label: line.taxCode!, color: Colors.teal),
              if ((line.location ?? '').isNotEmpty)
                _Chip(
                    label: line.location!,
                    color: muted),
            ],
          ),
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
            style:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
          Icon(icon, size: 16, color: muted),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: muted),
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
  final List<String> lines;
  final String? phone;
  final String? fax;
  final String? email;
  final String? attention;

  const _AddressBlock({
    required this.lines,
    required this.phone,
    required this.fax,
    required this.email,
    required this.attention,
  });

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...lines.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(l,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w400)),
              )),
          if ((attention ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.person_outline, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(attention!,
                  style: TextStyle(fontSize: 13, color: muted)),
            ]),
          ],
          if ((phone ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.phone_outlined, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(phone!,
                  style: TextStyle(fontSize: 13, color: muted)),
            ]),
          ],
          if ((fax ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.fax_outlined, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(fax!, style: TextStyle(fontSize: 13, color: muted)),
            ]),
          ],
          if ((email ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.email_outlined, size: 13, color: muted),
              const SizedBox(width: 4),
              Text(email!,
                  style: TextStyle(fontSize: 13, color: muted)),
            ]),
          ],
        ],
      ),
    );
  }
}

class _EmptyAddressHint extends StatelessWidget {
  final String label;
  const _EmptyAddressHint({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 13,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.35)),
      ),
    );
  }
}
