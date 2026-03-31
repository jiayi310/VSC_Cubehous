import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/date_pill.dart';
import '../../common/session_manager.dart';
import '../../models/customer.dart';
import '../Common/multi_customer_picker_page.dart';

// ─────────────────────────────────────────────
// Outstanding Sales List Item Model
// ─────────────────────────────────────────────

class _OutstandingSalesItem {
  final int docID;
  final String docNo;
  final String docDate;
  final String customerCode;
  final String customerName;
  final String? salesAgent;
  final double subtotal;
  final double taxAmt;
  final double finalTotal;
  final double paymentTotal;
  final double outstanding;
  final bool isVoid;

  const _OutstandingSalesItem({
    required this.docID,
    required this.docNo,
    required this.docDate,
    required this.customerCode,
    required this.customerName,
    this.salesAgent,
    required this.subtotal,
    required this.taxAmt,
    required this.finalTotal,
    required this.paymentTotal,
    required this.outstanding,
    required this.isVoid,
  });

  static double _toD(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  factory _OutstandingSalesItem.fromJson(Map<String, dynamic> json) =>
      _OutstandingSalesItem(
        docID: (json['docID'] as int?) ?? 0,
        docNo: (json['docNo'] as String?) ?? '',
        docDate: (json['docDate'] as String?) ?? '',
        customerCode: (json['customerCode'] as String?) ?? '',
        customerName: (json['customerName'] as String?) ?? '',
        salesAgent: json['salesAgent'] as String?,
        subtotal: _toD(json['subtotal']),
        taxAmt: _toD(json['taxAmt']),
        finalTotal: _toD(json['finalTotal']),
        paymentTotal: _toD(json['paymentTotal']),
        outstanding: _toD(json['outstanding']),
        isVoid: (json['isVoid'] as bool?) ?? false,
      );
}

// ─────────────────────────────────────────────
// Report Page
// ─────────────────────────────────────────────

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  final bool _isFilterByCreatedDateTime = true;
  List<Customer> _selectedCustomers = [];

  bool _outstandingLoading = false;
  bool _salesDtlLoading = false;
  bool _salesOutstandingLoading = false;

  late DateFormat _dateFmt;

  @override
  void initState() {
    super.initState();
    _dateFmt = DateFormat('dd MMM yyyy');
    _loadSession();
  }

  Future<void> _loadSession() async {
    final results = await Future.wait([
      SessionManager.getApiKey(),
      SessionManager.getCompanyGUID(),
      SessionManager.getUserID(),
      SessionManager.getUserSessionID(),
    ]);
    if (mounted) {
      setState(() {
        _apiKey = results[0] as String;
        _companyGUID = results[1] as String;
        _userID = results[2] as int;
        _userSessionID = results[3] as String;
      });
    }
  }

  Map<String, dynamic> get _baseBody => {
        'apiKey': _apiKey,
        'companyGUID': _companyGUID,
        'userID': _userID,
        'userSessionID': _userSessionID,
        'isFilterByCreatedDateTime': _isFilterByCreatedDateTime,
        'fromDate': _fromDate.toIso8601String(),
        'toDate': DateTime(
                _toDate.year, _toDate.month, _toDate.day, 23, 59, 59)
            .toIso8601String(),
        'customerIdList': _selectedCustomers.isEmpty
            ? []
            : _selectedCustomers.map((c) => c.customerID).toList(),
      };

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_fromDate.isAfter(_toDate)) _toDate = picked;
      } else {
        _toDate = picked;
        if (_toDate.isBefore(_fromDate)) _fromDate = picked;
      }
    });
  }

  void _openCustomerPicker() async {
    if (_apiKey.isEmpty) return;
    final result = await Navigator.of(context).push<List<Customer>>(
      MaterialPageRoute(
        builder: (_) => MultiCustomerPickerPage(
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
          initialSelected: List.from(_selectedCustomers),
        ),
      ),
    );
    if (result != null) setState(() => _selectedCustomers = result);
  }

  bool _requireCustomer() {
    if (_selectedCustomers.isNotEmpty) return true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Please select at least one customer.'),
        behavior: SnackBarBehavior.floating,
      ));
    return false;
  }

  Future<void> _generateOutstandingSalesList() async {
    if (!_requireCustomer()) return;
    setState(() => _outstandingLoading = true);
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getOutstandingSalesList,
        body: _baseBody,
      );
      if (!mounted) return;
      final items = (response as List<dynamic>)
          .map((e) =>
              _OutstandingSalesItem.fromJson(e as Map<String, dynamic>))
          .toList();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => _OutstandingSalesResultPage(
          items: items,
          fromDate: _fromDate,
          toDate: _toDate,
          dateFmt: _dateFmt,
        ),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } finally {
      if (mounted) setState(() => _outstandingLoading = false);
    }
  }

  Future<void> _generateSalesDtlReport() async {
    if (!_requireCustomer()) return;
    setState(() => _salesDtlLoading = true);
    try {
      final bytes = await BaseClient.postBytes(
        ApiEndpoints.getSalesDtlListingReport,
        body: _baseBody,
      );
      await _openPdf(bytes, 'SalesDtlListing');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Failed to generate report: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } finally {
      if (mounted) setState(() => _salesDtlLoading = false);
    }
  }

  Future<void> _generateSalesOutstandingReport() async {
    if (!_requireCustomer()) return;
    setState(() => _salesOutstandingLoading = true);
    try {
      final bytes = await BaseClient.postBytes(
        ApiEndpoints.getSalesOutstandingListReport,
        body: _baseBody,
      );
      await _openPdf(bytes, 'SalesOutstanding');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Failed to generate report: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } finally {
      if (mounted) setState(() => _salesOutstandingLoading = false);
    }
  }

  Future<void> _openPdf(List<int> bytes, String prefix) async {
    Directory dir;
    if (Platform.isAndroid) {
      dir = (await getExternalStorageDirectory()) ??
          await getTemporaryDirectory();
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    final timestamp = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    final file = File('${dir.path}/${prefix}_$timestamp.pdf');
    await file.writeAsBytes(bytes);
    await OpenFilex.open(file.path);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: DatePill(
                    label: 'From',
                    date: _dateFmt.format(_fromDate),
                    onTap: () => _pickDate(isFrom: true),
                    primary: primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DatePill(
                    label: 'To',
                    date: _dateFmt.format(_toDate),
                    onTap: () => _pickDate(isFrom: false),
                    primary: primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // ── Customer Filter ───────────────────────────
          _buildCustomerFilter(primary, cs),
          const SizedBox(height: 16),

          // ── Report Cards ─────────────────────────────
          _ReportCard(
            icon: Icons.list_alt_rounded,
            iconColor: const Color(0xFF1565C0),
            title: 'Outstanding Sales List',
            description:
                'View all unpaid sales orders with their outstanding balances.',
            isPdf: false,
            isLoading: _outstandingLoading,
            onGenerate: _generateOutstandingSalesList,
          ),
          const SizedBox(height: 12),
          _ReportCard(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF2E7D32),
            title: 'Sales Detail Listing',
            description:
                'Generate a detailed PDF listing of all sales within the selected period.',
            isPdf: true,
            isLoading: _salesDtlLoading,
            onGenerate: _generateSalesDtlReport,
          ),
          const SizedBox(height: 12),
          _ReportCard(
            icon: Icons.account_balance_wallet_outlined,
            iconColor: const Color(0xFFE65100),
            title: 'Sales Outstanding Report',
            description:
                'Generate a PDF report of all outstanding sales balances.',
            isPdf: true,
            isLoading: _salesOutstandingLoading,
            onGenerate: _generateSalesOutstandingReport,
          ),
        ],
      ),
    );
  }

  void _showSelectedCustomersSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SelectedCustomersSheet(
        selected: _selectedCustomers,
        onRemove: (c) => setState(() => _selectedCustomers.remove(c)),
        onAddMore: () {
          Navigator.pop(context);
          _openCustomerPicker();
        },
      ),
    );
  }

  Widget _buildCustomerFilter(Color primary, ColorScheme cs) {
    final count = _selectedCustomers.length;
    final hasSelection = count > 0;

    return InkWell(
      onTap: hasSelection ? _showSelectedCustomersSheet : _openCustomerPicker,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasSelection
                ? primary.withValues(alpha: 0.35)
                : cs.outline.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 25,
              color: primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasSelection ? 'Customers *' : 'Select Customers *',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (hasSelection)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count selected',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            if (hasSelection)
              GestureDetector(
                onTap: () => setState(() => _selectedCustomers.clear()),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onSurface.withValues(alpha: 0.35),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Report Card Widget
// ─────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool isPdf;
  final bool isLoading;
  final VoidCallback onGenerate;

  const _ReportCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.isPdf,
    required this.isLoading,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cardTheme = Theme.of(context).cardTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: (cardTheme.color ?? cs.surface).withValues(alpha: 0.5),
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 26, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    if (isPdf) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('PDF',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(description,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.55))),
                const SizedBox(height: 10),
                SizedBox(
                  height: 32,
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : onGenerate,
                    icon: isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            isPdf
                                ? Icons.download_rounded
                                : Icons.open_in_new_rounded,
                            size: 14),
                    label: Text(
                      isLoading
                          ? 'Generating...'
                          : isPdf
                              ? 'Download PDF'
                              : 'View Report',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Outstanding Sales Result Page
// ─────────────────────────────────────────────

class _OutstandingSalesResultPage extends StatelessWidget {
  final List<_OutstandingSalesItem> items;
  final DateTime fromDate;
  final DateTime toDate;
  final DateFormat dateFmt;

  const _OutstandingSalesResultPage({
    required this.items,
    required this.fromDate,
    required this.toDate,
    required this.dateFmt,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    final amtFmt = NumberFormat('#,##0.00');
    final docDateFmt = DateFormat('dd MMM yyyy');

    double totalOutstanding = items.fold(0.0, (s, i) => s + i.outstanding);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Outstanding Sales',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Text(
              '${dateFmt.format(fromDate)}  –  ${dateFmt.format(toDate)}  ·  ${items.length} record${items.length == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.5)),
            ),
          ),
        ),
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 52,
                      color: cs.onSurface.withValues(alpha: 0.2)),
                  const SizedBox(height: 12),
                  Text('No outstanding sales found',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.4))),
                ],
              ),
            )
          : Column(
              children: [
                // ── Total Summary Bar ─────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.06),
                    border: Border(
                        bottom: BorderSide(
                            color:
                                cs.outline.withValues(alpha: 0.15))),
                  ),
                  child: Row(
                    children: [
                      Text('Total Outstanding',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color:
                                  cs.onSurface.withValues(alpha: 0.6))),
                      const Spacer(),
                      Text(
                        amtFmt.format(totalOutstanding),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: primary),
                      ),
                    ],
                  ),
                ),
                // ── List ─────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      final dateStr = item.docDate.isNotEmpty
                          ? (() {
                              try {
                                return docDateFmt.format(
                                    DateTime.parse(item.docDate));
                              } catch (_) {
                                return item.docDate;
                              }
                            })()
                          : '';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(
                              12, 10, 12, 10),
                          decoration: BoxDecoration(
                            color: Theme.of(ctx)
                                .cardTheme
                                .color
                                ?.withValues(alpha: 0.5) ??
                                cs.surface.withValues(alpha: 0.5),
                            border: Border.all(
                                color: cs.outline
                                    .withValues(alpha: 0.18)),
                            borderRadius:
                                BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(item.docNo,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight:
                                              FontWeight.w700,
                                          color: primary)),
                                  if (item.isVoid) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 5,
                                              vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: const Text('VOID',
                                          style: TextStyle(
                                              fontSize: 9,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: Colors.red)),
                                    ),
                                  ],
                                  const Spacer(),
                                  Text(dateStr,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurface
                                              .withValues(
                                                  alpha: 0.5))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(item.customerName,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                              Text(item.customerCode,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: primary.withValues(
                                          alpha: 0.7))),
                              if (item.salesAgent != null &&
                                  item.salesAgent!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(item.salesAgent!,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.45))),
                              ],
                              const SizedBox(height: 10),
                              const Divider(height: 1),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _summaryCol('Total',
                                      amtFmt.format(item.finalTotal),
                                      cs),
                                  _summaryCol('Paid',
                                      amtFmt.format(item.paymentTotal),
                                      cs),
                                  _summaryCol(
                                    'Outstanding',
                                    amtFmt.format(item.outstanding),
                                    cs,
                                    valueColor: item.outstanding > 0
                                        ? Colors.orange
                                        : null,
                                    bold: true,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _summaryCol(String label, String value, ColorScheme cs,
      {Color? valueColor, bool bold = false}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.45))),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w500,
                  color: valueColor ??
                      cs.onSurface.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Selected Customers Bottom Sheet
// ─────────────────────────────────────────────

class _SelectedCustomersSheet extends StatefulWidget {
  final List<Customer> selected;
  final void Function(Customer) onRemove;
  final VoidCallback onAddMore;

  const _SelectedCustomersSheet({
    required this.selected,
    required this.onRemove,
    required this.onAddMore,
  });

  @override
  State<_SelectedCustomersSheet> createState() =>
      _SelectedCustomersSheetState();
}

class _SelectedCustomersSheetState extends State<_SelectedCustomersSheet> {
  late List<Customer> _list;

  @override
  void initState() {
    super.initState();
    _list = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollCtrl) => Material(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 12),
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
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  Text(
                    '${_list.length} Customer${_list.length == 1 ? '' : 's'} Selected',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: widget.onAddMore,
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit',
                        style: TextStyle(fontSize: 13)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // Customer list
            Expanded(
              child: _list.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_outline_rounded,
                              size: 44,
                              color: cs.onSurface.withValues(alpha: 0.2)),
                          const SizedBox(height: 10),
                          Text('No customers selected',
                              style: TextStyle(
                                  color: cs.onSurface
                                      .withValues(alpha: 0.4))),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _list.length,
                      itemBuilder: (ctx, i) {
                        final c = _list[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                primary.withValues(alpha: 0.1),
                            child: Text(
                              c.name.isNotEmpty
                                  ? c.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(c.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                          subtitle: Text(c.customerCode,
                              style: TextStyle(
                                  fontSize: 12, color: primary)),
                          trailing: IconButton(
                            icon: const Icon(Icons.close_rounded,
                                size: 18),
                            color: cs.onSurface.withValues(alpha: 0.45),
                            onPressed: () {
                              setState(() => _list.remove(c));
                              widget.onRemove(c);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
