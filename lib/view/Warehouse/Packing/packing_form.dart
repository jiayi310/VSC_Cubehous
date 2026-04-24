import 'dart:convert';
import 'package:cubehous/models/packing.dart';
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
import '../../Common/Stock/item_picker_page.dart';
import '../../../models/sales.dart';
import '../../../models/shipping_method.dart';
import '../../../models/stock.dart';
import '../../Common/decoration.dart';

// ─────────────────────────────────────────────────────────────────────
// Packing form page
// ─────────────────────────────────────────────────────────────────────

class PackingFormPage extends StatefulWidget {
  final PackingDoc? initialDoc;
  const PackingFormPage({super.key, this.initialDoc});

  @override
  State<PackingFormPage> createState() => _PackingFormPageState();
}

class _PackingFormPageState extends State<PackingFormPage> {
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
  bool _customerExpanded = true;
  bool _notesExpanded = true;
  bool _shippingExpanded = true;
  bool _itemsExpanded = true;

  // Document fields
  DateTime _docDate = DateTime.now();
  SalesListItem? _selectedSO;
  SalesDoc? _salesDoc;
  bool _isLoadingSO = false;

  // Notes fields
  final _descriptionCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final _shippingRefNoCtrl = TextEditingController();
  ShippingMethod? _selectedShippingMethod;
  List<ShippingMethod> _shippingMethods = [];

  // Line items (populated from SO)
  final List<_PackingLine> _lines = [];

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
    _shippingRefNoCtrl.dispose();
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
    if (widget.initialDoc == null) await _checkAndRestoreDraft();
    if (mounted) setState(() => _loading = false);
  }

  // ── Draft ─────────────────────────────────────────────────────────────

  Future<void> _saveDraft() async {
    final draft = {
      'docDate': _docDate.toIso8601String(),
      'description': _descriptionCtrl.text,
      'remark': _remarkCtrl.text,
      'shippingRefNo': _shippingRefNoCtrl.text,
      'shippingMethod': _selectedShippingMethod == null
          ? null
          : {
              'shippingMethodID': _selectedShippingMethod!.shippingMethodID,
              'description': _selectedShippingMethod!.description,
              'isDisabled': _selectedShippingMethod!.isDisabled,
            },
      'so': _selectedSO == null
          ? null
          : {
              'docID': _selectedSO!.docID,
              'docNo': _selectedSO!.docNo,
              'docDate': _selectedSO!.docDate,
              'customerID': _selectedSO!.customerID,
              'customerCode': _selectedSO!.customerCode,
              'customerName': _selectedSO!.customerName,
            },
      'lines': _lines
          .map((l) => {
                'soDetailID': l.soDetailID,
                'stockID': l.stockID,
                'stockCode': l.stockCode,
                'description': l.description,
                'uom': l.uom,
                'orderedQty': l.orderedQty,
                'packQty': l.packQtyCtrl.text,
              })
          .toList(),
    };
    await SessionManager.savePackingDraft(jsonEncode(draft));
  }

  void _restoreDraftFields(Map<String, dynamic> j) {
    _docDate = DateTime.tryParse(j['docDate'] as String? ?? '') ?? DateTime.now();
    _descriptionCtrl.text = j['description'] as String? ?? '';
    _remarkCtrl.text = j['remark'] as String? ?? '';
    _shippingRefNoCtrl.text = j['shippingRefNo'] as String? ?? '';
    final sm = j['shippingMethod'] as Map<String, dynamic>?;
    if (sm != null) _selectedShippingMethod = ShippingMethod.fromJson(sm);
  }

  Future<void> _checkAndRestoreDraft() async {
    final raw = await SessionManager.getPackingDraft();
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      _restoreDraftFields(j);
      final soMap = j['so'] as Map<String, dynamic>?;
      final linesJson = j['lines'] as List<dynamic>? ?? [];
      if (soMap != null) {
        final docID = soMap['docID'] as int? ?? 0;
        // Build a minimal SalesListItem so the SO card renders
        _selectedSO = SalesListItem(
          docID: docID,
          docNo: soMap['docNo'] as String? ?? '',
          docDate: soMap['docDate'] as String? ?? '',
          customerID: soMap['customerID'] as int? ?? 0,
          customerCode: soMap['customerCode'] as String? ?? '',
          customerName: soMap['customerName'] as String? ?? '',
          subtotal: 0,
          taxAmt: 0,
          finalTotal: 0,
          paymentTotal: 0,
          outstanding: 0,
          isVoid: false,
        );
        setState(() => _isLoadingSO = true);
        // Re-fetch SO so _salesDoc is populated (needed for save payload)
        try {
          final result = await BaseClient.post(
            ApiEndpoints.getSales,
            body: {
              'apiKey': _apiKey,
              'companyGUID': _companyGUID,
              'userID': _userID,
              'userSessionID': _userSessionID,
              'docID': docID,
            },
          );
          final doc = SalesDoc.fromJson(result as Map<String, dynamic>);
          if (!mounted) return;
          // Build lines from live SO data, apply saved pack qtys
          final Map<int, String> savedQtys = {
            for (final lj in linesJson)
              (lj as Map<String, dynamic>)['soDetailID'] as int? ?? 0:
                  (lj)['packQty'] as String? ?? '0',
          };
          final newLines = doc.salesDetails.map((d) {
            final line = _PackingLine()
              ..soDetailID = d.dtlID
              ..stockID = d.stockID
              ..stockCode = d.stockCode
              ..description = d.description
              ..uom = d.uom
              ..orderedQty = d.qty;
            line.packQtyCtrl.text = savedQtys[d.dtlID] ?? '0';
            return line;
          }).toList();
          setState(() {
            _salesDoc = doc;
            _lines.addAll(newLines);
            _isLoadingSO = false;
          });
        } catch (_) {
          if (mounted) setState(() => _isLoadingSO = false);
        }
      } else {
        setState(() {});
      }
    } catch (_) {
      await SessionManager.clearPackingDraft();
    }
  }

  Future<void> _loadShippingMethods() async {
    if (_shippingMethods.isNotEmpty) return;
    try {
      final result = await BaseClient.post(
        ApiEndpoints.getShippingMethodList,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
        },
      );
      if (mounted) {
        setState(() {
          _shippingMethods = (result as List<dynamic>)
              .map((e) => ShippingMethod.fromJson(e as Map<String, dynamic>))
              .where((s) => !s.isDisabled)
              .toList();
        });
      }
    } catch (_) {}
  }

  bool get _hasChanges =>
      _selectedSO != null ||
      _descriptionCtrl.text.isNotEmpty ||
      _remarkCtrl.text.isNotEmpty ||
      _shippingRefNoCtrl.text.isNotEmpty ||
      _selectedShippingMethod != null;

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

  // ── SO picker & detail fetch ──────────────────────────────────────────

  Future<void> _pickSO() async {
    final so = await Navigator.push<SalesListItem>(
      context,
      MaterialPageRoute(
        builder: (_) => _SOPickerPage(
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (so == null || !mounted) return;
    setState(() {
      _selectedSO = so;
      _salesDoc = null;
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      _isLoadingSO = true;
    });
    await _fetchSODetails(so.docID);
  }

  Future<void> _fetchSODetails(int docID) async {
    try {
      final result = await BaseClient.post(
        ApiEndpoints.getSales,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'docID': docID,
        },
      );
      final doc = SalesDoc.fromJson(result as Map<String, dynamic>);
      if (!mounted) return;
      final newLines = doc.salesDetails.map((d) {
        return _PackingLine()
          ..soDetailID = d.dtlID
          ..stockID = d.stockID
          ..stockCode = d.stockCode
          ..description = d.description
          ..uom = d.uom
          ..orderedQty = d.qty;
      }).toList();
      setState(() {
        _salesDoc = doc;
        _lines.addAll(newLines);
        _isLoadingSO = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSO = false);
        _showError('Failed to load sales order: $e');
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

  Future<void> _pickShippingMethod() async {
    await _loadShippingMethods();
    if (_shippingMethods.isEmpty || !mounted) return;
    final picked = await showModalBottomSheet<ShippingMethod>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text('Shipping Method',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: _shippingMethods.length,
                itemBuilder: (_, i) {
                  final s = _shippingMethods[i];
                  final selected =
                      _selectedShippingMethod?.shippingMethodID ==
                          s.shippingMethodID;
                  return ListTile(
                    title: Text(s.description),
                    trailing: selected
                        ? const Icon(Icons.check, color: Color(0xFF153D81))
                        : null,
                    onTap: () => Navigator.pop(ctx, s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _selectedShippingMethod = picked);
  }

  // ── Barcode scan ──────────────────────────────────────────────────────

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
        final idx = _lines.indexWhere((l) => l.stockID == found!.stockID);
        if (idx >= 0) {
          final line = _lines[idx];
          final next = (line.packQty + 1).clamp(0.0, line.orderedQty);
          setState(() => line.packQtyCtrl.text = _qtyFmt.format(next));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Scanned: ${found.stockCode}  ${_qtyFmt.format(next)} / ${_qtyFmt.format(line.orderedQty)} ${line.uom}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ));
        } else if (mounted) {
          _showError('${found.stockCode} is not in this sales order');
        }
      } else if (mounted) {
        _showError('No item found for "$barcode"');
      }
    } catch (_) {
      if (mounted) _showError('No item found for "$barcode"');
    } finally {
      if (mounted) setState(() => _scanSearching = false);
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_selectedSO == null || _salesDoc == null) {
      _showError('Please select a sales order.');
      return;
    }
    final packedLines = _lines.where((l) => l.packQty > 0).toList();
    if (packedLines.isEmpty) {
      _showError('Please set pack quantity for at least one item.');
      return;
    }
    setState(() => _saving = true);
    try {
      final doc = _salesDoc!;
      final details = packedLines
          .map((l) => {
                'dtlID': 0,
                'docID': 0,
                'pickingItemID': l.soDetailID,
                'stockID': l.stockID,
                'stockBatchID': 0,
                'batchNo': '',
                'stockCode': l.stockCode,
                'description': l.description,
                'uom': l.uom,
                'qty': l.packQty,
              })
          .toList();

      await BaseClient.post(
        ApiEndpoints.createPacking,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'packingForm': {
            'docID': 0,
            'docNo': '',
            'docDate': _docDate.toIso8601String(),
            'customerID': doc.customerID,
            'customerCode': doc.customerCode,
            'customerName': doc.customerName,
            'address1': doc.address1 ?? '',
            'address2': doc.address2 ?? '',
            'address3': doc.address3 ?? '',
            'address4': doc.address4 ?? '',
            'deliverAddr1': doc.deliverAddr1 ?? '',
            'deliverAddr2': doc.deliverAddr2 ?? '',
            'deliverAddr3': doc.deliverAddr3 ?? '',
            'deliverAddr4': doc.deliverAddr4 ?? '',
            'phone': doc.phone ?? '',
            'fax': doc.fax ?? '',
            'email': doc.email ?? '',
            'attention': doc.attention ?? '',
            'description': _descriptionCtrl.text.trim(),
            'remark': _remarkCtrl.text.trim(),
            'isVoid': false,
            'lastModifiedUserID': _userID,
            'lastModifiedDateTime': DateTime.now().toIso8601String(),
            'createdUserID': _userID,
            'createdDateTime': DateTime.now().toIso8601String(),
            'shippingRefNo': _shippingRefNoCtrl.text.trim(),
            'shippingMethodID':
                _selectedShippingMethod?.shippingMethodID ?? 0,
            'shippingMethodDescription':
                _selectedShippingMethod?.description ?? '',
            'salesDocID': doc.docID,
            'salesDocNo': doc.docNo,
            'pickingDocID': 0,
            'pickingDocNo': '',
            'packingDetails': details,
          },
        },
      );
      await SessionManager.clearPackingDraft();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      _showError(
          e is BadRequestException ? e.message : 'Failed to save: $e');
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

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final packedCount = _lines.where((l) => l.isFullyPacked).length;
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
            onDoubleTap: () => _formScrollCtrl.animateTo(0,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic),
            child: const Text('New Packing',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          centerTitle: true,
          actions: [
            if (_scanSearching)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: DotsLoading(dotSize: 6))
            else
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_outlined),
                tooltip: 'Scan Item',
                onPressed: _selectedSO == null
                    ? null
                    : () => setState(() => _scanning = true),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: DotsLoading())
            : Stack(children: [
                Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _formScrollCtrl,
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 16),
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

                            // ── Customer (after SO selected) ──────────
                            if (_selectedSO != null) ...[
                              FormSectionHeader(
                                icon: Icons.person_outline,
                                title: 'Customer',
                                expanded: _customerExpanded,
                                onToggle: () => setState(() =>
                                    _customerExpanded =
                                        !_customerExpanded),
                              ),
                              AnimatedSize(
                                duration:
                                    const Duration(milliseconds: 220),
                                curve: Curves.easeInOut,
                                child: _customerExpanded
                                    ? _buildCustomerSection()
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

                            // ── Shipping ───────────────────────────────
                            FormSectionHeader(
                              icon: Icons.local_shipping_outlined,
                              title: 'Shipping',
                              expanded: _shippingExpanded,
                              onToggle: () => setState(
                                  () => _shippingExpanded = !_shippingExpanded),
                            ),
                            AnimatedSize(
                              duration:
                                  const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              child: _shippingExpanded
                                  ? _buildShippingSection()
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
                                  : '$packedCount/${_lines.length}',
                            ),
                            AnimatedSize(
                              duration:
                                  const Duration(milliseconds: 220),
                              curve: Curves.easeInOut,
                              child: _itemsExpanded
                                  ? _buildItemsSection()
                                  : const SizedBox.shrink(),
                            ),

                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ),

                    // ── Packing progress bar ─────────────────────────
                    if (_lines.isNotEmpty) _buildPackingBar(packedCount),

                    // ── Save button ──────────────────────────────────
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const DotsLoading()
                              : const Text('Save Packing',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── Scanner overlay ──────────────────────────────────
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
              ]),
      ),
    );
  }

  // ── Section builders ──────────────────────────────────────────────────

  Widget _buildDocSection() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date
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
                    style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Sales Order picker
        FieldLabel(label: 'Sales Order *'),
        InkWell(
          onTap: _isLoadingSO ? null : _pickSO,
          borderRadius: BorderRadius.circular(12),
          child: FieldBox(
            child: _isLoadingSO
                ? const SizedBox(
                    height: 20,
                    child: Center(child: DotsLoading()))
                : Row(
                    children: [
                      const Icon(Icons.receipt_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _selectedSO == null
                            ? Text(
                                'Select sales order',
                                style: TextStyle(
                                    fontSize: 14,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.4)),
                              )
                            : Text(
                                    _selectedSO!.docNo,
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: cs.primary),
                                  ),
                      ),
                      if (_selectedSO != null)
                        GestureDetector(
                          onTap: () => setState(() {
                            _selectedSO = null;
                            _salesDoc = null;
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

  Widget _buildCustomerSection() {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final muted = cs.onSurface.withValues(alpha: 0.5);
    final doc = _salesDoc;

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
                Row(
                  children: [
                    Text(doc.customerCode,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: primary)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(doc.customerName,
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
                if (_hasAddr([
                      doc.deliverAddr1,
                      doc.deliverAddr2,
                      doc.deliverAddr3,
                      doc.deliverAddr4
                    ]) &&
                    _joinAddr([
                          doc.deliverAddr1,
                          doc.deliverAddr2,
                          doc.deliverAddr3,
                          doc.deliverAddr4
                        ]) !=
                        _joinAddr([
                          doc.address1,
                          doc.address2,
                          doc.address3,
                          doc.address4
                        ])) ...[
                  const SizedBox(height: 6),
                  _infoRow(
                      Icons.airport_shuttle_outlined,
                      _joinAddr([
                        doc.deliverAddr1,
                        doc.deliverAddr2,
                        doc.deliverAddr3,
                        doc.deliverAddr4
                      ]),
                      muted),
                ],
                if (doc.phone?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  _infoRow(Icons.phone_outlined, doc.phone!, muted),
                ],
                if (doc.email?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  _infoRow(Icons.email_outlined, doc.email!, muted),
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

  Widget _buildShippingSection() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label: 'Shipping Method'),
        InkWell(
          onTap: _pickShippingMethod,
          borderRadius: BorderRadius.circular(12),
          child: FieldBox(
            child: Row(
              children: [
                const Icon(Icons.airport_shuttle_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: _selectedShippingMethod == null
                      ? Text('Select shipping method',
                          style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface.withValues(alpha: 0.4)))
                      : Text(
                          _selectedShippingMethod!.description,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                ),
                if (_selectedShippingMethod != null)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _selectedShippingMethod = null),
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
        const SizedBox(height: 12),
        FieldLabel(label: 'Shipping Reference No'),
        TextFormField(
          controller: _shippingRefNoCtrl,
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

    if (_selectedSO == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 40, color: cs.onSurface.withValues(alpha: 0.25)),
              const SizedBox(height: 10),
              Text('Select a sales order to load items',
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.4))),
            ],
          ),
        ),
      );
    }

    if (_isLoadingSO) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: DotsLoading()),
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
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scan hint banner
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.qr_code_scanner_outlined,
                  size: 16, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scan each item barcode to record pack qty, or swipe a card left to edit manually.',
                  style: TextStyle(
                      fontSize: 12, color: cs.primary, height: 1.3),
                ),
              ),
            ],
          ),
        ),

        SlidableAutoCloseBehavior(
          child: Column(
            children: _lines.asMap().entries.map((e) {
              return _LineItemCard(
                key: ValueKey(e.key),
                index: e.key,
                item: e.value,
                qtyFmt: _qtyFmt,
                showImage: _showImage,
                onChanged: () => setState(() {}),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPackingBar(int packedCount) {
    final cs = Theme.of(context).colorScheme;
    final total = _lines.length;
    final isComplete = packedCount == total && total > 0;
    final progress = total > 0 ? packedCount / total : 0.0;
    final color =
        isComplete ? Colors.green : const Color(0xFFFF9700);

    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isComplete
                    ? Icons.check_circle_outline
                    : Icons.inventory_2_outlined,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Text(
                isComplete
                    ? 'All items fully packed'
                    : '$packedCount of $total items fully packed',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: cs.outline.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Packing line model
// ─────────────────────────────────────────────────────────────────────

class _PackingLine {
  int soDetailID = 0;
  int stockID = 0;
  String stockCode = '';
  String description = '';
  String uom = '';
  double orderedQty = 0;
  String? itemImage;
  final packQtyCtrl = TextEditingController(text: '0');

  double get packQty =>
      double.tryParse(packQtyCtrl.text.replaceAll(',', '')) ?? 0;

  bool get isFullyPacked => orderedQty > 0 && packQty >= orderedQty;

  void dispose() => packQtyCtrl.dispose();
}

// ─────────────────────────────────────────────────────────────────────
// Line item card
// ─────────────────────────────────────────────────────────────────────

class _LineItemCard extends StatefulWidget {
  final int index;
  final _PackingLine item;
  final NumberFormat qtyFmt;
  final bool showImage;
  final VoidCallback onChanged;

  const _LineItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.qtyFmt,
    required this.showImage,
    required this.onChanged,
  });

  @override
  State<_LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends State<_LineItemCard> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});
    };
    widget.item.packQtyCtrl.addListener(_listener);
  }

  @override
  void dispose() {
    widget.item.packQtyCtrl.removeListener(_listener);
    super.dispose();
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PackQtyEditSheet(
        item: widget.item,
        qtyFmt: widget.qtyFmt,
        onChanged: () {
          widget.onChanged();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _badge(Color primary) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            shape: BoxShape.circle),
        child: Center(
          child: Text('${widget.index + 1}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primary)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final item = widget.item;
    final packQty = item.packQty;
    final isFullyPacked = item.isFullyPacked;
    final isPartial = packQty > 0 && !isFullyPacked;

    final borderColor = isFullyPacked
        ? Colors.green.withValues(alpha: 0.45)
        : isPartial
            ? const Color(0xFFFF9700).withValues(alpha: 0.45)
            : cs.outline.withValues(alpha: 0.18);

    final qtyColor = isFullyPacked
        ? Colors.green
        : isPartial
            ? const Color(0xFFFF9700)
            : cs.onSurface.withValues(alpha: 0.45);

    // Leading: image or index badge
    Widget leading;
    if (widget.showImage &&
        item.itemImage != null &&
        item.itemImage!.isNotEmpty) {
      try {
        final raw = item.itemImage!.contains(',')
            ? item.itemImage!.split(',').last
            : item.itemImage!;
        leading = ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            base64Decode(raw),
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _badge(cs.primary),
          ),
        );
      } catch (_) {
        leading = _badge(cs.primary);
      }
    } else {
      leading = _badge(cs.primary);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Slidable(
          key: widget.key,
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.28,
            children: [
              CustomSlidableAction(
                onPressed: (_) => _openEditSheet(),
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
            ],
          ),
          child: GestureDetector(
            onTap: _openEditSheet,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: isFullyPacked
                    ? Colors.green.withValues(alpha: 0.04)
                    : (Theme.of(context).cardTheme.color ??
                            cs.surface)
                        .withValues(alpha: 0.5),
                border: Border.all(color: borderColor),
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
                        // Row 1: stock code | fully-packed checkmark
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.stockCode,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: cs.primary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isFullyPacked)
                              const Icon(Icons.check_circle_rounded,
                                  size: 16, color: Colors.green),
                          ],
                        ),
                        // Row 2: description
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface
                                  .withValues(alpha: 0.65)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Row 3: UOM | pack qty / ordered qty
                        Row(
                          children: [
                            Text(item.uom,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.5))),
                            const Spacer(),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: widget.qtyFmt
                                        .format(packQty),
                                    style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: qtyColor),
                                  ),
                                  TextSpan(
                                    text:
                                        ' / ${widget.qtyFmt.format(item.orderedQty)}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.4)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Row 4: mini progress bar
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: item.orderedQty > 0
                                ? (packQty / item.orderedQty)
                                    .clamp(0.0, 1.0)
                                : 0,
                            backgroundColor:
                                cs.outline.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isFullyPacked
                                  ? Colors.green
                                  : const Color(0xFFFF9700),
                            ),
                            minHeight: 3,
                          ),
                        ),
                      ],
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
}

// ─────────────────────────────────────────────────────────────────────
// Pack qty edit sheet
// ─────────────────────────────────────────────────────────────────────

class _PackQtyEditSheet extends StatefulWidget {
  final _PackingLine item;
  final NumberFormat qtyFmt;
  final VoidCallback onChanged;

  const _PackQtyEditSheet({
    required this.item,
    required this.qtyFmt,
    required this.onChanged,
  });

  @override
  State<_PackQtyEditSheet> createState() => _PackQtyEditSheetState();
}

class _PackQtyEditSheetState extends State<_PackQtyEditSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.item.packQtyCtrl.text);
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _qty =>
      double.tryParse(_ctrl.text.replaceAll(',', '')) ?? 0;

  void _step(double delta) {
    final next = (_qty + delta).clamp(0.0, widget.item.orderedQty);
    _ctrl.text = widget.qtyFmt.format(next);
  }

  void _clamp() {
    final v = _qty.clamp(0.0, widget.item.orderedQty);
    _ctrl.text = widget.qtyFmt.format(v);
  }

  void _setFull() =>
      _ctrl.text = widget.qtyFmt.format(widget.item.orderedQty);

  void _apply() {
    _clamp();
    widget.item.packQtyCtrl.text = _ctrl.text;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final item = widget.item;
    final isFullyPacked = _qty >= item.orderedQty && item.orderedQty > 0;
    final progress = item.orderedQty > 0
        ? (_qty / item.orderedQty).clamp(0.0, 1.0)
        : 0.0;
    final color =
        isFullyPacked ? Colors.green : const Color(0xFFFF9700);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Item header
            Text(item.stockCode,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: primary)),
            Text(item.description,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Ordered Qty',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5))),
                const Spacer(),
                Text(
                  'x${widget.qtyFmt.format(item.orderedQty)} ${item.uom}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Pack qty label + Set Full shortcut
            Row(
              children: [
                Text('Pack Qty',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.5))),
                const Spacer(),
                TextButton.icon(
                  onPressed: _setFull,
                  icon: const Icon(Icons.done_all_rounded, size: 14),
                  label: const Text('Set Full',
                      style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),

            // Qty stepper row
            Row(
              children: [
                stepBtn(context, Icons.remove_rounded, () => _step(-1)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d*')), // ignore: deprecated_member_use
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700),
                    decoration: sheetInputDeco(context),
                    onEditingComplete: _clamp,
                    onTapOutside: (_) => _clamp(),
                  ),
                ),
                const SizedBox(width: 10),
                stepBtn(context, Icons.add_rounded, () => _step(1)),
              ],
            ),
            const SizedBox(height: 10),

            // Live progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: cs.outline.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 30),

            // Apply button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _apply,
                child: const Text('Apply',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sales Order picker page
// ─────────────────────────────────────────────────────────────────────

class _SOPickerPage extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  const _SOPickerPage({
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
  });

  @override
  State<_SOPickerPage> createState() => _SOPickerPageState();
}

class _SOPickerPageState extends State<_SOPickerPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<SalesListItem> _items = [];
  bool _loading = true;
  String? _error;

  int _currentPage = 0;
  int _totalPages = 1;
  int _totalCount = 0;
  int _itemsPerPage = 20;

  String _sortBy = 'DocDate';
  bool _sortAsc = false;

  final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _loadPageSize();
    _fetch(page: 0);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPageSize() async {
    _itemsPerPage = await SessionManager.getItemsPerPage();
  }

  Future<void> _fetch({required int page}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getSalesListAvailableForPacking,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'pageIndex': page,
          'pageSize': _itemsPerPage,
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
        pageSize = _itemsPerPage;
      } else if (response is Map<String, dynamic>) {
        raw = (response['data'] as List<dynamic>?) ?? [];
        final pg = response['pagination'] as Map<String, dynamic>?;
        totalRecord = (pg?['totalRecord'] as int?) ?? raw.length;
        pageSize = (pg?['pageSize'] as int?) ?? _itemsPerPage;
      } else {
        raw = [];
        totalRecord = 0;
        pageSize = _itemsPerPage;
      }

      if (mounted) {
        setState(() {
          _items = raw
              .map((e) =>
                  SalesListItem.fromJson(e as Map<String, dynamic>))
              .toList();
          _currentPage = page;
          _totalCount = totalRecord;
          _totalPages =
              pageSize > 0 ? (totalRecord / pageSize).ceil() : 1;
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
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

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
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20)),
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color:
                            cs.onSurface.withValues(alpha: 0.2),
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
                          borderRadius:
                              BorderRadius.circular(10)),
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'DocDate',
                          child: Text('Doc Date')),
                      DropdownMenuItem(
                          value: 'DocNo',
                          child: Text('Doc No')),
                      DropdownMenuItem(
                          value: 'CustomerName',
                          child: Text('Customer Name')),
                    ],
                    onChanged: (v) => setSheet(
                        () => tempSort = v ?? tempSort),
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
                          onTap: () =>
                              setSheet(() => tempAsc = true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DirectionChip(
                          label: 'Descending',
                          icon: Icons.arrow_downward_rounded,
                          selected: !tempAsc,
                          onTap: () =>
                              setSheet(() => tempAsc = false),
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
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Sales Order',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            onPressed: _openSortSheet,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by doc no, customer…',
                hintStyle: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _fetch(page: 0);
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 12),
              ),
              onChanged: (value) {
                final query = value;
                Future.delayed(
                  const Duration(milliseconds: 600),
                  () {
                    if (mounted && _searchCtrl.text == query) {
                      _fetch(page: 0);
                    }
                  },
                );
              },
              onSubmitted: (_) => _fetch(page: 0),
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
                      Icon(Icons.error_outline,
                          size: 40, color: cs.error),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(color: cs.error),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: () => _fetch(page: 0),
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        'No sales orders available for packing',
                        style: TextStyle(
                            color: cs.onSurface
                                .withValues(alpha: 0.4)),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(
                                16, 8, 16, 8),
                            itemCount: _items.length + 1,
                            itemBuilder: (_, i) {
                              if (i == _items.length) {
                                final start =
                                    _currentPage * _itemsPerPage + 1;
                                final end =
                                    ((_currentPage + 1) * _itemsPerPage)
                                        .clamp(0, _totalCount);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  child: Text(
                                    'Showing $start–$end of $_totalCount records',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.5)),
                                  ),
                                );
                              }
                              final so = _items[i];
                              return Card(
                                margin:
                                    const EdgeInsets.only(bottom: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  onTap: () =>
                                      Navigator.pop(context, so),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(so.docNo,
                                                style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    color: primary)),
                                            const Spacer(),
                                            Text(
                                              _dateFmt.format(
                                                  DateTime.tryParse(
                                                          so.docDate) ??
                                                      DateTime.now()),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: cs.onSurface
                                                      .withValues(
                                                          alpha: 0.5)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(so.customerName,
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w600)),
                                        if (so.customerCode.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(so.customerCode,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: cs.onSurface
                                                      .withValues(
                                                          alpha: 0.5))),
                                        ],
                                      ],
                                    ),
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
