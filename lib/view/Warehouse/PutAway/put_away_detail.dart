import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';
import '../../../models/put_away.dart';

class PutAwayDetailPage extends StatefulWidget {
  final int docID;
  const PutAwayDetailPage({super.key, required this.docID});

  @override
  State<PutAwayDetailPage> createState() => _PutAwayDetailPageState();
}

class _PutAwayDetailPageState extends State<PutAwayDetailPage> {
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';
  List<String> _accessRights = [];

  PutAwayListItem? _doc;
  bool _loading = true;
  String? _error;

  final _dateFmt = DateFormat('dd MMM yyyy, HH:mm');
  final _qtyFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _init();
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

  Future<void> _loadDoc() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getPutAway,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': widget.docID,
        },
      );
      setState(() {
        _doc = PutAwayListItem.fromJson(json as Map<String, dynamic>);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _deletePutAway() async {
    final confirmed = await _confirmDelete(_doc!.docNo);
    if (confirmed != true) return;
    try {
      await BaseClient.post(
        ApiEndpoints.removePutAway,
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
            content: Text(e is BadRequestException ? e.message : 'Failed to delete: $e'),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                child: const Icon(Icons.delete_outline_rounded, size: 32, color: Colors.red),
              ),
              const SizedBox(height: 16),
              const Text('Delete Put Away',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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
              Divider(height: 1, color: cs.outline.withValues(alpha: 0.15)),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.only(bottomLeft: Radius.circular(20))),
                        ),
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.6))),
                      ),
                    ),
                    VerticalDivider(width: 1, color: cs.outline.withValues(alpha: 0.15)),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.only(bottomRight: Radius.circular(20))),
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
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

  void _showNoAccessDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Access Denied'),
        content: const Text('You do not have the access right to perform this action.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _doc?.docNo ?? 'Put Away',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_doc != null)
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  if (!_accessRights.contains('PUTAWAY_DELETE')) {
                    _showNoAccessDialog();
                    return;
                  }
                  await _deletePutAway();
                }
              },
              itemBuilder: (_) => [
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
      ),
      body: _loading
          ? const Center(child: DotsLoading())
          : _error != null
              ? _buildError()
              : _buildContent(_doc!),
    );
  }

  Widget _buildContent(PutAwayListItem doc) {
    DateTime? createdDate;
    try {
      createdDate = DateTime.parse(doc.createdDateTime);
    } catch (_) {}

    return ListView(
      children: [
        _SectionHeader(title: 'DOCUMENT'),
        _DetailRow(label: 'Doc No', value: doc.docNo),
        _DetailRow(
          label: 'Date',
          value: createdDate != null ? _dateFmt.format(createdDate) : doc.createdDateTime,
        ),
        if ((doc.receivingDocNo ?? '').isNotEmpty)
          _DetailRow(label: 'GRN Ref', value: doc.receivingDocNo!),

        const SizedBox(height: 4),
        _SectionHeader(title: 'STOCK'),
        _DetailRow(label: 'Stock Code', value: doc.stockCode),
        _DetailRow(label: 'Description', value: doc.stockDescription),
        _DetailRow(label: 'UOM', value: doc.uom),
        _DetailRow(label: 'Qty', value: _qtyFmt.format(doc.qty)),
        if ((doc.batchNo ?? '').isNotEmpty)
          _DetailRow(label: 'Batch No', value: doc.batchNo!),

        const SizedBox(height: 4),
        _SectionHeader(title: 'LOCATION'),
        _DetailRow(label: 'Location', value: doc.location),
        _DetailRow(label: 'Storage', value: doc.storageCode),

        const SizedBox(height: 24),
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
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.6)),
            const SizedBox(height: 14),
            const Text('Failed to load put away',
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
// Reusable widgets
// ─────────────────────────────────────────────────────────────────────

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
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
