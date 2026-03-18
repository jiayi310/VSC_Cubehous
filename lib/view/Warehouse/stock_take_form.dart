import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../common/session_manager.dart';
import '../../models/stock.dart';
import '../../models/stock_take.dart';
import '../../models/storage.dart';

// ─────────────────────────────────────────────────────────────────────
// Local working item (not a model, lives only during form editing)
// ─────────────────────────────────────────────────────────────────────

class _StockTakeItem {
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

  _StockTakeItem({
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
// StockTakeFormPage
// ─────────────────────────────────────────────────────────────────────

class StockTakeFormPage extends StatefulWidget {
  final StockTakeDoc? initialDoc;
  const StockTakeFormPage({super.key, this.initialDoc});

  @override
  State<StockTakeFormPage> createState() => _StockTakeFormPageState();
}

class _StockTakeFormPageState extends State<StockTakeFormPage> {
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
  final List<_StockTakeItem> _items = [];

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
      for (final line in doc.stockTakeDetails) {
        _items.add(_StockTakeItem(
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

    if (mounted) setState(() => _initLoading = false);
  }

  // ── Location Picker ───────────────────────────────────────────────

  Future<void> _pickLocation() async {
    final result = await Navigator.push<({int locationID, String locationName})>(
      context,
      MaterialPageRoute(
        builder: (_) => _LocationPickerPage(
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
        builder: (_) => _StoragePickerPage(
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
          locationID: _locationID,
        ),
      ),
    );
    if (storage == null || !mounted) return;

    // Step 2: pick stock (stays open, items added via callback)
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StockPickerPage(
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          companyID: _companyID,
          userSessionID: _userSessionID,
          selectedStorage: storage,
          locationID: _locationID,
          onItemAdded: (item) {
            if (mounted) setState(() => _items.add(item));
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
          _items.add(_StockTakeItem(
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
        'stockTakeDetails': details,
      };

      await BaseClient.post(
        _isEdit ? ApiEndpoints.updateStockTake : ApiEndpoints.createStockTake,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'stockTakeForm': form,
        },
      );

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
        if (_isScannerMode) {
          setState(() => _isScannerMode = false);
          return;
        }
        Navigator.of(context).pop();
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
                                _isEdit ? 'Update Stock Take' : 'Create Stock Take',
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
                        decoration: _inputDeco(''),
                      ),
                      const SizedBox(height: 12),
                      _fieldLabel(label: 'Remark'),
                      TextFormField(
                        controller: _remarkController,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 14),
                        decoration: _inputDeco(''),
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
                      _fieldLabel(label: 'Warehouse Location *'),
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

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      labelStyle: TextStyle(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.4)),
      filled: true,
      isDense: true,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary, width: 1.5),
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
  final _StockTakeItem item;
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

// ─────────────────────────────────────────────────────────────────────
// Location Picker Page
// ─────────────────────────────────────────────────────────────────────

class _LocationPickerPage extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  const _LocationPickerPage({
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
  });

  @override
  State<_LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<_LocationPickerPage> {
  List<Map<String, dynamic>> _locations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await BaseClient.post(
        ApiEndpoints.getLocationList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
        },
      );
      if (resp is List<dynamic>) {
        setState(() {
          _locations = resp.cast<Map<String, dynamic>>();
          _loading = false;
        });
      } else {
        setState(() {
          _locations = [];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: DotsLoading())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.6)),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _locations.length,
                  itemBuilder: (_, i) {
                    final loc = _locations[i];
                    final id = (loc['locationID'] as int?) ?? 0;
                    final name = (loc['location'] as String?) ?? '';
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.location_on_outlined,
                            size: 20, color: primary),
                      ),
                      title: Text(name,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                      onTap: () => Navigator.pop(
                          context, (locationID: id, locationName: name)),
                    );
                  },
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Storage Picker Page
// ─────────────────────────────────────────────────────────────────────

class _StoragePickerPage extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;
  final int locationID;

  const _StoragePickerPage({
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
    required this.locationID,
  });

  @override
  State<_StoragePickerPage> createState() => _StoragePickerPageState();
}

class _StoragePickerPageState extends State<_StoragePickerPage> {
  List<StorageDropdownDto> _storages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getLocationWithStorage,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'locationID': widget.locationID,
        },
      );

      List<StorageDropdownDto> items = [];
      if (response is List<dynamic> && response.isNotEmpty) {
        final first = response.first as Map<String, dynamic>;
        final raw = first['storageDropdownDtoList'];
        if (raw is List<dynamic>) {
          items = raw
              .map((e) =>
                  StorageDropdownDto.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      setState(() {
        _storages = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Storage',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: DotsLoading())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .error
                                .withValues(alpha: 0.6)),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _storages.isEmpty
                  ? Center(
                      child: Text('No storages found',
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4))),
                    )
                  : ListView.builder(
                      itemCount: _storages.length,
                      itemBuilder: (_, i) {
                        final s = _storages[i];
                        final disabled = s.isDisabled;
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: disabled
                                  ? Colors.grey.withValues(alpha: 0.1)
                                  : primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.warehouse_outlined,
                                size: 20,
                                color: disabled ? Colors.grey : primary),
                          ),
                          title: Text(
                            s.storageCode ?? '',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: disabled
                                    ? Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.35)
                                    : null),
                          ),
                          subtitle: disabled
                              ? Text('Disabled',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey
                                          .withValues(alpha: 0.6)))
                              : null,
                          enabled: !disabled,
                          onTap: disabled
                              ? null
                              : () => Navigator.pop(context, s),
                        );
                      },
                    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Stock Picker Page
// ─────────────────────────────────────────────────────────────────────

class _StockPickerPage extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final int userID;
  final int companyID;
  final String userSessionID;
  final StorageDropdownDto selectedStorage;
  final int locationID;
  final void Function(_StockTakeItem item) onItemAdded;

  const _StockPickerPage({
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.companyID,
    required this.userSessionID,
    required this.selectedStorage,
    required this.locationID,
    required this.onItemAdded,
  });

  @override
  State<_StockPickerPage> createState() => _StockPickerPageState();
}

class _StockPickerPageState extends State<_StockPickerPage> {
  static const _pageSize = 20;

  List<Stock> _stocks = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  final _scrollController = ScrollController();
  final _qtyFmt = NumberFormat('#,##0.##');

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetch(page: 0);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _fetchMore();
      }
    }
  }

  Future<void> _fetch({required int page}) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
      if (page == 0) _stocks = [];
    });
    try {
      final resp = await BaseClient.post(
        ApiEndpoints.getStockList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'companyID': widget.companyID,
          'pageIndex': page,
          'pageSize': _pageSize,
          'searchTerm': _searchQuery.isEmpty ? '' : _searchQuery,
        },
      );
      final result =
          StockResponse.fromJson(resp as Map<String, dynamic>);
      final items = result.data ?? [];
      final total = result.pagination?.totalRecord ?? items.length;
      setState(() {
        _stocks = page == 0 ? items : [..._stocks, ...items];
        _currentPage = page;
        _hasMore = _stocks.length < total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final resp = await BaseClient.post(
        ApiEndpoints.getStockList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'companyID': widget.companyID,
          'pageIndex': _currentPage + 1,
          'pageSize': _pageSize,
          'searchTerm': _searchQuery.isEmpty ? '' : _searchQuery,
        },
      );
      final result =
          StockResponse.fromJson(resp as Map<String, dynamic>);
      final items = result.data ?? [];
      final total = result.pagination?.totalRecord ?? _stocks.length;
      setState(() {
        _stocks = [..._stocks, ...items];
        _currentPage = _currentPage + 1;
        _hasMore = _stocks.length < total;
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() => _isLoadingMore = false);
    }
  }

  void _onSearchSubmit(String value) {
    setState(() {
      _searchQuery = value.trim();
      _hasMore = true;
    });
    _fetch(page: 0);
  }

  Future<void> _onStockTap(Stock stock) async {
    final cs = Theme.of(context).colorScheme;
    final uomController =
        TextEditingController(text: stock.baseUOM);
    final qtyController = TextEditingController(text: '1');
    double qty = 1.0;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                Text(stock.stockCode,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.primary)),
                const SizedBox(height: 2),
                Text(stock.description,
                    style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withValues(alpha: 0.65))),
                const SizedBox(height: 20),
                // UOM field
                TextField(
                  controller: uomController,
                  decoration: InputDecoration(
                    labelText: 'UOM',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                // Qty stepper
                Row(
                  children: [
                    Text('Quantity',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.primary)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        final v =
                            double.tryParse(qtyController.text) ??
                                1.0;
                        final newV = (v - 1.0).clamp(1.0, double.infinity);
                        qtyController.text =
                            _qtyFmt.format(newV);
                        setSheetState(() => qty = newV);
                      },
                    ),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: qtyController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[\d.]')),
                        ],
                        decoration: InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                        ),
                        onChanged: (v) {
                          final parsed = double.tryParse(v);
                          if (parsed != null) {
                            qty = parsed.clamp(1.0, double.infinity);
                          }
                        },
                        onEditingComplete: () {
                          final v =
                              double.tryParse(qtyController.text) ??
                                  1.0;
                          qty = v.clamp(1.0, double.infinity);
                          qtyController.text = _qtyFmt.format(qty);
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        final v =
                            double.tryParse(qtyController.text) ??
                                1.0;
                        final newV = v + 1.0;
                        qtyController.text =
                            _qtyFmt.format(newV);
                        setSheetState(() => qty = newV);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Done',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true) {
      final finalQty =
          (double.tryParse(qtyController.text) ?? qty).clamp(1.0, double.infinity);
      final finalUom =
          uomController.text.isNotEmpty ? uomController.text : stock.baseUOM;

      widget.onItemAdded(_StockTakeItem(
        stockID: stock.stockID,
        stockBatchID: 0,
        stockCode: stock.stockCode,
        description: stock.description,
        uom: finalUom,
        qty: finalQty,
        storageID: widget.selectedStorage.storageID,
        storageCode: widget.selectedStorage.storageCode ?? '',
        locationID: widget.locationID,
        itemImage: stock.image,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('${stock.stockCode} added'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Select Product (${widget.selectedStorage.storageCode ?? ''})',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmit,
              onChanged: (v) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search stock...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                          _fetch(page: 0);
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: DotsLoading())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48,
                            color: cs.error.withValues(alpha: 0.6)),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                            onPressed: () => _fetch(page: 0),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _stocks.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No results for "$_searchQuery"'
                            : 'No stock items found',
                        style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withValues(alpha: 0.45)),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _stocks.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i == _stocks.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: DotsLoading()),
                          );
                        }
                        final stock = _stocks[i];
                        return ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                stock.stockCode.isNotEmpty
                                    ? stock.stockCode[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: primary),
                              ),
                            ),
                          ),
                          title: Text(stock.stockCode,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: primary)),
                          subtitle: Text(stock.description,
                              style: const TextStyle(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              stock.baseUOM,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: primary),
                            ),
                          ),
                          onTap: () => _onStockTap(stock),
                        );
                      },
                    ),
    );
  }
}
