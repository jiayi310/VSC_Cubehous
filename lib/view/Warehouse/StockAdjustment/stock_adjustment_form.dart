import 'dart:convert';
import 'package:cubehous/models/stock_adjustment.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';
import '../../../models/stock.dart';
import '../../../models/storage.dart';
import '../../Common/decoration.dart';
import '../../Common/Location/location_picker.dart';
import '../../Common/Stock/item_picker_page.dart';

// ─────────────────────────────────────────────────────────────────────
// Local working item (not a model, lives only during form editing)
// ─────────────────────────────────────────────────────────────────────

class _StockAdjustmentItem {
  int stockID;
  int stockBatchID;
  String stockCode;
  String description;
  String uom;
  double qty;
  int storageID;
  String storageCode;
  int locationID;
  String? itemImage;

  _StockAdjustmentItem({
    this.stockID = 0,
    this.stockBatchID = 0,
    this.stockCode = '',
    this.description = '',
    this.uom = '',
    this.qty = 1.0,
    this.storageID = 0,
    this.storageCode = '',
    this.locationID = 0,
    this.itemImage,
  });
}

// ─────────────────────────────────────────────────────────────────────
// StockAdjustmentFormPage
// ─────────────────────────────────────────────────────────────────────

class StockAdjustmentFormPage extends StatefulWidget {
  final StockAdjustmentDoc? initialDoc;
  const StockAdjustmentFormPage({super.key, this.initialDoc});

  @override
  State<StockAdjustmentFormPage> createState() => _StockAdjustmentFormPageState();
}

class _StockAdjustmentFormPageState extends State<StockAdjustmentFormPage> {
  bool get _isEdit => widget.initialDoc != null;

  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  int _companyID = 0;
  String _userSessionID = '';

  // Form state
  DateTime _docDate = DateTime.now();
  final _descController = TextEditingController();
  final _remarkController = TextEditingController();
  int _locationID = 0;
  String _locationName = '';

  // Items
  final List<_StockAdjustmentItem> _items = [];

  // UI state
  bool _isScannerMode = false;
  bool _saving = false;
  bool _initLoading = true;
  bool _showImage = true;
  bool _docExpanded = true;
  bool _notesExpanded = true;
  bool _locationExpanded = true;
  bool _itemsExpanded = true;
  final Map<String, bool> _storageExpanded = {};

  // Scanner sub-state
  bool _scanningStorage = true;
  int _scannedStorageID = 0;
  String _scannedStorageCode = '';
  final MobileScannerController _scannerController = MobileScannerController();
  bool _scannerPaused = false;

  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _qtyFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _descController.dispose();
    _remarkController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final results = await Future.wait([
      SessionManager.getApiKey(),
      SessionManager.getCompanyGUID(),
      SessionManager.getUserID(),
      SessionManager.getCompanyID(),
      SessionManager.getUserSessionID(),
      SessionManager.getDefaultLocationID(),
      SessionManager.getImageMode(),
    ]);
    _apiKey = results[0] as String;
    _companyGUID = results[1] as String;
    _userID = results[2] as int;
    _companyID = results[3] as int;
    _userSessionID = results[4] as String;
    final defaultLocationID = results[5] as int;
    _showImage = (results[6] as String) == 'show';

    if (_isEdit) {
      final doc = widget.initialDoc!;
      _locationID = doc.locationID;
      _locationName = doc.location;
      try {
        _docDate = DateTime.parse(doc.docDate);
      } catch (_) {
        _docDate = DateTime.now();
      }
      _descController.text = doc.description ?? '';
      _remarkController.text = doc.remark ?? '';
      for (final line in doc.stockAdjustmentDetails) {
        _items.add(_StockAdjustmentItem(
          stockID: line.stockID,
          stockBatchID: line.stockBatchID,
          stockCode: line.stockCode,
          description: line.description,
          uom: line.uom,
          qty: line.qty,
          storageID: line.storageID,
          storageCode: line.storageCode,
          locationID: line.locationID,
        ));
      }
    } else {
      _locationID = defaultLocationID;
      // Load location name
      try {
        final resp = await BaseClient.post(
          ApiEndpoints.getLocationList,
          body: {
            'apiKey': _apiKey,
            'companyGUID': _companyGUID,
            'userID': _userID,
            'userSessionID': _userSessionID,
          },
        );
        if (resp is List<dynamic>) {
          for (final e in resp) {
            final loc = e as Map<String, dynamic>;
            if ((loc['locationID'] as int?) == _locationID) {
              _locationName = (loc['location'] as String?) ?? '';
              break;
            }
          }
        }
      } catch (_) {}
    }

    if (!_isEdit) await _checkAndRestoreDraft();
    if (mounted) setState(() => _initLoading = false);
  }

  // ── Draft helpers ─────────────────────────────────────────────────

  bool get _hasChanges =>
      _items.isNotEmpty ||
      _descController.text.isNotEmpty ||
      _remarkController.text.isNotEmpty;

  Future<void> _saveDraft() async {
    final draft = {
      'docDate': _docDate.toIso8601String(),
      'locationID': _locationID,
      'locationName': _locationName,
      'description': _descController.text,
      'remark': _remarkController.text,
      'items': _items
          .map((i) => {
                'stockID': i.stockID,
                'stockBatchID': i.stockBatchID,
                'stockCode': i.stockCode,
                'description': i.description,
                'uom': i.uom,
                'qty': i.qty,
                'storageID': i.storageID,
                'storageCode': i.storageCode,
                'locationID': i.locationID,
                'itemImage': i.itemImage,
              })
          .toList(),
    };
    await SessionManager.saveStockAdjustmentDraft(jsonEncode(draft));
  }

  void _restoreDraft(Map<String, dynamic> j) {
    _docDate =
        DateTime.tryParse(j['docDate'] as String? ?? '') ?? DateTime.now();
    _locationID = (j['locationID'] as int?) ?? _locationID;
    _locationName = (j['locationName'] as String?) ?? _locationName;
    _descController.text = (j['description'] as String?) ?? '';
    _remarkController.text = (j['remark'] as String?) ?? '';
    for (final raw in (j['items'] as List<dynamic>? ?? [])) {
      final m = raw as Map<String, dynamic>;
      _items.add(_StockAdjustmentItem(
        stockID: (m['stockID'] as int?) ?? 0,
        stockBatchID: (m['stockBatchID'] as int?) ?? 0,
        stockCode: (m['stockCode'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        uom: (m['uom'] as String?) ?? '',
        qty: ((m['qty'] as num?) ?? 1.0).toDouble(),
        storageID: (m['storageID'] as int?) ?? 0,
        storageCode: (m['storageCode'] as String?) ?? '',
        locationID: (m['locationID'] as int?) ?? 0,
        itemImage: m['itemImage'] as String?,
      ));
    }
  }

  Future<void> _checkAndRestoreDraft() async {
    final raw = await SessionManager.getStockAdjustmentDraft();
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) setState(() => _restoreDraft(j));
    } catch (_) {
      await SessionManager.clearStockAdjustmentDraft();
    }
  }

  Future<bool> _onWillPop() async {
    if (_isScannerMode) {
      setState(() => _isScannerMode = false);
      return false;
    }
    if (_isEdit || !_hasChanges) return true;
    final result = await showDialog<String>(
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
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.save_outlined,
                    size: 30, color: cs.primary),
              ),
              const SizedBox(height: 16),
              const Text('Save Draft?',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24),
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
                            Navigator.pop(ctx, 'discard'),
                        child: Text('Discard',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface
                                    .withValues(alpha: 0.5))),
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
                                bottomRight: Radius.circular(20)),
                          ),
                        ),
                        onPressed: () =>
                            Navigator.pop(ctx, 'save'),
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
    if (result == 'discard') await SessionManager.clearStockAdjustmentDraft();
    return true;
  }

  // ── Location Picker ───────────────────────────────────────────────

  Future<void> _pickLocation() async {
    final result = await Navigator.push<({int locationID, String locationName})>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          module: "STOCKADJUSTMENT",
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _locationID = result.locationID;
        _locationName = result.locationName;
        // Clear items when location changes
        _items.clear();
      });
    }
  }

  // ── Date Picker ───────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && mounted) {
      setState(() => _docDate = picked);
    }
  }

  // ── Manual Add Item Flow ──────────────────────────────────────────

  Future<void> _startManualItemAdd() async {
    if (_locationID == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Please select a location first'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }

    // Step 1: pick storage
    final storage = await Navigator.push<StorageDropdownDto>(
      context,
      MaterialPageRoute(
        builder: (_) => StoragePickerPage(
          module: "STOCKADJUSTMENT",
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
          locationID: _locationID,
        ),
      ),
    );
    if (storage == null || !mounted) return;

    // Step 2: pick stock — sheet handled inside ItemPickerPage, stays open
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ItemPickerPage(
          module: 'STOCKADJUSTMENT',
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
          onItemAdded: (stock, uom, qty) {
            if (mounted) {
              setState(() => _items.add(_StockAdjustmentItem(
                    stockID: stock.stockID,
                    stockBatchID: 0,
                    stockCode: stock.stockCode,
                    description: stock.description,
                    uom: uom,
                    qty: qty,
                    storageID: storage.storageID,
                    storageCode: storage.storageCode ?? '',
                    locationID: _locationID,
                    itemImage: stock.image,
                  )));
            }
          },
        ),
      ),
    );
  }

  // ── Scanner helpers ───────────────────────────────────────────────

  void _onStorageQrDetected(String value) {
    if (_scannerPaused) return;
    _scannerPaused = true;

    int locID = 0;
    int storageID = 0;
    String storageCode = '';

    // Try JSON first
    try {
      final map = jsonDecode(value) as Map<String, dynamic>;
      locID = (map['locationID'] as int?) ?? 0;
      storageID = (map['storageID'] as int?) ?? 0;
      storageCode = (map['storageCode'] as String?) ?? '';
    } catch (_) {
      // Try pipe-separated
      final parts = value.split('|');
      if (parts.length >= 3) {
        locID = int.tryParse(parts[0]) ?? 0;
        storageID = int.tryParse(parts[1]) ?? 0;
        storageCode = parts[2];
      }
    }

    if (storageID == 0 || storageCode.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Invalid storage QR code'),
            behavior: SnackBarBehavior.floating,
          ));
      }
      Future.delayed(const Duration(seconds: 2),
          () => _scannerPaused = false);
      return;
    }

    // If locationID in QR differs, update it
    if (locID != 0 && locID != _locationID) {
      _locationID = locID;
    }

    if (mounted) {
      setState(() {
        _scannedStorageID = storageID;
        _scannedStorageCode = storageCode;
        _scanningStorage = false;
        _scannerPaused = false;
      });
    }
  }

  Future<void> _onItemBarcodeDetected(String value) async {
    if (_scannerPaused) return;
    _scannerPaused = true;

    try {
      final resp = await BaseClient.post(
        ApiEndpoints.getStockByBarcode,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'stockCodeOrBarcode': value,
          'companyID': _companyID,
        },
      );

      if (resp == null || resp is! Map<String, dynamic>) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text('Item not found: $value'),
              behavior: SnackBarBehavior.floating,
            ));
        }
        _scannerPaused = false;
        return;
      }

      final stock = Stock.fromJson(resp);

      if (!mounted) return;

      // Show qty dialog
      final qty = await _showQtyDialog(stock);
      if (qty != null && mounted) {
        setState(() {
          _items.add(_StockAdjustmentItem(
            stockID: stock.stockID,
            stockBatchID: 0,
            stockCode: stock.stockCode,
            description: stock.description,
            uom: stock.baseUOM,
            qty: qty,
            storageID: _scannedStorageID,
            storageCode: _scannedStorageCode,
            locationID: _locationID,
            itemImage: stock.image,
          ));
        });
      }
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
      _scannerPaused = false;
    }
  }

  Future<double?> _showQtyDialog(Stock stock) async {
    final controller = TextEditingController(text: '1');
    double qty = 1.0;
    return showDialog<double>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Enter Quantity',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stock.stockCode,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.primary)),
                const SizedBox(height: 2),
                Text(stock.description,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        final v = double.tryParse(controller.text) ?? 1.0;
                        final newV = (v - 1.0).clamp(1.0, double.infinity);
                        controller.text = _qtyFmt.format(newV);
                        setDialogState(() => qty = newV);
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (v) {
                          final parsed = double.tryParse(v);
                          if (parsed != null) qty = parsed.clamp(1.0, double.infinity);
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        final v = double.tryParse(controller.text) ?? 1.0;
                        final newV = v + 1.0;
                        controller.text = _qtyFmt.format(newV);
                        setDialogState(() => qty = newV);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final v = double.tryParse(controller.text) ?? qty;
                  Navigator.pop(ctx, v.clamp(1.0, double.infinity));
                },
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Save ──────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_locationID == 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Please select a location'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    if (_items.isEmpty) {
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
      final details = _items
          .map((item) => {
                'dtlID': 0,
                'docID': _isEdit ? widget.initialDoc!.docID : 0,
                'stockID': item.stockID,
                'stockBatchID': item.stockBatchID,
                'batchNo': '',
                'stockCode': item.stockCode,
                'description': item.description,
                'uom': item.uom,
                'qty': item.qty,
                'locationID': item.locationID,
                'storageID': item.storageID,
                'storageCode': item.storageCode,
              })
          .toList();

      final now = DateTime.now().toIso8601String();
      final form = {
        'docID': _isEdit ? widget.initialDoc!.docID : 0,
        'docNo': '',
        'docDate': _docDate.toIso8601String(),
        'description': _descController.text,
        'remark': _remarkController.text,
        'isMerge': false,
        'mergeDocID': 0,
        'mergeDocNo': '',
        'mergeDate': now,
        'isAdjustment': false,
        'adjustmentDocID': 0,
        'adjustmentDocNo': '',
        'adjustmentDate': now,
        'isVoid': false,
        'lastModifiedDateTime': now,
        'lastModifiedUserID': _userID,
        'createdDateTime': now,
        'createdUserID': _userID,
        'locationID': _locationID,
        'location': _locationName,
        'stockAdjustmentDetails': details,
      };

      await BaseClient.post(
        _isEdit ? ApiEndpoints.updateStockAdjustment : ApiEndpoints.createStockAdjustment,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'stockAdjustmentForm': form,
        },
      );

      if (!_isEdit) await SessionManager.clearStockAdjustmentDraft();
      if (mounted) Navigator.pop(context, true);
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

  // ── Storage-grouped items (manual mode) ──────────────────────────

  List<Widget> _buildStorageGroups() {
    // Collect unique storage codes in insertion order
    final storages = <String>[];
    for (final item in _items) {
      if (!storages.contains(item.storageCode)) {
        storages.add(item.storageCode);
      }
    }
    if (storages.isEmpty) return [];

    final primary = Theme.of(context).colorScheme.primary;
    final widgets = <Widget>[];

    for (final storageCode in storages) {
      final storageEntries = _items
          .asMap()
          .entries
          .where((e) => e.value.storageCode == storageCode)
          .toList();
      final expanded = _storageExpanded[storageCode] ?? true;

      // Sub-section header for this storage
      widgets.add(
        GestureDetector(
          onTap: () => setState(
              () => _storageExpanded[storageCode] = !expanded),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warehouse_outlined,
                          size: 13, color: primary),
                      const SizedBox(width: 4),
                      Text(
                        storageCode.isEmpty
                            ? '(No Storage)'
                            : storageCode,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: primary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${storageEntries.length}',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: primary),
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: expanded ? 0 : -0.25,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: primary.withValues(alpha: 0.6)),
                ),
              ],
            ),
          ),
        ),
      );

      // Collapsible items for this storage
      widgets.add(
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: expanded
              ? Column(
                  children: storageEntries.map((e) {
                    final globalIdx = e.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Slidable(
                        key: ValueKey(globalIdx),
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: 0.26,
                          children: [
                            CustomSlidableAction(
                              onPressed: (_) => setState(
                                  () => _items.removeAt(globalIdx)),
                              backgroundColor:
                                  Colors.red.withValues(alpha: 0.12),
                              child: const Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.delete_outline,
                                      size: 22, color: Colors.red),
                                  SizedBox(height: 4),
                                  Text('Delete',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        child: _ItemCard(
                          index: globalIdx,
                          item: e.value,
                          qtyFmt: _qtyFmt,
                          showImage: _showImage,
                        ),
                      ),
                    );
                  }).toList(),
                )
              : const SizedBox.shrink(),
        ),
      );
    }

    return widgets;
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_initLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit Stock Take' : 'New Stock Take',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          centerTitle: true,
        ),
        body: const Center(child: DotsLoading()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await _onWillPop();
        if (shouldPop) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? 'Edit Stock Take' : 'New Stock Take',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(_isScannerMode
                  ? Icons.edit_note_outlined
                  : Icons.qr_code_scanner),
              tooltip: _isScannerMode ? 'Manual Mode' : 'Scanner Mode',
              onPressed: () {
                setState(() {
                  _isScannerMode = !_isScannerMode;
                  if (_isScannerMode) {
                    _scanningStorage = true;
                    _scannedStorageID = 0;
                    _scannedStorageCode = '';
                    _scannerPaused = false;
                  }
                });
              },
            ),
          ],
        ),
        body: _isScannerMode
            ? _buildScannerBody()
            : Column(
                children: [
                  Expanded(child: _buildManualBody()),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const DotsLoading(dotSize: 6)
                            : Text(
                                _isEdit ? 'Update' : 'Save',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Manual Mode Body ──────────────────────────────────────────────

  Widget _buildManualBody() {
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Document (Date) ───────────────────────────────────
          _sectionHeader(Icons.receipt_long_outlined, 'Document',
              expanded: _docExpanded,
              onToggle: () => setState(() => _docExpanded = !_docExpanded)),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _docExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel(label: 'Date'),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(12),
                        child: _fieldBox(
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined, size: 18),
                              const SizedBox(width: 8),
                              Text(_dateFmt.format(_docDate),
                                  style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // ── Notes ─────────────────────────────────────────────
          _sectionHeader(Icons.notes_outlined, 'Notes',
              expanded: _notesExpanded,
              onToggle: () => setState(() => _notesExpanded = !_notesExpanded)),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _notesExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel(label: 'Description'),
                      TextFormField(
                        controller: _descController,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 14),
                        decoration: formInputDeco(context),
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel(label: 'Remark'),
                      TextFormField(
                        controller: _remarkController,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 14),
                        decoration: formInputDeco(context),
                      ),
                      const SizedBox(height: 4),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // ── Location ──────────────────────────────────────────
          _sectionHeader(Icons.location_on_outlined, 'Location',
              expanded: _locationExpanded,
              onToggle: () => setState(() => _locationExpanded = !_locationExpanded)),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _locationExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel(label: 'Location *'),
                      InkWell(
                        onTap: _pickLocation,
                        borderRadius: BorderRadius.circular(12),
                        child: _fieldBox(
                          child: Row(
                            children: [
                              const Icon(Icons.location_on_outlined, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _locationName.isNotEmpty
                                    ? Text(_locationName,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600))
                                    : Text('Select location',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.4))),
                              ),
                              Icon(Icons.chevron_right,
                                  size: 18,
                                  color: cs.onSurface.withValues(alpha: 0.3)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          // ── Items ─────────────────────────────────────────────
          _sectionHeader(Icons.list_alt_outlined, 'Items',
              expanded: _itemsExpanded,
              onToggle: () =>
                  setState(() => _itemsExpanded = !_itemsExpanded),
              badge: '${_items.length}'),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: _itemsExpanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SlidableAutoCloseBehavior(
                        child: Column(
                          children: _buildStorageGroups(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _startManualItemAdd,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Item'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Section header (matches quotation form style) ─────────────────

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

  // ── Field helpers (match quotation form style) ────────────────────

  Widget _fieldLabel({required String label}) {
    return Padding(
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

  Widget _fieldBox({required Widget child}) {
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

  // ── Scanner Mode Body ─────────────────────────────────────────────

  Widget _buildScannerBody() {
    return _scanningStorage
        ? _buildStorageScanView()
        : _buildItemScanView();
  }

  Widget _buildStorageScanView() {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            final barcode = capture.barcodes.first;
            final value = barcode.rawValue;
            if (value != null) _onStorageQrDetected(value);
          },
        ),
        // Overlay
        Positioned.fill(
          child: Container(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: cs.primary, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Scan Storage QR Code',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemScanView() {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return Column(
      children: [
        // Storage info bar
        Container(
          color: primary.withValues(alpha: 0.08),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.warehouse_outlined,
                  size: 18, color: primary),
              const SizedBox(width: 8),
              Text(
                'Storage: $_scannedStorageCode',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primary),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _scanningStorage = true;
                    _scannedStorageID = 0;
                    _scannedStorageCode = '';
                    _scannerPaused = false;
                  });
                },
                style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('Change'),
              ),
            ],
          ),
        ),

        // Scanner view (~40% height)
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.38,
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  final barcode = capture.barcodes.first;
                  final value = barcode.rawValue;
                  if (value != null) _onItemBarcodeDetected(value);
                },
              ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 200,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.7),
                          width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scanned items for this storage
        Expanded(
          child: _items
                  .where((item) =>
                      item.storageID == _scannedStorageID)
                  .isEmpty
              ? Center(
                  child: Text(
                    'Scan an item barcode',
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.4)),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: _items
                      .where((item) =>
                          item.storageID == _scannedStorageID)
                      .length,
                  itemBuilder: (_, i) {
                    final storageItems = _items
                        .where((item) =>
                            item.storageID == _scannedStorageID)
                        .toList();
                    final globalIndex = _items.indexOf(storageItems[i]);
                    return _ItemCard(
                      index: globalIndex,
                      item: storageItems[i],
                      qtyFmt: _qtyFmt,
                      showImage: _showImage,
                      onDelete: () =>
                          setState(() => _items.removeAt(globalIndex)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Item Card (form list)
// ─────────────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final int index;
  final _StockAdjustmentItem item;
  final NumberFormat qtyFmt;
  final VoidCallback? onDelete;
  final bool showImage;

  const _ItemCard({
    required this.index,
    required this.item,
    required this.qtyFmt,
    this.onDelete,
    this.showImage = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    // Build leading: image or index badge
    Widget leading;
    final rawImage = item.itemImage;
    if (showImage && rawImage != null && rawImage.isNotEmpty) {
      try {
        final raw = rawImage.contains(',')
            ? rawImage.split(',').last
            : rawImage;
        leading = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(raw),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _indexBadge(primary),
          ),
        );
      } catch (_) {
        leading = _indexBadge(primary);
      }
    } else {
      leading = _indexBadge(primary);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: (Theme.of(context).cardTheme.color ?? cs.surface)
              .withValues(alpha: 0.5),
          border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: stockCode | qty
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.stockCode,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: primary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'x ${qtyFmt.format(item.qty)}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: primary),
                      ),
                    ],
                  ),
                  // Row 2: description
                  const SizedBox(height: 2),
                  Text(
                    item.description,
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.65)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Row 3: UOM | Spacer | delete (scanner mode only)
                  Row(
                    children: [
                      Text(item.uom,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurface.withValues(alpha: 0.5))),
                      const Spacer(),
                      if (onDelete != null)
                        GestureDetector(
                          onTap: onDelete,
                          child: Icon(Icons.delete_outline,
                              size: 20,
                              color: Colors.red.withValues(alpha: 0.7)),
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

  Widget _indexBadge(Color primary) => Container(
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
                fontSize: 13, fontWeight: FontWeight.w700, color: primary),
          ),
        ),
      );
}
