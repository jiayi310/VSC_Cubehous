import 'dart:convert';
import 'package:cubehous/common/stock_common.dart';
import 'package:cubehous/view/Warehouse/Receiving/receiving_po_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
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
  int stockBatchID = 0;
  String batchNo;
  String stockCode;
  String description;
  String uom;
  double orderedQty;
  double qty;
  List<String> serialNoList = [];
  String? itemImage;
  bool hasBatch = false;
  bool hasSerial = false;
  final bool fromPO;
  final TextEditingController qtyCtrl;
  final TextEditingController batchNoCtrl;

  _ReceivingLine({
    this.dtlID = 0,
    this.stockID,
    this.batchNo = '',
    required this.stockCode,
    required this.description,
    required this.uom,
    this.orderedQty = 0,
    required this.qty,
    this.fromPO = false,
  })  : qtyCtrl = TextEditingController(
            text: NumberFormat('#,##0.##').format(qty)),
        batchNoCtrl = TextEditingController(text: batchNo);

  bool get isFullyReceived => orderedQty > 0 && qty >= orderedQty;

  void dispose() {
    qtyCtrl.dispose();
    batchNoCtrl.dispose();
  }
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

  bool get _isEditMode => widget.initialDoc != null;
  int _editDocID = 0;
  String _editDocNo = '';

  // Header state
  DateTime _docDate = DateTime.now();
  ReceivingSelectedPO? _selectedPO;
  PurchaseDoc? _purchaseDoc;
  bool _isLoadingPO = false;
  final _descriptionCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  // Line items
  final List<_ReceivingLine> _lines = [];

  final _formScrollCtrl = ScrollController();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showImage = true;
  bool _scanning = false;
  bool _scanSearching = false;
  bool _docExpanded = false;
  bool _fromPOExpanded = true;
  bool _itemsExpanded = true;
  NumberFormat _qtyFmt = NumberFormat('#,##0.##');
  DateFormat _dateFmt = DateFormat('dd MMM yyyy');

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
    try {
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
      if (_isEditMode) {
        if (mounted) setState(() => _initFromDoc(widget.initialDoc!));
      } else {
        await _checkAndRestoreDraft();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _initFromDoc(ReceivingDoc doc) {
    _editDocID  = doc.docID;
    _editDocNo  = doc.docNo;
    _docDate    = DateTime.tryParse(doc.docDate) ?? DateTime.now();
    _descriptionCtrl.text = doc.description ?? '';
    _remarkCtrl.text      = doc.remark ?? '';
    _docExpanded = true;

    if (doc.purchaseDocID != null) {
      _selectedPO = ReceivingSelectedPO(
        docID:        doc.purchaseDocID!,
        docNo:        doc.purchaseDocNo ?? '',
        docDate:      '',
        supplierID:   doc.supplierID ?? 0,
        supplierCode: doc.supplierCode,
        supplierName: doc.supplierName,
        finalTotal:   0,
      );
    }

    for (final d in doc.receivingDetails) {
      _lines.add(_ReceivingLine(
        dtlID:       d.dtlID,
        stockID:     d.stockID,
        stockCode:   d.stockCode,
        description: d.description,
        uom:         d.uom,
        orderedQty:  0,
        qty:         d.qty,
        fromPO:      doc.purchaseDocID != null,
      ));
    }

    if (doc.purchaseDocID != null) {
      _fetchPOForEditMode(doc.purchaseDocID!);
    }
  }

  Future<void> _fetchPOForEditMode(int docID) async {
    setState(() => _isLoadingPO = true);
    try {
      final result = await BaseClient.post(
        ApiEndpoints.getPurchase,
        body: {
          'apiKey':        _apiKey,
          'companyGUID':   _companyGUID,
          'userID':        _userID,
          'userSessionID': _userSessionID,
          'docID':         docID,
        },
      );
      final doc = PurchaseDoc.fromJson(result as Map<String, dynamic>);
      if (!mounted) return;
      for (final line in _lines) {
        final match = doc.purchaseDetails.where(
          (d) => d.stockID == line.stockID || d.stockCode == line.stockCode,
        ).firstOrNull;
        if (match != null) line.orderedQty = match.qty;
      }
      setState(() {
        _purchaseDoc = doc;
        _isLoadingPO = false;
      });
      if (_showImage) _loadLineData(_lines);
    } catch (_) {
      if (mounted) setState(() => _isLoadingPO = false);
    }
  }

  // ── Draft ─────────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    final draft = {
      'docDate': _docDate.toIso8601String(),
      'description': _descriptionCtrl.text,
      'remark': _remarkCtrl.text,
      'po': _selectedPO == null
          ? null
          : {
              'docID': _selectedPO!.docID,
              'docNo': _selectedPO!.docNo,
              'docDate': _selectedPO!.docDate,
              'supplierCode': _selectedPO!.supplierCode,
              'supplierName': _selectedPO!.supplierName,
            },
      'lines': _lines
          .map((l) => {
                'stockID': l.stockID,
                'stockCode': l.stockCode,
                'description': l.description,
                'uom': l.uom,
                'orderedQty': l.orderedQty,
                'qty': l.qtyCtrl.text,
                'batchNo': l.batchNoCtrl.text,
                'fromPO': l.fromPO,
              })
          .toList(),
    };
    await SessionManager.saveReceivingDraft(jsonEncode(draft));
  }

  void _restoreDraftFields(Map<String, dynamic> j) {
    _docDate = DateTime.tryParse(j['docDate'] as String? ?? '') ?? DateTime.now();
    _descriptionCtrl.text = j['description'] as String? ?? '';
    _remarkCtrl.text = j['remark'] as String? ?? '';
  }

  Future<void> _checkAndRestoreDraft() async {
    final raw = await SessionManager.getReceivingDraft();
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      _restoreDraftFields(j);
      final poMap = j['po'] as Map<String, dynamic>?;
      final linesJson = j['lines'] as List<dynamic>? ?? [];
      if (poMap != null) {
        _selectedPO = ReceivingSelectedPO(
          docID: poMap['docID'] as int? ?? 0,
          docNo: poMap['docNo'] as String? ?? '',
          docDate: poMap['docDate'] as String? ?? '',
          supplierID: poMap['supplierID'] as int? ?? 0,
          supplierCode: poMap['supplierCode'] as String? ?? '',
          supplierName: poMap['supplierName'] as String? ?? '',
          finalTotal: StockCommon.toD(poMap['finalTotal'])
        );
        setState(() => _isLoadingPO = true);
        try {
          final result = await BaseClient.post(
            ApiEndpoints.getPurchase,
            body: {
              'apiKey': _apiKey,
              'companyGUID': _companyGUID,
              'userID': _userID,
              'userSessionID': _userSessionID,
              'docID': _selectedPO!.docID,
            },
          );
          final doc = PurchaseDoc.fromJson(result as Map<String, dynamic>);
          if (!mounted) return;
          // Restore lines from draft (preserves user-edited qtys)
          final restoredLines = linesJson.map((lj) {
            final m = lj as Map<String, dynamic>;
            final qtyText = m['qty'] as String? ?? '0';
            final qty = double.tryParse(qtyText.replaceAll(',', '')) ?? 0;
            final orderedQty = (m['orderedQty'] as num?)?.toDouble() ?? 0;
            return _ReceivingLine(
              stockID: m['stockID'] as int?,
              stockCode: m['stockCode'] as String? ?? '',
              description: m['description'] as String? ?? '',
              uom: m['uom'] as String? ?? '',
              orderedQty: orderedQty,
              qty: qty,
              batchNo: m['batchNo'] as String? ?? '',
              fromPO: m['fromPO'] as bool? ?? false,
            );
          }).toList();
          setState(() {
            _purchaseDoc = doc;
            _lines.addAll(restoredLines);
            _isLoadingPO = false;
          });
          _loadLineData(restoredLines);
        } catch (_) {
          if (mounted) setState(() => _isLoadingPO = false);
        }
      } else {
        setState(() {});
      }
    } catch (_) {
      await SessionManager.clearReceivingDraft();
    }
  }

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
    if (result == 'discard') await SessionManager.clearReceivingDraft();
    return true;
  }

  // ── PO picker ───────────────────────────────────────────────────

  Future<void> _pickPO() async {
    final po = await Navigator.push<ReceivingSelectedPO>(
      context,
      MaterialPageRoute(
        builder: (_) => ReceivingPOPickerPage(
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
      final result = await BaseClient.post(
        ApiEndpoints.getPurchase,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': docID,
        },
      );
      final doc = PurchaseDoc.fromJson(result as Map<String, dynamic>);
      if (!mounted) return;
      final newLines = doc.purchaseDetails.map((d) {
        return _ReceivingLine(
          dtlID: d.dtlID,
          stockID: d.stockID,
          stockCode: d.stockCode,
          description: d.description,
          uom: d.uom,
          orderedQty: d.qty,
          qty: 0,
          fromPO: true,
        );
      }).toList();
      setState(() {
        _purchaseDoc = doc;
        _lines
          ..clear()
          ..addAll(newLines);
        _isLoadingPO = false;
      });
      _loadLineData(newLines);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPO = false);
        _showError('Failed to load purchase order: $e');
      }
    }
  }

  Future<void> _loadLineData(List<_ReceivingLine> lines) async {
    for (final line in lines) {
      if (line.stockID == null || !mounted) return;
      try {
        final result = await BaseClient.post(
          ApiEndpoints.getStock,
          body: {
            'apiKey': _apiKey,
            'companyGUID': _companyGUID,
            'userID': _userID,
            'userSessionID': _userSessionID,
            'stockID': line.stockID,
          },
        );
        if (!mounted) return;

        final data = result as Map<String, dynamic>;
        final bool nHasBatch = data['hasBatch'] as bool;
        // final bool nHasSerialNo = data['hasSerial'] as bool;
        final bool nHasSerialNo = true;

        if (_showImage){
          final image = data['image'] as String?;
          if (image != null && image.isNotEmpty) {
            setState(() {
              line.itemImage = image;
              line.hasBatch = nHasBatch;
              line.hasSerial = nHasSerialNo;
            });
          }
        } else {
          setState(() {
            line.hasBatch = nHasBatch;
            line.hasSerial = nHasSerialNo;
          });
        }

        
      } catch (_) {}
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
    if (_showImage && picked.stockID != null) {
      _loadLineData([_lines.last]);
    }
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
    final maxQty = line.fromPO && line.orderedQty > 0
        ? line.orderedQty
        : double.infinity;
    final newQty = (line.qty + delta).clamp(0.0, maxQty);
    setState(() {
      line.qty = newQty;
      line.qtyCtrl.text = _qtyFmt.format(newQty);
    });
  }

  void _clampQty(_ReceivingLine line) {
    final val = double.tryParse(
            line.qtyCtrl.text.replaceAll(',', '')) ??
        line.qty;
    final maxQty = line.fromPO && line.orderedQty > 0
        ? line.orderedQty
        : double.infinity;
    final clamped = val.clamp(0.0, maxQty);
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
        final f = found;
        final existingIdx = _lines.indexWhere(
          (l) => l.stockID == f.stockID || l.stockCode == f.stockCode,
        );
        if (existingIdx >= 0) {
          final line = _lines[existingIdx];
          final maxQty = line.fromPO && line.orderedQty > 0
              ? line.orderedQty
              : double.infinity;
          final newQty = (line.qty + 1).clamp(0.0, maxQty);
          setState(() {
            line.qty = newQty;
            line.qtyCtrl.text = _qtyFmt.format(newQty);
          });
        } else {
          final newLine = _ReceivingLine(
            stockID: f.stockID,
            stockCode: f.stockCode,
            description: f.description,
            uom: f.baseUOM,
            qty: 1,
            fromPO: false,
          );
          setState(() => _lines.add(newLine));
          if (_showImage) _loadLineData([newLine]);
        }
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
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();

    if (_selectedPO == null) {
      _showError('Please select a Purchase Order');
      return;
    }
    if (_lines.isEmpty) {
      _showError('Please add at least one item');
      return;
    }

    final missingBatch = _lines.where(
      (l) => l.qty > 0 && l.hasBatch && l.batchNoCtrl.text.trim().isEmpty,
    ).toList();
    if (missingBatch.isNotEmpty) {
      _showError('Batch no required for: ${missingBatch.map((l) => l.stockCode).join(', ')}');
      return;
    }

    final missingSerial = _lines.where(
      (l) => l.hasSerial && l.serialNoList.length != l.qty.toInt(),
    ).toList();
    if (missingSerial.isNotEmpty) {
      _showError('Serial no. count mismatch for: ${missingSerial.map((l) => l.stockCode).join(', ')}');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final details = _lines
          .where((l) => l.qty > 0)
          .map((l) => {
                'dtlID': l.dtlID,
                'docID': _isEditMode ? _editDocID : 0,
                'stockID': l.stockID ?? 0,
                'stockBatchID': l.stockBatchID,
                'batchNo': l.batchNoCtrl.text.trim(),
                'stockCode': l.stockCode,
                'description': l.description,
                'uom': l.uom,
                'qty': l.qty,
                if (l.hasSerial) 'serialNoList': l.serialNoList,
              })
          .toList();

      final body = {
        'apiKey':        _apiKey,
        'companyGUID':   _companyGUID,
        'userID':        _userID,
        'userSessionID': _userSessionID,
        'receivingForm': {
          'docID':        _isEditMode ? _editDocID : 0,
          'docNo':        _isEditMode ? _editDocNo : '',
          'docDate':      _docDate.toIso8601String(),
          'supplierID':   _selectedPO?.supplierID ?? 0,
          'supplierCode': _selectedPO?.supplierCode ?? '',
          'supplierName': _selectedPO?.supplierName ?? '',
          'address1' : '',
          'address2' : '',
          'address3' : '',
          'address4' : '',
          'phone' : '',
          'fax' : '',
          'email' : '',
          'attention' : '',
          'description':  _descriptionCtrl.text.trim(),
          'remark':       _remarkCtrl.text.trim(),
          'isPutAway':    false,
          'isVoid':       false,
          'lastModifiedDateTime' : DateTime.now().toIso8601String(),
          'lastModifiedUserID': _userID,
          'createdDateTime' : DateTime.now().toIso8601String(),
          'createdUserID': _userID,
          'purchaseDocID':  _selectedPO?.docID ?? 0,
          'purchaseDocNo':  _selectedPO?.docNo ?? '',
          'receivingDetails': details,
        },
      };

      final jsonStr = '── RECEIVING SAVE BODY ──\n${const JsonEncoder.withIndent('  ').convert(body)}';
      for (var i = 0; i < jsonStr.length; i += 800) {
        // ignore: avoid_print
        print(jsonStr.substring(i, i + 800 > jsonStr.length ? jsonStr.length : i + 800));
      }

      await BaseClient.post(
        _isEditMode ? ApiEndpoints.updateReceiving : ApiEndpoints.createReceiving,
        body: body,
      );

      if (!_isEditMode) await SessionManager.clearReceivingDraft();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
        title: GestureDetector(
          onDoubleTap: () => _formScrollCtrl.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ),
          child: Text(_isEditMode ? 'Edit Receiving' : 'New Receiving',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
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
      body: _isLoading
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
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeInOut,
                                child: _docExpanded
                                    ? _buildDocSection()
                                    : const SizedBox.shrink(),
                              ),

                              // ── From PO ───────────────────────────────
                              FormSectionHeader(
                                icon: Icons.link_outlined,
                                title: 'From Purchase Order *',
                                expanded: _fromPOExpanded,
                                onToggle: () => setState(
                                    () => _fromPOExpanded = !_fromPOExpanded),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeInOut,
                                child: _fromPOExpanded
                                    ? _buildFromPOSection()
                                    : const SizedBox.shrink(),
                              ),

                              // ── Items ─────────────────────────────────
                              FormSectionHeader(
                                icon: Icons.inventory_2_outlined,
                                title: 'Receiving Items',
                                expanded: _itemsExpanded,
                                onToggle: () => setState(
                                    () => _itemsExpanded = !_itemsExpanded),
                                badge: _lines.isEmpty ? null : '${_lines.length}',
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 220),
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
                    // ── Receiving summary and Save button ────────────────────────
                    Padding(
                      padding: EdgeInsetsGeometry.only(top: 25, bottom: 25, left: 10, right: 20),
                      child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        IconButton(onPressed: _showReceivingSummary, icon: Icon(Icons.info_outline, size: 25, color: Colors.grey)),
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              onPressed: _isSaving ? null : _save,
                              child: _isSaving
                                  ? const DotsLoading(dotSize: 6)
                                  : Text(_isEditMode ? 'Update' : 'Save',
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                      ],
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


  // ── Line edit sheet ───────────────────────────────────────────────

  void _openEditSheet(_ReceivingLine line) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final dateFmt = DateFormat('dd MMM yyyy');

    DateTime? mfgDate;
    DateTime? expDate;
    bool creating = false;

    // Serial generator state
    bool showGenerator  = false;
    bool showSerialList = true;
    final genPrefixCtrl = TextEditingController();
    final genStartCtrl  = TextEditingController(text: '1');
    final genCountCtrl  = TextEditingController();
    final serialCtrl    = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isFullyReceived = line.isFullyReceived;
          final isPartial = line.qty > 0 && !isFullyReceived;
          final qtyColor = line.fromPO
              ? isFullyReceived
                  ? Colors.green
                  : isPartial
                      ? const Color(0xFFFF9700)
                      : cs.onSurface.withValues(alpha: 0.45)
              : cs.onSurface.withValues(alpha: 0.45);

          void stepQty(double delta) {
            final maxQty = line.fromPO && line.orderedQty > 0
                ? line.orderedQty
                : double.infinity;
            final newQty = (line.qty + delta).clamp(0.0, maxQty);
            setState(() {
              line.qty = newQty;
              line.qtyCtrl.text = _qtyFmt.format(newQty);
            });
            setSheet(() {});
          }

          void clampQty() {
            final val = double.tryParse(
                    line.qtyCtrl.text.replaceAll(',', '')) ??
                line.qty;
            final maxQty = line.fromPO && line.orderedQty > 0
                ? line.orderedQty
                : double.infinity;
            final clamped = val.clamp(0.0, maxQty);
            setState(() {
              line.qty = clamped;
              line.qtyCtrl.text = _qtyFmt.format(clamped);
            });
            setSheet(() {});
          }

          Future<void> pickDate({required bool isMfg}) async {
            final initial = isMfg
                ? (mfgDate ?? DateTime.now())
                : (expDate ?? DateTime.now());
            final picked = await showDatePicker(
              context: ctx,
              initialDate: initial,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setSheet(() {
                if (isMfg) { mfgDate = picked; } else { expDate = picked; }
              });
            }
          }

          Widget dateField(String label, DateTime? value, {required bool isMfg}) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () => pickDate(isMfg: isMfg),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: cs.outline.withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 16,
                            color: value != null
                                ? primary
                                : cs.onSurface.withValues(alpha: 0.35)),
                        const SizedBox(width: 8),
                        Text(
                          value != null
                              ? dateFmt.format(value)
                              : 'Select date',
                          style: TextStyle(
                              fontSize: 14,
                              color: value != null
                                  ? cs.onSurface
                                  : cs.onSurface.withValues(alpha: 0.35)),
                        ),
                        if (value != null) ...[
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setSheet(() {
                              if (isMfg) { mfgDate = null; } else { expDate = null; }
                            }),
                            child: Icon(Icons.clear,
                                size: 16,
                                color: cs.onSurface.withValues(alpha: 0.4)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          Future<void> confirm() async {
            if (line.hasBatch) {
              final batchNo = line.batchNoCtrl.text.trim();
              if (batchNo.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                  content: const Text('Please enter a batch number'),
                  backgroundColor: cs.error,
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              setSheet(() => creating = true);
              try {
                final now = DateTime.now().toIso8601String();
                final result = await BaseClient.post(
                  ApiEndpoints.createStockBatch,
                  body: {
                    'apiKey': _apiKey,
                    'companyGUID': _companyGUID,
                    'userID': _userID,
                    'userSessionID': _userSessionID,
                    'stockBatchForm': {
                      'stockBatchID': 0,
                      'batchNo': batchNo,
                      'manufacturedDate': mfgDate?.toIso8601String(),
                      'expiryDate': expDate?.toIso8601String(),
                      'lastModifiedDateTime': now,
                      'lastModifiedUserID': _userID,
                      'createdDateTime': now,
                      'createdUserID': _userID,
                      'stockID': line.stockID,
                      'manufacturedDateOnly': mfgDate != null
                          ? DateFormat('yyyy-MM-dd').format(mfgDate!)
                          : null,
                      'expiryDateOnly': expDate != null
                          ? DateFormat('yyyy-MM-dd').format(expDate!)
                          : null,
                    },
                  },
                );
                if (result is Map<String, dynamic>) {
                  final id = result['stockBatchID'] as int?;
                  if (id != null) setState(() => line.stockBatchID = id);
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(e is BadRequestException
                        ? e.message
                        : 'Failed to create batch: $e'),
                    backgroundColor: cs.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
                setSheet(() => creating = false);
                return;
              }
            }
            if (ctx.mounted) Navigator.pop(ctx);
          }

          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.8,
            ),
            child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
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
                    // Stock header
                    Text(line.stockCode,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: primary)),
                    const SizedBox(height: 2),
                    Text(line.description,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface),
                        maxLines: 2),
                    const SizedBox(height: 4),
                    Text(line.uom,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.5))),
                    if (line.fromPO && line.orderedQty > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Ordered: ${_qtyFmt.format(line.orderedQty)}',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.45)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Divider(height: 1, color: cs.outline.withValues(alpha: 0.1)),
                    const SizedBox(height: 16),
                    // Qty stepper — hidden for serial items (qty driven by serial count)
                    if (!line.hasSerial) ...[
                      Text('Receive Qty',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _StepButton(
                              icon: Icons.remove,
                              primary: primary,
                              cs: cs,
                              onTap: () => stepQty(-1)),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 80,
                            child: TextField(
                              controller: line.qtyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d.,]'))
                              ],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: qtyColor),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 8, horizontal: 4),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color:
                                          cs.outline.withValues(alpha: 0.3)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color:
                                          cs.outline.withValues(alpha: 0.3)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: primary),
                                ),
                              ),
                              onEditingComplete: clampQty,
                              onTapOutside: (_) => clampQty(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _StepButton(
                              icon: Icons.add,
                              primary: primary,
                              cs: cs,
                              onTap: () => stepQty(1)),
                        ],
                      ),
                    ],
                    // Serial number section
                    if (line.hasSerial) ...[
                      // Header row
                      Row(
                        children: [
                          Text('Serial Numbers',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface.withValues(alpha: 0.6))),
                          const Spacer(),
                          if (line.serialNoList.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  line.serialNoList = [];
                                  line.qty = 0;
                                  line.qtyCtrl.text = '0';
                                });
                                setSheet(() {});
                              },
                              child: Text('Clear all',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: cs.error)),
                            ),
                          
                        ],
                      ),
                      const SizedBox(height: 10),

                      // ── Mode toggle ───────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setSheet(() => showGenerator = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: !showGenerator
                                      ? primary
                                      : cs.surfaceContainerHighest,
                                  borderRadius: const BorderRadius.horizontal(
                                      left: Radius.circular(8)),
                                ),
                                child: Center(
                                  child: Text('Scan / Type',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: !showGenerator
                                              ? Colors.white
                                              : cs.onSurface.withValues(alpha: 0.6))),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setSheet(() => showGenerator = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: showGenerator
                                      ? primary
                                      : cs.surfaceContainerHighest,
                                  borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(8)),
                                ),
                                child: Center(
                                  child: Text('Generate Sequential',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: showGenerator
                                              ? Colors.white
                                              : cs.onSurface.withValues(alpha: 0.6))),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Scan / Type mode ──────────────────────────────
                      if (!showGenerator) ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: serialCtrl,
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Enter or scan serial no.',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: cs.outline.withValues(alpha: 0.3)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                        color: cs.outline.withValues(alpha: 0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: primary),
                                  ),
                                ),
                                onSubmitted: (_) {
                                  final sn = serialCtrl.text.trim();
                                  if (sn.isEmpty) return;
                                  if (line.serialNoList.contains(sn)) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                      content: Text('Duplicate: "$sn"'),
                                      backgroundColor: cs.error,
                                      behavior: SnackBarBehavior.floating,
                                    ));
                                    return;
                                  }
                                  setState(() {
                                    line.serialNoList = [...line.serialNoList, sn];
                                    line.qty = line.serialNoList.length.toDouble();
                                    line.qtyCtrl.text = _qtyFmt.format(line.qty);
                                  });
                                  setSheet(() {});
                                  serialCtrl.clear();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () {
                                final sn = serialCtrl.text.trim();
                                if (sn.isEmpty) return;
                                if (line.serialNoList.contains(sn)) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                    content: Text('Duplicate: "$sn"'),
                                    backgroundColor: cs.error,
                                    behavior: SnackBarBehavior.floating,
                                  ));
                                  return;
                                }
                                setState(() {
                                  line.serialNoList = [...line.serialNoList, sn];
                                  line.qty = line.serialNoList.length.toDouble();
                                  line.qtyCtrl.text = _qtyFmt.format(line.qty);
                                });
                                setSheet(() {});
                                serialCtrl.clear();
                              },
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      ],

                      // ── Sequential generator mode ─────────────────────
                      if (showGenerator) ...[
                        // Prefix + Start No row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Prefix',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface.withValues(alpha: 0.55))),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: genPrefixCtrl,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'e.g. SN-2024-',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: cs.outline.withValues(alpha: 0.3))),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: cs.outline.withValues(alpha: 0.3))),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: primary)),
                                    ),
                                    onChanged: (_) => setSheet(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Start No',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface.withValues(alpha: 0.55))),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: genStartCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: '001',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: cs.outline.withValues(alpha: 0.3))),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: cs.outline.withValues(alpha: 0.3))),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: primary)),
                                    ),
                                    onChanged: (_) => setSheet(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Count',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface.withValues(alpha: 0.55))),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: genCountCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: '100',
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 10),
                                      border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: cs.outline.withValues(alpha: 0.3))),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(
                                              color: cs.outline.withValues(alpha: 0.3))),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          borderSide: BorderSide(color: primary)),
                                    ),
                                    onChanged: (_) => setSheet(() {}),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Preview
                        Builder(builder: (_) {
                          final prefix   = genPrefixCtrl.text;
                          final startRaw = genStartCtrl.text;
                          final countRaw = int.tryParse(genCountCtrl.text) ?? 0;
                          final startNum = int.tryParse(startRaw) ?? 1;
                          final digits   = startRaw.length.clamp(1, 10);
                          if (countRaw <= 0 || startRaw.isEmpty) return const SizedBox.shrink();
                          final previews = List.generate(
                            countRaw.clamp(0, 3),
                            (i) => '$prefix${(startNum + i).toString().padLeft(digits, '0')}',
                          );
                          final label = countRaw > 3
                              ? '${previews.join(', ')}, … ($countRaw total)'
                              : previews.join(', ');
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 13, color: primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(label,
                                      style: TextStyle(
                                          fontSize: 11, color: primary),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              final prefix   = genPrefixCtrl.text;
                              final startRaw = genStartCtrl.text;
                              final count    = int.tryParse(genCountCtrl.text) ?? 0;
                              final startNum = int.tryParse(startRaw) ?? 1;
                              final digits   = startRaw.length.clamp(1, 10);
                              if (count <= 0) return;
                              final generated = List.generate(
                                count,
                                (i) => '$prefix${(startNum + i).toString().padLeft(digits, '0')}',
                              );
                              final dupes = generated.where(line.serialNoList.contains).toList();
                              final toAdd = generated.where((s) => !line.serialNoList.contains(s)).toList();
                              if (toAdd.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: const Text('All generated serials already exist'),
                                  backgroundColor: cs.error,
                                  behavior: SnackBarBehavior.floating,
                                ));
                                return;
                              }
                              setState(() {
                                line.serialNoList = [...line.serialNoList, ...toAdd];
                                line.qty = line.serialNoList.length.toDouble();
                                line.qtyCtrl.text = _qtyFmt.format(line.qty);
                              });
                              setSheet(() {});
                              if (dupes.isNotEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text('Added ${toAdd.length}, skipped ${dupes.length} duplicates'),
                                  behavior: SnackBarBehavior.floating,
                                ));
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Generate & Add'),
                          ),
                        ),
                      ],

                      // ── Entered serial list ───────────────────────────
                      if (line.serialNoList.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        // Collapse header
                        GestureDetector(
                          onTap: () => setSheet(() => showSerialList = !showSerialList),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.list_alt_rounded, size: 14, color: primary),
                                const SizedBox(width: 6),
                                Text(
                                  '${line.serialNoList.length} serial${line.serialNoList.length == 1 ? '' : 's'} entered',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: primary),
                                ),
                                const Spacer(),
                                Icon(
                                  showSerialList
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: cs.onSurface.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (showSerialList) ...[
                          const SizedBox(height: 6),
                          ...line.serialNoList.asMap().entries.map((e) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: cs.outline.withValues(alpha: 0.15)),
                              ),
                              child: Row(
                                children: [
                                  Text('${e.key + 1}.',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface.withValues(alpha: 0.4))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(e.value,
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        line.serialNoList = [...line.serialNoList]
                                          ..removeAt(e.key);
                                        line.qty = line.serialNoList.length.toDouble();
                                        line.qtyCtrl.text = _qtyFmt.format(line.qty);
                                      });
                                      setSheet(() {});
                                    },
                                    child: Icon(Icons.close_rounded,
                                        size: 16,
                                        color: cs.onSurface.withValues(alpha: 0.4)),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ],
                    // Batch section
                    if (line.hasBatch) ...[
                      const SizedBox(height: 20),
                      Divider(
                          height: 1,
                          color: cs.outline.withValues(alpha: 0.1)),
                      const SizedBox(height: 16),
                      Text('Batch No *',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface.withValues(alpha: 0.6))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: line.batchNoCtrl,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Enter batch number',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: cs.outline.withValues(alpha: 0.3)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: cs.outline.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      dateField('Manufacture Date', mfgDate, isMfg: true),
                      const SizedBox(height: 12),
                      dateField('Expiry Date', expDate, isMfg: false),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: creating ? null : confirm,
                        child: creating
                            ? const DotsLoading()
                            : const Text('Confirm',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  // ── Section builders ──────────────────────────────────────────────

  Widget _buildDocSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label: 'Date'),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12),
          child: FieldBox(
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 18),
                const SizedBox(width: 8),
                Text(_dateFmt.format(_docDate),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
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

  Widget _buildFromPOSection() {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // PO picker
        FieldLabel(label: 'Selected PO'),
        InkWell(
          onTap: _isLoadingPO ? null : _pickPO,
          borderRadius: BorderRadius.circular(12),
          child: FieldBox(
            child: _isLoadingPO
                ? const SizedBox(
                    height: 20, child: Center(child: DotsLoading()))
                : Row(
                    children: [
                      const Icon(Icons.receipt_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _selectedPO == null
                            ? Text('Select purchase order',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.4)))
                            : Text(_selectedPO!.docNo,
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary)),
                      ),
                      if (_selectedPO != null)
                        GestureDetector(
                          onTap: () async {
                            final hasQty = _lines.any((l) => l.qty > 0);
                            if (hasQty) {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) {
                                  final cs = Theme.of(ctx).colorScheme;
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                    title: const Text('Clear PO?',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                    content: const Text(
                                      'You have items with qty entered. Clearing the PO will remove all items. Continue?',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                            backgroundColor: cs.error),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Clear'),
                                      ),
                                    ],
                                  );
                                },
                              );
                              if (confirmed != true) return;
                            }
                            setState(() {
                              _selectedPO = null;
                              _purchaseDoc = null;
                              for (final l in _lines) { l.dispose(); }
                              _lines.clear();
                            });
                          },
                          child: Icon(Icons.clear,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.4)),
                        )
                      else
                        Icon(Icons.chevron_right,
                            size: 18,
                            color: cs.onSurface.withValues(alpha: 0.3)),
                    ],
                  ),
          ),
        ),
        // Supplier card (shown once PO is selected)
        if (_selectedPO != null) ...[
        const SizedBox(height: 12),
        FieldLabel(label: 'Supplier'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline.withValues(alpha: 0.15)),
          ),
          child: _purchaseDoc == null
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: DotsLoading()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_purchaseDoc!.supplierCode,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: primary)),
                const SizedBox(height: 2),
                Text(_purchaseDoc!.supplierName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
        ),
        ], // end if (_selectedPO != null)
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

    if (_selectedPO == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 40, color: cs.onSurface.withValues(alpha: 0.25)),
              const SizedBox(height: 10),
              Text('Select a purchase order to load items',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.4))),
            ],
          ),
        ),
      );
    }

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
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Slidable(
                              key: ValueKey(i),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.48,
                                children: [
                                  CustomSlidableAction(
                                    onPressed: (_) => _openEditSheet(line),
                                    backgroundColor:
                                        const Color(0xFF1565C0).withValues(alpha: 0.12),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.edit_outlined,
                                            size: 26, color: Color(0xFF1565C0)),
                                        SizedBox(height: 4),
                                        Text('Edit',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF1565C0))),
                                      ],
                                    ),
                                  ),
                                  CustomSlidableAction(
                                    onPressed: (_) => _deleteLine(i),
                                    backgroundColor: Colors.red.withValues(alpha: 0.12),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: const [
                                        Icon(Icons.delete_outline, size: 26, color: Colors.red),
                                        SizedBox(height: 4),
                                        Text('Delete',
                                            style: TextStyle(
                                                fontSize: 10,
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
                                showImage: _showImage,
                                onStepDown: () => _stepQty(line, -1),
                                onStepUp: () => _stepQty(line, 1),
                                onQtyEditComplete: () => _clampQty(line),
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    // OutlinedButton.icon(
                    //   onPressed: _openItemPicker,
                    //   icon: const Icon(Icons.add, size: 18),
                    //   label: const Text('Add Item'),
                    //   style: OutlinedButton.styleFrom(
                    //     minimumSize: const Size(double.infinity, 44),
                    //     shape: RoundedRectangleBorder(
                    //         borderRadius: BorderRadius.circular(12)),
                    //   ),
                    // ),
                  ],
                );
    }
  }

  void _showReceivingSummary() {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    final poLines = _lines.where((l) => l.fromPO).toList();
    final totalPOItems = poLines.length;
    final fullyReceived = poLines.where((l) => l.isFullyReceived).length;
    final totalReceiveQty = _lines.fold(0.0, (s, l) => s + l.qty);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.3,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, sc) => Material(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 15),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text('Summary',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Stat cards
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: primary),
                    const SizedBox(width: 6),
                    Text('Total Received Items',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    Spacer(),
                    Text('${_lines.length}',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: primary)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Icon(Icons.move_to_inbox_outlined, size: 16, color: primary),
                    const SizedBox(width: 6),
                    Text('Total Received Qty',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    Spacer(),
                    Text(_qtyFmt.format(totalReceiveQty),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: primary)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: fullyReceived == totalPOItems ? Colors.green.withValues(alpha: 0.07) : Colors.yellow.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline, size: 16, color: primary),
                    const SizedBox(width: 6),
                    Text('Items From PO',
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                    Spacer(),
                    Text('$fullyReceived/$totalPOItems',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: primary)),
                  ],
                ),
              ),       
              const SizedBox(height: 40),
            ],
          ),
            ),
        ),
      ),
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
  final bool showImage;
  final VoidCallback onStepDown;
  final VoidCallback onStepUp;
  final VoidCallback onQtyEditComplete;

  const _LineItemCard({
    required this.index,
    required this.line,
    required this.primary,
    required this.cs,
    required this.qtyFmt,
    required this.showImage,
    required this.onStepDown,
    required this.onStepUp,
    required this.onQtyEditComplete,
  });

  Widget _badge() => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${index + 1}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: primary),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final isFullyReceived = line.isFullyReceived;
    final isPartial = line.qty > 0 && !isFullyReceived;

    final borderColor = line.fromPO
        ? isFullyReceived
            ? Colors.green.withValues(alpha: 0.45)
            : isPartial
                ? const Color(0xFFFF9700).withValues(alpha: 0.45)
                : primary.withValues(alpha: 0.2)
        : cs.outline.withValues(alpha: 0.18);

    final receiveQtyColor = line.fromPO
        ? isFullyReceived
            ? Colors.green
            : isPartial
                ? const Color(0xFFFF9700)
                : cs.onSurface.withValues(alpha: 0.45)
        : cs.onSurface.withValues(alpha: 0.45);

    // Leading: image or index badge
    Widget leading;
    if (showImage && line.itemImage != null && line.itemImage!.isNotEmpty) {
      try {
        final raw = line.itemImage!.contains(',')
            ? line.itemImage!.split(',').last
            : line.itemImage!;
        leading = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(raw),
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _badge(),
          ),
        );
      } catch (_) {
        leading = _badge();
      }
    } else {
      leading = _badge();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: (line.fromPO && isFullyReceived)
            ? Colors.green.withValues(alpha: 0.04)
            : (Theme.of(context).cardTheme.color ?? cs.surface).withValues(alpha: 0.5),
        border: Border.all(color: borderColor),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: image/badge + code / description / uom
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          if (isFullyReceived)
                            const Icon(Icons.check_circle_rounded,
                                size: 16, color: Colors.green),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line.description,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.65)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        line.uom,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Ordered qty | stepper (full width)
            Row(
              children: [
                if (line.fromPO && line.orderedQty > 0)
                  Text(
                    'Ordered: ${qtyFmt.format(line.orderedQty)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.45)),
                  ),
                const Spacer(),
                _QtyStepper(
                  ctrl: line.qtyCtrl,
                  primary: primary,
                  cs: cs,
                  qtyColor: receiveQtyColor,
                  onStepDown: onStepDown,
                  onStepUp: onStepUp,
                  onEditComplete: onQtyEditComplete,
                ),
              ],
            ),
            // Progress bar (PO items only)
            if (line.fromPO && line.orderedQty > 0) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (line.qty / line.orderedQty).clamp(0.0, 1.0),
                  backgroundColor: cs.outline.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isFullyReceived
                        ? Colors.green
                        : const Color(0xFFFF9700),
                  ),
                  minHeight: 3,
                ),
              ),
            ],
            // Batch indicator
            if (line.hasBatch) ...[
              const SizedBox(height: 6),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: line.batchNoCtrl,
                builder: (_, v, __) {
                  final text = v.text.trim();
                  final missing = text.isEmpty;
                  return Row(
                    children: [
                      Icon(Icons.tag_rounded,
                          size: 12,
                          color: missing
                              ? Colors.red.withValues(alpha: 0.7)
                              : cs.onSurface.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(
                        missing ? 'Batch no required' : text,
                        style: TextStyle(
                            fontSize: 11,
                            fontStyle: missing
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: missing
                                ? Colors.red.withValues(alpha: 0.8)
                                : primary),
                      ),
                    ],
                  );
                },
              ),
            ],
            // Serial indicator
            if (line.hasSerial) ...[
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final entered = line.serialNoList.length;
                final needed = line.qty.toInt();
                final ok = entered > 0 && entered == needed;
                final color = ok
                    ? Colors.green
                    : entered == 0
                        ? Colors.red.withValues(alpha: 0.8)
                        : const Color(0xFFFF9700);
                return Row(
                  children: [
                    Icon(Icons.qr_code_rounded, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(
                      entered == 0
                          ? 'Serial no. required'
                          : '$entered${needed > 0 ? '/$needed' : ''} serial${entered == 1 ? '' : 's'}',
                      style: TextStyle(
                          fontSize: 11,
                          fontStyle: entered == 0
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: color),
                    ),
                  ],
                );
              }),
            ],
          ],
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
  final Color? qtyColor;
  final ColorScheme cs;
  final VoidCallback onStepDown;
  final VoidCallback onStepUp;
  final VoidCallback onEditComplete;

  const _QtyStepper({
    required this.ctrl,
    required this.primary,
    required this.cs,
    this.qtyColor,
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
                color: qtyColor ?? primary),
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
