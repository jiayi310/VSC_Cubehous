import 'package:cubehous/view/Common/common_dialog.dart';
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
  final ReceivingDoc? initialDoc;
  const ReceivingFormPage({super.key, this.initialDoc});

  @override
  State<ReceivingFormPage> createState() => _ReceivingFormPageState();
}

class _ReceivingFormPageState extends State<ReceivingFormPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  // Page state
  bool _loading = true;
  bool _saving = false;
  bool _showImage = true;
  bool _scanning = false;
  bool _scanSearching = false;

  // Section expand state
  bool _docExpanded = true;
  bool _notesExpanded = true;
  bool _supplierExpanded = true;
  bool _itemsExpanded = true;

  // Header state
  DateTime _docDate = DateTime.now();
  ReceivingPurchaseItem? _selectedPO;
  PurchaseDoc? _purchaseDoc;
  bool _isLoadingPO = false;

  // Notes fields
  final _descriptionCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  // Line items
  final List<_ReceivingLine> _lines = [];

  NumberFormat _qtyFmt = NumberFormat('#,##0.##');
  DateFormat _dateFmt = DateFormat('dd MMM yyyy');
  final _formScrollCtrl = ScrollController();

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
      SessionManager.getImageMode(),
      SessionManager.getQuantityDecimalPoint(),
      SessionManager.getDateFormat(),
    ]);
    _apiKey        = results[0] as String;
    _companyGUID   = results[1] as String;
    _userID        = results[2] as int;
    _userSessionID = results[3] as String;
    _showImage     = (results[4] as String) == 'show';
    final dp       = results[5] as int;
    _qtyFmt        = NumberFormat('#,##0.${'0' * dp}');
    _dateFmt       = DateFormat(results[6] as String);
    // if (widget.initialDoc == null) await _checkAndRestoreDraft();
    if (mounted) setState(() => _loading = false);
  }

  // ── Draft ─────────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    final draft = {

    };
    // await SessionManager.saveReceivingraft(jsonEncode(draft));
  }

  // void _restoreDraftFields(Map<String, dynamic> j) {
  //   _docDate = DateTime.tryParse(j['docDate'] as String? ?? '') ?? DateTime.now();
  //   _descriptionCtrl.text = j['description'] as String? ?? '';
  //   _remarkCtrl.text = j['remark'] as String? ?? '';
  // }

  // Future<void> _checkAndRestoreDraft() async {
  //   final raw = await SessionManager.getReceivingDraft();
  //   if (raw == null || raw.isEmpty) return;
  //   try {
  //     final j = jsonDecode(raw) as Map<String, dynamic>;
  //     if (!mounted) return;
  //     _restoreDraftFields(j);
  //     final soMap = j['so'] as Map<String, dynamic>?;
  //     final linesJson = j['lines'] as List<dynamic>? ?? [];
  //     if (soMap != null) {
  //       final docID = soMap['docID'] as int? ?? 0;
  //       // Build a minimal SalesListItem so the SO card renders
  //       _selectedPO = PurchaseListItem(
  //         //TODO
  //       );
  //       setState(() => _isLoadingPO = true);
  //       // Re-fetch SO so _salesDoc is populated (needed for save payload)
  //       try {
  //         final result = await BaseClient.post(
  //           ApiEndpoints.getPurchase,
  //           body: {
  //             'apiKey': _apiKey,
  //             'companyGUID': _companyGUID,
  //             'userID': _userID,
  //             'userSessionID': _userSessionID,
  //             'docID': docID,
  //           },
  //         );
  //         final doc = PurchaseDoc.fromJson(result as Map<String, dynamic>);
  //         if (!mounted) return;
  //         // Build lines from live SO data, apply saved pack qtys
  //         final Map<int, String> savedQtys = {
  //           for (final lj in linesJson)
  //             (lj as Map<String, dynamic>)['soDetailID'] as int? ?? 0:
  //                 (lj)['packQty'] as String? ?? '0',
  //         };
  //         final newLines = doc.purchaseDetails.map((d) {
  //           final line = ;//TODO

  //           line.packQtyCtrl.text = savedQtys[d.dtlID] ?? '0';
  //           return line;
  //         }).toList();
  //         setState(() {
  //           _purchaseDoc = doc;
  //           _lines.addAll(newLines);
  //           _isLoadingPO = false;
  //         });
  //       } catch (_) {
  //         if (mounted) setState(() => _isLoadingPO = false);
  //       }
  //     } else {
  //       setState(() {});
  //     }
  //   } catch (_) {
  //     await SessionManager.clearPackingDraft();
  //   }
  // }

  bool get _hasChanges =>
      _selectedPO != null ||
      _descriptionCtrl.text.isNotEmpty ||
      _remarkCtrl.text.isNotEmpty;

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.save_outlined, size: 30, color: cs.primary),
              ),
              const SizedBox(height: 16),
              const Text('Save Draft?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Do you want to save your progress as a draft?',
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
                              borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(20))),
                        ),
                        onPressed: () => Navigator.pop(ctx, 'discard'),
                        child: Text('Discard',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                      ),
                    ),
                    VerticalDivider(
                        width: 1, color: cs.outline.withValues(alpha: 0.15)),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                  bottomRight: Radius.circular(20))),
                        ),
                        onPressed: () => Navigator.pop(ctx, 'save'),
                        child: Text('Save Draft',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: cs.primary)),
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
    if (result == null) return false;
    if (result == 'save') await _saveDraft();
    if (result == 'discard') await SessionManager.clearPackingDraft();
    return true;
  }

  // ── PO picker ───────────────────────────────────────────────────

  Future<void> _pickPO() async {
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
    if (po == null || !mounted) return;
    setState(() {
      _selectedPO = po;
      _purchaseDoc = null;
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      _isLoadingPO = true;
    });
    await _fetchPODetails(po.docID);
  }

Future<void> _fetchPODetails(int docID) async {
    try {
      // final result = await BaseClient.post(
      //   ApiEndpoints.getPurchase,
      //   body: {
      //     'apiKey': _apiKey,
      //     'companyGUID': _companyGUID,
      //     'userID': _userID,
      //     'userSessionID': _userSessionID,
      //     'docID': docID,
      //   },
      // );
      // final doc = PurchaseDoc.fromJson(result as Map<String, dynamic>);
      // if (!mounted) return;
      // final newLines = doc.purchaseDetails.map((d) {
      //   return _ReceivingLine()
      //     ..stockID: d.stockID
      //     ..stockCode: d.stockCode
      //     ..description: d.description
      //     ..uom: d.uom
      //     ..qty: d.qty
      //     ..fromPO: true;
      // }).toList();
      // setState(() {
      //   _purchaseDoc = doc;
      //   _lines.addAll(newLines);
      //   _isLoadingPO = false;
      // });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPO = false);
        _showError('Failed to load purchase order: $e');
      }
    }
  }

  // ── Pickers ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _docDate = picked);
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

  // ── Barcode scan ───────────────────────────────────────────────

  Future<void> _onScanDetected(String barcode) async {
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

    setState(() => _saving = true);
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
          // 'apiKey': _apiKey,
          // 'companyGUID': _companyGUID,
          // 'userID': _userID,
          // 'userSessionID': _userSessionID,
          // 'docDate': _docDate.toIso8601String(),
          // 'supplierID': _supplierID ?? 0,
          // 'supplierCode': _supplierCode,
          // 'supplierName': _supplierName,
          // 'address1': _address1,
          // 'address2': _address2,
          // 'address3': _address3,
          // 'address4': _address4,
          // 'phone': _phone,
          // 'fax': _fax,
          // 'email': _email,
          // 'attention': _attention,
          // 'description': _descriptionCtrl.text.trim(),
          // 'remark': _remarkCtrl.text.trim(),
          // 'purchaseDocID': _selectedPO?.docID ?? 0,
          // 'receivingDetails': details,
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
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final canPop = await _onWillPop();
        if (canPop && mounted) nav.pop();
      },
      child: Scaffold(
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
      body: _loading
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
                              // ── Document ──────────────────────────────
                              FormSectionHeader(
                                icon: Icons.receipt_long_outlined,
                                title: 'Document',
                                expanded: _docExpanded,
                                onToggle: () => setState(
                                    () => _docExpanded = !_docExpanded),
                              ),
                              AnimatedSize(
                                duration:
                                    const Duration(milliseconds: 220),
                                curve: Curves.easeInOut,
                                child: _docExpanded
                                    ? _buildDocSection()
                                    : const SizedBox.shrink(),
                              ),

                            // ── Supplier (after PO selected) ──────────
                            if (_selectedPO != null) ...[
                              FormSectionHeader(
                                icon: Icons.person_outline,
                                title: 'Supplier',
                                expanded: _supplierExpanded,
                                onToggle: () => setState(() =>
                                    _supplierExpanded =
                                        !_supplierExpanded),
                              ),
                              AnimatedSize(
                                duration:
                                    const Duration(milliseconds: 220),
                                curve: Curves.easeInOut,
                                child: _supplierExpanded
                                    ? _buildSupplierSection()
                                    : const SizedBox.shrink(),
                              ),
                            ],

                            // ── Notes ─────────────────────────────────
                            FormSectionHeader(
                              icon: Icons.notes_outlined,
                              title: 'Notes',
                              expanded: _notesExpanded,
                              onToggle: () => setState(
                                  () => _notesExpanded = !_notesExpanded),
                            ),
                            AnimatedSize(
                              duration:
                                  const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              child: _notesExpanded
                                  ? _buildNotesSection()
                                  : const SizedBox.shrink(),
                            ),
                            
                            // ── Items ─────────────────────────────────
                            FormSectionHeader(
                              icon: Icons.inventory_2_outlined,
                              title: 'Packing Items',
                              expanded: _itemsExpanded,
                              onToggle: () => setState(
                                  () => _itemsExpanded = !_itemsExpanded),
                              badge: _lines.isEmpty
                                  ? null
                                  : '${_lines.length}',
                            ),
                            AnimatedSize(
                              duration:
                                  const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              child: _itemsExpanded
                                  ? _buildItemsSection()
                                  : const SizedBox.shrink(),
                            ),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Save button ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
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
                    onDetected: _onScanDetected,
                    onClose: () => setState(() => _scanning = false),
                  ),
                if (_scanSearching)
                  Container(
                    color: Colors.black45,
                    child: const Center(child: DotsLoading()),
                  ),
              ],
            ),
    )
    );
  }


  // ── Section builders ──────────────────────────────────────────────

  Widget _buildDocSection() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date picker
        FieldLabel(label: 'Date'),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: _FieldBox(
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 8),
                Text(
                  _dateFmt.format(_docDate),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        // PO picker
        FieldLabel(label: 'PO Ref *'),
        InkWell(
          onTap: _isLoadingPO ? null : _pickPO,
          borderRadius: BorderRadius.circular(12),
          child: FieldBox(
            child: _isLoadingPO
              ? const SizedBox(
                height: 20,
                child: Center(child: DotsLoading()))
                : Row(
                    children: [
                      const Icon(Icons.receipt_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _selectedPO == null
                            ? Text(
                                'Select purchase order',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.4)),
                              )
                            : Text(
                                    _selectedPO!.docNo,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: cs.primary),
                                  ),
                      ),
                      if (_selectedPO != null)
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectedPO = null;
                            // _poDoc = null;
                            for (final l in _lines) {
                              l.dispose();
                            }
                            _lines.clear();
                          }),
                          child: Icon(Icons.clear,
                              size: 16,
                              color: cs.onSurface
                                  .withValues(alpha: 0.4)),
                        )
                      else
                        Icon(Icons.chevron_right,
                            size: 18,
                            color: cs.onSurface
                                .withValues(alpha: 0.3)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildSupplierSection() {
      final cs = Theme.of(context).colorScheme;
      final primary = cs.primary;
      final muted = cs.onSurface.withValues(alpha: 0.5);
      final doc = _poDoc;

      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
        ),
        child: doc == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: DotsLoading()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.supplierCode,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: primary)
                ),
                const SizedBox(height: 2),
                Text(doc.supplierName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                if (_hasAddr([
                  doc.address1,
                  doc.address2,
                  doc.address3,
                  doc.address4
                ])) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                      Icons.location_on_outlined,
                      _joinAddr([
                        doc.address1,
                        doc.address2,
                        doc.address3,
                        doc.address4
                      ]),
                      muted),
                ],
              ],
             ),
    );
  }

  bool _hasAddr(List<String?> parts) =>
      parts.any((p) => p != null && p.isNotEmpty);

  String _joinAddr(List<String?> parts) =>
      parts.where((p) => p != null && p.isNotEmpty).join(', ');

  Widget _infoRow(IconData icon, String text, Color muted) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: muted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: muted, height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label: 'Description'),
        TextFormField(
          controller: _descriptionCtrl,
          maxLines: 1,
          style: const TextStyle(fontSize: 14),
          decoration: formInputDeco(context),
        ),
        const SizedBox(height: 12),
        FieldLabel(label: 'Remark'),
        TextFormField(
          controller: _remarkCtrl,
          maxLines: 1,
          style: const TextStyle(fontSize: 14),
          decoration: formInputDeco(context),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildItemsSection() {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    if (_isLoadingPO) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: DotsLoading()),
      );
    }

  if (_selectedPO != null){
    if (_lines.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Text('No items in this sales order',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.4))),
        ),
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                );
    }
  }



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

  DateFormat _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    SessionManager.getDateFormat().then((fmt) {
      if (mounted) setState(() => _dateFmt = DateFormat(fmt));
    });
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
        title: const Text('Purchase Order',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      width: 44,
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
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      po.docNo,
                                                      style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w700,
                                                          color: primary),
                                                    ),
                                                  ),
                                                  if (d != null)
                                                    Text(
                                                      _dateFmt.format(d),
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color: cs.onSurface
                                                              .withValues(alpha: 0.5)),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                po.supplierName,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
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
