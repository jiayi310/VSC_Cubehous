import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../common/session_manager.dart';
import '../../models/collection.dart';

class CollectionDetailPage extends StatefulWidget {
  final int docID;

  const CollectionDetailPage({super.key, required this.docID});

  @override
  State<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends State<CollectionDetailPage> {
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  CollectionDoc? _doc;
  bool _isLoading = true;
  String? _error;

  final _dateFmt = DateFormat('dd MMM yyyy');
  final _amtFmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    await _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getCollection,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': widget.docID,
        },
      );
      final doc = CollectionDoc.fromJson(response as Map<String, dynamic>);
      setState(() {
        _doc = doc;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          doc != null ? doc.docNo : 'Collection Detail',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (doc != null && doc.isVoid)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
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
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: DotsLoading());
    if (_error != null) return _buildError();
    if (_doc == null) return const Center(child: Text('No data found'));
    return _buildContent(_doc!);
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
                color:
                    Theme.of(context).colorScheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            const Text('Failed to load collection',
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
              onPressed: _fetchDetail,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(CollectionDoc doc) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    DateTime? parsedDate;
    try {
      parsedDate = DateTime.parse(doc.docDate);
    } catch (_) {}

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Summary Card ──────────────────────────────
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Summary',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary)),
                  const SizedBox(height: 12),
                  _InfoRow(
                    icon: Icons.tag_outlined,
                    label: 'Document No',
                    value: doc.docNo,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: parsedDate != null
                        ? _dateFmt.format(parsedDate)
                        : doc.docDate,
                  ),
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.person_outline,
                    label: 'Customer',
                    value: doc.customerName,
                  ),
                  if ((doc.salesAgent ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.badge_outlined,
                      label: 'Sales Agent',
                      value: doc.salesAgent!,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.payment_outlined, size: 16, color: muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Payment Type',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: muted)),
                            const SizedBox(height: 4),
                            if ((doc.paymentType ?? '').isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  doc.paymentType!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: primary,
                                  ),
                                ),
                              )
                            else
                              Text('—',
                                  style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((doc.refNo ?? '').isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.receipt_long_outlined,
                      label: 'Reference No',
                      value: doc.refNo!,
                    ),
                  ],
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Payment',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: muted)),
                      Text(
                        'RM ${_amtFmt.format(doc.paymentTotal)}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Image Section ─────────────────────────────
          if ((doc.image ?? '').isNotEmpty)
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: Icon(Icons.image_outlined, color: primary),
                title: const Text('Payment Receipt',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Builder(
                        builder: (_) {
                          try {
                            final bytes = base64Decode(doc.image!);
                            return Image.memory(
                              bytes,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Unable to load image'),
                              ),
                            );
                          } catch (_) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Unable to decode image'),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if ((doc.image ?? '').isNotEmpty) const SizedBox(height: 12),

          // ── Applied Sales Orders ─────────────────────
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Applied to Sales Orders',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary)),
                  const SizedBox(height: 12),
                  if (doc.collectMappings.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No applied sales orders',
                          style: TextStyle(fontSize: 13, color: muted),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: doc.collectMappings.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (context, i) {
                        final m = doc.collectMappings[i];
                        DateTime? saleDate;
                        try {
                          saleDate = DateTime.parse(m.salesDocDate);
                        } catch (_) {}
                        return _MappingRow(
                          mapping: m,
                          saleDate: saleDate,
                          dateFmt: _dateFmt,
                          amtFmt: _amtFmt,
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Mapping Row
// ─────────────────────────────────────────────────────────────────────

class _MappingRow extends StatelessWidget {
  final CollectMapping mapping;
  final DateTime? saleDate;
  final DateFormat dateFmt;
  final NumberFormat amtFmt;

  const _MappingRow({
    required this.mapping,
    required this.saleDate,
    required this.dateFmt,
    required this.amtFmt,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mapping.salesDocNo,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                saleDate != null
                    ? dateFmt.format(saleDate!)
                    : mapping.salesDocDate,
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Paid: RM ${amtFmt.format(mapping.editPaymentAmt)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Remaining: RM ${amtFmt.format(mapping.editOutstanding)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: mapping.editOutstanding > 0
                    ? Colors.orange
                    : muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Info Row
// ─────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: muted),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: muted)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
