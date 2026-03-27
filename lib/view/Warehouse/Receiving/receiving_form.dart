import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/direction_chip.dart';
import '../../../common/dots_loading.dart';
import '../../../common/pagination_bar.dart';
import '../../../common/session_manager.dart';
import '../../../models/receiving.dart';
import '../../../models/purchase_order.dart';
import '../../../models/stock.dart';
import '../../Common/decoration.dart';
import '../../Common/Stock/item_picker_page.dart';

// ─────────────────────────────────────────────────────────────────────
// Internal form line model
// ─────────────────────────────────────────────────────────────────────

class _ReceivingLine {
  int dtlID;
  int? stockID;
  int stockBatchID;
  String batchNo;
  String stockCode;
  String description;
  String uom;
  double qty;
  final bool fromPO;
  final TextEditingController qtyCtrl;

  _ReceivingLine({
    this.dtlID = 0,
    this.stockID,
    this.stockBatchID = 0,
    this.batchNo = '',
    required this.stockCode,
    required this.description,
    required this.uom,
    required this.qty,
    this.fromPO = false,
  }) : qtyCtrl = TextEditingController(
            text: NumberFormat('#,##0.##').format(qty));

  void dispose() => qtyCtrl.dispose();
}

// ─────────────────────────────────────────────────────────────────────
// Receiving form page
// ─────────────────────────────────────────────────────────────────────

class ReceivingFormPage extends StatefulWidget {
  const ReceivingFormPage({super.key});

  @override
  State<ReceivingFormPage> createState() => _ReceivingFormPageState();
}

class _ReceivingFormPageState extends State<ReceivingFormPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  // Header state
  DateTime _docDate = DateTime.now();
  ReceivingPurchaseItem? _selectedPO;
  int? _supplierID;
  String _supplierCode = '';
  String _supplierName = '';
  String _address1 = '', _address2 = '', _address3 = '', _address4 = '';
  String _phone = '', _fax = '', _email = '', _attention = '';

  final _descriptionCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  // Line items
  final List<_ReceivingLine> _lines = [];

  bool _isSaving = false;
  bool _isLoadingPO = false;
  bool _scanning = false;
  bool _scanSearching = false;

  // Section expand state
  bool _docExpanded = true;
  bool _supplierExpanded = true;
  bool _itemsExpanded = true;

  final _formScrollCtrl = ScrollController();
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _qtyFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _formScrollCtrl.dispose();
    _descriptionCtrl.dispose();
    _remarkCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      SessionManager.getApiKey(),
      SessionManager.getCompanyGUID(),
      SessionManager.getUserID(),
      SessionManager.getUserSessionID(),
    ]);
    _apiKey = results[0] as String;
    _companyGUID = results[1] as String;
    _userID = results[2] as int;
    _userSessionID = results[3] as String;
    if (mounted) setState(() {});
  }

  // ── PO picker ───────────────────────────────────────────────────

  Future<void> _openPOPicker() async {
    final po = await Navigator.push<ReceivingPurchaseItem>(
      context,
      MaterialPageRoute(
        builder: (_) => _POPickerPage(
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (po != null) await _onPOSelected(po);
  }

  Future<void> _onPOSelected(ReceivingPurchaseItem po) async {
    setState(() {
      _selectedPO = po;
      _isLoadingPO = true;
    });

    try {
      final json = await BaseClient.post(
        ApiEndpoints.getPurchase,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': po.docID,
        },
      );
      final doc = PurchaseDoc.fromJson(json as Map<String, dynamic>);

      // Dispose existing PO-origin lines
      final newLines = <_ReceivingLine>[];
      for (final l in _lines) {
        if (!l.fromPO) {
          newLines.add(l);
        } else {
          l.dispose();
        }
      }

      // Add PO items as pre-filled lines
      for (final pl in doc.purchaseDetails) {
        newLines.add(_ReceivingLine(
          stockID: pl.stockID,
          stockCode: pl.stockCode,
          description: pl.description,
          uom: pl.uom,
          qty: pl.qty,
          fromPO: true,
        ));
      }

      setState(() {
        _supplierID = null;
        _supplierCode = doc.supplierCode;
        _supplierName = doc.supplierName;
        _address1 = doc.address1 ?? '';
        _address2 = doc.address2 ?? '';
        _address3 = doc.address3 ?? '';
        _address4 = doc.address4 ?? '';
        _phone = doc.phone ?? '';
        _fax = doc.fax ?? '';
        _email = doc.email ?? '';
        _attention = doc.attention ?? '';
        _lines
          ..clear()
          ..addAll(newLines);
        _isLoadingPO = false;
      });
    } catch (e) {
      setState(() => _isLoadingPO = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Failed to load PO: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    }
  }

  void _clearPO() {
    setState(() {
      _selectedPO = null;
      // Remove PO-origin lines
      final kept = _lines.where((l) => !l.fromPO).toList();
      for (final l in _lines) {
        if (l.fromPO) l.dispose();
      }
      _lines
        ..clear()
        ..addAll(kept);
      _supplierID = null;
      _supplierCode = '';
      _supplierName = '';
      _address1 = '';
      _address2 = '';
      _address3 = '';
      _address4 = '';
      _phone = '';
      _fax = '';
      _email = '';
      _attention = '';
    });
  }

  // ── Item picker ─────────────────────────────────────────────────

  Future<void> _openItemPicker() async {
    final picked = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemPickerPage(
          module: 'RECEIVING',
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _lines.add(_ReceivingLine(
        stockID: picked.stockID,
        stockCode: picked.stockCode,
        description: picked.description,
        uom: picked.baseUOM,
        qty: 1,
        fromPO: false,
      ));
    });
  }

  // ── Delete line ─────────────────────────────────────────────────

  Future<void> _deleteLine(int index) async {
    final line = _lines[index];
    if (line.fromPO) {
      final confirmed = await _confirmDeletePOItem(line.stockCode);
      if (confirmed != true) return;
    }
    setState(() {
      _lines.removeAt(index).dispose();
    });
  }

  Future<bool?> _confirmDeletePOItem(String stockCode) {
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
                  color: Colors.orange.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    size: 32, color: Colors.orange),
              ),
              const SizedBox(height: 16),
              const Text(
                'Remove PO Item',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'This item ($stockCode) is from the selected PO.\nAre you sure you want to remove it?',
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
                        child: const Text('Remove',
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

  // ── Qty helpers ─────────────────────────────────────────────────

  void _stepQty(_ReceivingLine line, double delta) {
    final newQty = (line.qty + delta).clamp(1.0, double.infinity);
    setState(() {
      line.qty = newQty;
      line.qtyCtrl.text = _qtyFmt.format(newQty);
    });
  }

  void _clampQty(_ReceivingLine line) {
    final val = double.tryParse(
            line.qtyCtrl.text.replaceAll(',', '')) ??
        line.qty;
    final clamped = val < 1.0 ? 1.0 : val;
    setState(() {
      line.qty = clamped;
      line.qtyCtrl.text = _qtyFmt.format(clamped);
    });
  }

  // ── Save ─────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_selectedPO == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Please select a Purchase Order'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Please add at least one item'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final details = _lines
          .map((l) => {
                'dtlID': l.dtlID,
                'stockID': l.stockID ?? 0,
                'stockBatchID': l.stockBatchID,
                'batchNo': l.batchNo,
                'stockCode': l.stockCode,
                'description': l.description,
                'uom': l.uom,
                'qty': l.qty,
              })
          .toList();

      await BaseClient.post(
        ApiEndpoints.createReceiving,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docDate': _docDate.toIso8601String(),
          'supplierID': _supplierID ?? 0,
          'supplierCode': _supplierCode,
          'supplierName': _supplierName,
          'address1': _address1,
          'address2': _address2,
          'address3': _address3,
          'address4': _address4,
          'phone': _phone,
          'fax': _fax,
          'email': _email,
          'attention': _attention,
          'description': _descriptionCtrl.text.trim(),
          'remark': _remarkCtrl.text.trim(),
          'purchaseDocID': _selectedPO?.docID ?? 0,
          'receivingDetails': details,
        },
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('Failed to save: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── QR barcode scan ───────────────────────────────────────────────

  Future<void> _onFormBarcodeDetected(String barcode) async {
    if (_scanSearching) return;
    setState(() {
      _scanning = false;
      _scanSearching = true;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getStockByBarcode,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'search': barcode,
        },
      );
      Stock? found;
      if (response is List && response.isNotEmpty) {
        found = Stock.fromJson(response.first as Map<String, dynamic>);
      } else if (response is Map<String, dynamic>) {
        found = Stock.fromJson(response);
      }
      if (found != null && mounted) {
        setState(() {
          _lines.add(_ReceivingLine(
            stockID: found!.stockID,
            stockCode: found.stockCode,
            description: found.description,
            uom: found.baseUOM,
            qty: 1,
            fromPO: false,
          ));
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('No item found for "$barcode"'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('No item found for "$barcode"'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } finally {
      if (mounted) setState(() => _scanSearching = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Receiving',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          if (_scanSearching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: DotsLoading(dotSize: 6),
            )
          else
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_outlined),
              tooltip: 'Scan Barcode',
              onPressed: () => setState(() => _scanning = true),
            ),
        ],
      ),
      body: _isLoadingPO
          ? const Center(child: DotsLoading())
          : Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: SlidableAutoCloseBehavior(
                        child: SingleChildScrollView(
                          controller: _formScrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDocSection(primary, cs),
                              if (_supplierName.isNotEmpty)
                                _buildSupplierSection(primary, cs),
                              _buildItemsSection(primary, cs),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const DotsLoading(dotSize: 6)
                              : const Text('Save',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_scanning)
                  ScannerOverlay(
                    onDetected: _onFormBarcodeDetected,
                    onClose: () => setState(() => _scanning = false),
                  ),
                if (_scanSearching)
                  Container(
                    color: Colors.black45,
                    child: const Center(child: DotsLoading()),
                  ),
              ],
            ),
    );
  }

  // ── Section header ────────────────────────────────────────────────

  Widget _sectionHeader(IconData icon, String title,
      {required bool expanded, required VoidCallback onToggle, String? badge}) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12),
        child: Row(
          children: [
            Icon(icon, size: 16, color: primary),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: primary,
                    letterSpacing: 0.6)),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(badge,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primary)),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
                child: Divider(
                    color: primary.withValues(alpha: 0.2), thickness: 1)),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: expanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: primary.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Document section ──────────────────────────────────────────────

  Widget _buildDocSection(Color primary, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.receipt_long_outlined, 'DOCUMENT',
            expanded: _docExpanded,
            onToggle: () =>
                setState(() => _docExpanded = !_docExpanded)),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _docExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date picker
                    _FieldLabel(label: 'Date'),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: _FieldBox(
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_dateFmt.format(_docDate),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Description
                    _FieldLabel(label: 'Description'),
                    TextFormField(
                      controller: _descriptionCtrl,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 14),
                      decoration: formInputDeco(context, hint: 'Optional'),
                    ),
                    const SizedBox(height: 12),
                    // Remark
                    _FieldLabel(label: 'Remark'),
                    TextFormField(
                      controller: _remarkCtrl,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 14),
                      decoration: formInputDeco(context, hint: 'Optional'),
                    ),
                    const SizedBox(height: 12),
                    // PO picker
                    _FieldLabel(label: 'PO Ref *'),
                    InkWell(
                      onTap: _openPOPicker,
                      borderRadius: BorderRadius.circular(12),
                      child: _FieldBox(
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _selectedPO != null
                                  ? Text(
                                      _selectedPO!.docNo,
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: primary),
                                    )
                                  : Text(
                                      'Select Purchase Order',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.4)),
                                    ),
                            ),
                            if (_selectedPO != null)
                              GestureDetector(
                                onTap: _clearPO,
                                child: Icon(Icons.close_rounded,
                                    size: 18,
                                    color: cs.onSurface.withValues(alpha: 0.5)),
                              )
                            else
                              Icon(Icons.chevron_right_rounded,
                                  size: 18,
                                  color: cs.onSurface.withValues(alpha: 0.4)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _docDate = picked);
  }

  // ── Supplier section ──────────────────────────────────────────────

  Widget _buildSupplierSection(Color primary, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(Icons.business_outlined, 'SUPPLIER',
            expanded: _supplierExpanded,
            onToggle: () =>
                setState(() => _supplierExpanded = !_supplierExpanded)),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _supplierExpanded
              ? Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.04),
                    border: Border.all(
                        color: cs.outline.withValues(alpha: 0.18)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _supplierName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      if (_supplierCode.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          _supplierCode,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                      if ([_address1, _address2, _address3, _address4]
                          .any((a) => a.isNotEmpty)) ...[
                        const SizedBox(height: 6),
                        Text(
                          [_address1, _address2, _address3, _address4]
                              .where((a) => a.isNotEmpty)
                              .join(', '),
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.55)),
                        ),
                      ],
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ── Items section ─────────────────────────────────────────────────

  Widget _buildItemsSection(Color primary, ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          Icons.inventory_2_outlined,
          'ITEMS',
          expanded: _itemsExpanded,
          onToggle: () => setState(() => _itemsExpanded = !_itemsExpanded),
          badge: _lines.isNotEmpty ? '${_lines.length}' : null,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          child: _itemsExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_lines.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: cs.outline.withValues(alpha: 0.18)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inventory_2_outlined,
                                  size: 40,
                                  color: cs.onSurface.withValues(alpha: 0.2)),
                              const SizedBox(height: 8),
                              Text(
                                'No items yet',
                                style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.4)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._lines.asMap().entries.map((entry) {
                        final i = entry.key;
                        final line = entry.value;
                        return Slidable(
                          key: ObjectKey(line),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.26,
                            children: [
                              CustomSlidableAction(
                                onPressed: (_) => _deleteLine(i),
                                backgroundColor:
                                    Colors.red.withValues(alpha: 0.12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.delete_outline,
                                        size: 26, color: Colors.red),
                                    SizedBox(height: 4),
                                    Text('Remove',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          child: _LineItemCard(
                            index: i,
                            line: line,
                            primary: primary,
                            cs: cs,
                            qtyFmt: _qtyFmt,
                            onStepDown: () => _stepQty(line, -1),
                            onStepUp: () => _stepQty(line, 1),
                            onQtyEditComplete: () => _clampQty(line),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _openItemPicker,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Item'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

}

// ─────────────────────────────────────────────────────────────────────
// Line item card
// ─────────────────────────────────────────────────────────────────────

class _LineItemCard extends StatelessWidget {
  final int index;
  final _ReceivingLine line;
  final Color primary;
  final ColorScheme cs;
  final NumberFormat qtyFmt;
  final VoidCallback onStepDown;
  final VoidCallback onStepUp;
  final VoidCallback onQtyEditComplete;

  const _LineItemCard({
    required this.index,
    required this.line,
    required this.primary,
    required this.cs,
    required this.qtyFmt,
    required this.onStepDown,
    required this.onStepUp,
    required this.onQtyEditComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: (Theme.of(context).cardTheme.color ?? cs.surface)
              .withValues(alpha: 0.5),
          border: Border.all(
              color: line.fromPO
                  ? primary.withValues(alpha: 0.25)
                  : cs.outline.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primary),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: stock code + from PO badge
                  Row(
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
                      if (line.fromPO) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(4),
                          ),
                          child: Text(
                            'FROM PO',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: primary,
                                letterSpacing: 0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Row 2: description
                  Text(
                    line.description,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.65)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Row 3: UOM | qty stepper
                  Row(
                    children: [
                      Text(line.uom,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface
                                  .withValues(alpha: 0.5))),
                      const Spacer(),
                      // Qty stepper
                      _QtyStepper(
                        ctrl: line.qtyCtrl,
                        primary: primary,
                        cs: cs,
                        onStepDown: onStepDown,
                        onStepUp: onStepUp,
                        onEditComplete: onQtyEditComplete,
                      ),
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

// ─────────────────────────────────────────────────────────────────────
// Qty stepper
// ─────────────────────────────────────────────────────────────────────

class _QtyStepper extends StatelessWidget {
  final TextEditingController ctrl;
  final Color primary;
  final ColorScheme cs;
  final VoidCallback onStepDown;
  final VoidCallback onStepUp;
  final VoidCallback onEditComplete;

  const _QtyStepper({
    required this.ctrl,
    required this.primary,
    required this.cs,
    required this.onStepDown,
    required this.onStepUp,
    required this.onEditComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          primary: primary,
          cs: cs,
          onTap: onStepDown,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 56,
          child: TextField(
            controller: ctrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'[\d.,]'))
            ],
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primary),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                  vertical: 6, horizontal: 4),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: cs.outline.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: cs.outline.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: primary),
              ),
            ),
            onEditingComplete: onEditComplete,
            onTapOutside: (_) => onEditComplete(),
          ),
        ),
        const SizedBox(width: 4),
        _StepButton(
          icon: Icons.add,
          primary: primary,
          cs: cs,
          onTap: onStepUp,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final Color primary;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.primary,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: primary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Field helpers
// ─────────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.6))),
      );
}

class _FieldBox extends StatelessWidget {
  final Widget child;
  const _FieldBox({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// PO picker page
// ─────────────────────────────────────────────────────────────────────

class _POPickerPage extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  const _POPickerPage({
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID
  });

  @override
  State<_POPickerPage> createState() => _POPickerPageState();
}

class _POPickerPageState extends State<_POPickerPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<ReceivingPurchaseItem> _items = [];
  bool _loading = true;
  String? _error;

  // Pagination
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalCount = 0;
  final int _pageSize = 20;

  // Sort
  String _sortBy = 'DocDate';
  bool _sortAsc = false;

  @override
  void initState() {
    super.initState();
    _fetch(page: 0);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({required int page}) async {
    if (_loading && page != 0) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getReceivingPurchaseList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'pageIndex': page,
          'pageSize': _pageSize,
          'sortBy': _sortBy,
          'isSortByAscending': _sortAsc,
          'searchTerm': _searchCtrl.text.trim().isEmpty
              ? null
              : _searchCtrl.text.trim(),
        },
      );

      List<dynamic> raw;
      int totalRecord;
      int pageSize;
      if (response is List) {
        raw = response;
        totalRecord = raw.length;
        pageSize = _pageSize;
      } else if (response is Map<String, dynamic>) {
        raw = (response['data'] as List<dynamic>?) ?? [];
        final pg = response['pagination'] as Map<String, dynamic>?;
        totalRecord = (pg?['totalRecord'] as int?) ?? raw.length;
        pageSize = (pg?['pageSize'] as int?) ?? _pageSize;
      } else {
        raw = [];
        totalRecord = 0;
        pageSize = _pageSize;
      }

      if (mounted) {
        setState(() {
          _items = raw
              .map((e) =>
                  ReceivingPurchaseItem.fromJson(e as Map<String, dynamic>))
              .toList();
          _currentPage = page;
          _totalCount = totalRecord;
          _totalPages = pageSize > 0 ? (totalRecord / pageSize).ceil() : 1;
          if (_totalPages < 1) _totalPages = 1;
          _loading = false;
        });
        if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _openSortSheet() {
    String tempSort = _sortBy;
    bool tempAsc = _sortAsc;
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.35,
          maxChildSize: 0.6,
          expand: false,
          builder: (_, sc) => Material(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 16),
                  Text('Sort By',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: tempSort,
                    decoration: InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'DocDate', child: Text('Doc Date')),
                      DropdownMenuItem(
                          value: 'DocNo', child: Text('Doc No')),
                      DropdownMenuItem(
                          value: 'SupplierName',
                          child: Text('Supplier Name')),
                    ],
                    onChanged: (v) =>
                        setSheet(() => tempSort = v ?? tempSort),
                  ),
                  const SizedBox(height: 12),
                  Text('Direction',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primary)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DirectionChip(
                          label: 'Ascending',
                          icon: Icons.arrow_upward_rounded,
                          selected: tempAsc,
                          onTap: () => setSheet(() => tempAsc = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DirectionChip(
                          label: 'Descending',
                          icon: Icons.arrow_downward_rounded,
                          selected: !tempAsc,
                          onTap: () => setSheet(() => tempAsc = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _sortBy = tempSort;
                          _sortAsc = tempAsc;
                        });
                        _fetch(page: 0);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    final start = _currentPage * _pageSize + 1;
    final end = ((_currentPage + 1) * _pageSize).clamp(0, _totalCount);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Purchase Order',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _fetch(page: 0),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search by PO no. or supplier...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _fetch(page: 0);
                              })
                          : null,
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _openSortSheet,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.sort_rounded,
                        size: 20, color: primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: DotsLoading())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: () => _fetch(page: 0),
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _items.isEmpty
                          ? Center(
                              child: Text(
                                'No purchase orders available',
                                style: TextStyle(
                                    color:
                                        cs.onSurface.withValues(alpha: 0.4)),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollCtrl,
                              itemCount: _items.length + 1,
                              itemBuilder: (_, i) {
                                if (i == _items.length) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    child: Center(
                                      child: Text(
                                        'Showing $start–$end of $_totalCount records',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.5)),
                                      ),
                                    ),
                                  );
                                }
                                final po = _items[i];
                                DateTime? d;
                                try {
                                  d = DateTime.parse(po.docDate);
                                } catch (_) {}
                                return InkWell(
                                  onTap: () => Navigator.pop(context, po),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: cs.outline
                                              .withValues(alpha: 0.08),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                              Icons.shopping_basket_outlined,
                                              size: 20,
                                              color: primary),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                po.docNo,
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: primary),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                po.supplierName,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w500),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (d != null)
                                          Text(
                                            DateFormat('dd/MM/yyyy').format(d),
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.5)),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    PaginationBar(
                      currentPage: _currentPage,
                      totalPages: _totalPages,
                      isLoading: _loading,
                      primary: primary,
                      onPrev: _currentPage > 0
                          ? () => _fetch(page: _currentPage - 1)
                          : null,
                      onNext: _currentPage < _totalPages - 1
                          ? () => _fetch(page: _currentPage + 1)
                          : null,
                    ),
                  ],
                ),
    );
  }
}
