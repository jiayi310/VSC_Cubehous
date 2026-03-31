import 'dart:convert';

import 'package:cubehous/api/api_endpoints.dart';
import 'package:cubehous/api/base_client.dart';
import 'package:cubehous/common/dots_loading.dart';
import 'package:cubehous/common/my_color.dart';
import 'package:cubehous/common/session_manager.dart';
import 'package:cubehous/common/stock_common.dart';
import 'package:cubehous/models/customer.dart';
import 'package:cubehous/models/inbound.dart';
import 'package:cubehous/models/location.dart';
import 'package:cubehous/models/stock.dart';
import 'package:cubehous/models/stock_detail.dart';
import 'package:cubehous/models/tax_type.dart';
import 'package:cubehous/view/Common/decoration.dart';
import 'package:cubehous/view/Common/Stock/item_picker_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

class InboundFormPage extends StatefulWidget {
  final InboundDoc? initialDoc;
  const InboundFormPage({super.key, this.initialDoc});

  @override
  State<InboundFormPage> createState() => _InboundFormPageState();
}

class _InboundFormPageState extends State<InboundFormPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  bool get _isEditMode => widget.initialDoc != null;
  int _editDocID = 0;
  String _editDocNo = '';

  // ── Section expand state ────────────────────────────────────────────
  final _formScrollCtrl = ScrollController();
  bool _docExpanded = true;
  bool _notesExpanded = true;
  bool _itemsExpanded = true;
  bool _loadingDropdowns = true;
  bool _scanning = false;
  bool _scanSearching = false;
  bool _showImage = true;
  bool _isEnableTax = false;
  int _defaultLocationID = 0;
  List<Location> _locations = [];
  List<TaxType> _taxTypes = [];
  Customer? _selectedCustomer;
  int get _priceCategory => _selectedCustomer?.priceCategory ?? 1;

  // ── Document fields ─────────────────────────────────────────────────
  String? _docType;        // 'GRN' | 'PUT'
  DateTime _docDate = DateTime.now();

  // ── Notes fields ────────────────────────────────────────────────────
  final _descCtrl    = TextEditingController();
  final _remarkCtrl  = TextEditingController();

  // ── Items ────────────────────────────────────────────────────────────
  final List<_LineItem> _lines = [];

  final _amtFmt = NumberFormat('#,##0.00');

  static const _docTypeOptions = [
    (code: 'PUT', label: 'Put Away'),
  ];

   @override
  void initState() {
    super.initState();
    _init();
  }

   @override
  void dispose() {
    _formScrollCtrl.dispose();
    _descCtrl.dispose();
    _remarkCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    final results = await Future.wait([
      SessionManager.getImageMode(),
      SessionManager.getIsEnableTax(),
      SessionManager.getDefaultLocationID(),
    ]);
    if (mounted) {
      setState(() {
        _showImage = (results[0] as String) == 'show';
        _isEnableTax = results[1] as bool;
        _defaultLocationID = results[2] as int;
      });
    }
    await _loadDropdowns();
  }

    Future<void> _loadDropdowns() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    try {
      final body = {
        'apiKey': _apiKey,
        'companyGUID': _companyGUID,
        'userID': _userID,
        'userSessionID': _userSessionID,
      };
      final results = await Future.wait([
        BaseClient.post(ApiEndpoints.getTaxList, body: body),
        BaseClient.post(ApiEndpoints.getLocationList, body: body),
      ]);
      setState(() {
         _taxTypes = (results[0] as List<dynamic>)
            .map((e) => TaxType.fromJson(e as Map<String, dynamic>))
            .where((t) => !t.isDisabled)
            .toList();
        _locations = (results[1] as List<dynamic>)
            .map((e) => Location.fromJson(e as Map<String, dynamic>))
            .where((l) => l.isActive)
            .toList();
        _loadingDropdowns = false;
      });
    } catch (_) {
      setState(() => _loadingDropdowns = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  InputDecoration _inputDeco(String hint) => formInputDeco(
        context,
        hint: hint,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );


  // ── DocType picker sheet ─────────────────────────────────────────────

  void _pickDocType() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: cs.outline.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Select Document Type',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface)),
              ),
              const SizedBox(height: 8),
              for (final opt in _docTypeOptions) ...[
                ListTile(
                  title: Text(opt.label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(opt.code,
                      style: TextStyle(
                          fontSize: 12, color: cs.primary)),
                  trailing: _docType == opt.code
                      ? Icon(Icons.check_circle_rounded,
                          color: cs.primary)
                      : Icon(Icons.radio_button_unchecked,
                          color: cs.outline.withValues(alpha: 0.5)),
                  onTap: () {
                    setState(() => _docType = opt.code);
                    Navigator.pop(ctx);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ── Date picker ──────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _docDate = picked);
  }

  Future<void> _pickItem(int index) async {
    final picked = await Navigator.push<Stock>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemPickerPage(
          module: "INBOUND",
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (picked != null && mounted) {
      final price =
          await StockCommon.fetchUOMPrice(picked.stockID, picked.baseUOM, _priceCategory) ??
          picked.baseUOMPrice1;
      if (!mounted) return;
      setState(() {
        final l = _lines[index];
        l.stockID = picked.stockID;
        l.stockCode = picked.stockCode;
        l.uom = picked.baseUOM;
        l.itemImage = picked.image;
        l.descriptionCtrl.text = picked.description;
        l.unitPriceCtrl.text = price.toString();
        if (picked.taxTypeID != 0) {
          l.selectedTaxType = _taxTypes
              .where((t) => t.taxTypeID == picked.taxTypeID)
              .firstOrNull;
        }
      });
    }
  }

  Future<void> _addLine() async {
    final picked = await Navigator.push<Stock>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemPickerPage(
          module: "INBOUND",
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (picked != null && mounted) {
      final price =
          await StockCommon.fetchUOMPrice(picked.stockID, picked.baseUOM, _priceCategory) ??
          picked.baseUOMPrice1;
      if (!mounted) return;
      final line = _LineItem();
      line.stockID = picked.stockID;
      line.stockCode = picked.stockCode;
      line.uom = picked.baseUOM;
      line.itemImage = picked.image;
      line.descriptionCtrl.text = picked.description;
      line.unitPriceCtrl.text = price.toString();
      if (picked.taxTypeID != 0) {
        line.selectedTaxType =
            _taxTypes.where((t) => t.taxTypeID == picked.taxTypeID).firstOrNull;
      }
      setState(() => _lines.add(line));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_formScrollCtrl.hasClients) {
          _formScrollCtrl.animateTo(
            _formScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      });
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

  // ── Save ─────────────────────────────────────────────────────────────

  void _save() {
    if (_docType == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Please select a document type'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    // TODO: API call
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  Future<void> _onFormBarcodeDetected(String barcode) async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
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
        final price =
            await StockCommon.fetchUOMPrice(found.stockID, found.baseUOM, _priceCategory) ??
            found.baseUOMPrice1;
        if (!mounted) return;
        setState(() {
          // Fill the first empty line, or add a new one
          final emptyIndex = _lines.indexWhere((l) => l.stockID == 0);
          final _LineItem line;
          if (emptyIndex >= 0) {
            line = _lines[emptyIndex];
          } else {
            line = _LineItem();
            _lines.add(line);
          }
          line.stockID = found!.stockID;
          line.stockCode = found.stockCode;
          line.uom = found.baseUOM;
          line.itemImage = found.image;
          line.descriptionCtrl.text = found.description;
          line.unitPriceCtrl.text = price.toString();
          if (found.taxTypeID != 0) {
            line.selectedTaxType =
                _taxTypes.where((t) => t.taxTypeID == found!.taxTypeID).firstOrNull;
          }
        });
      } else if (mounted) {
        _showError('No item found for "$barcode"');
      }
    } catch (_) {
      if (mounted) _showError('No item found for "$barcode"');
    } finally {
      if (mounted) setState(() => _scanSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Discard changes?'),
            content: const Text('Changes you made will not be saved.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Discard',
                      style: TextStyle(color: Colors.red))),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
        title: GestureDetector(
          onDoubleTap: () => _formScrollCtrl.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ),
          child: Text(_isEditMode ? 'Edit Inbound' : 'New Inbound',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        centerTitle: true,
        actions: [
          if (_scanSearching)
            const Padding(padding: EdgeInsets.all(16), child: DotsLoading(dotSize: 6))
          else
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_outlined),
              tooltip: 'Scan Barcode',
              onPressed: () => setState(() => _scanning = true),
            ),
        ],
      ),
        body: _loadingDropdowns
          ? const Center(child: DotsLoading())
          : Stack(children: [
            Column(
              children: [
              Expanded(
                child: SingleChildScrollView(
                controller: _formScrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Document section ──────────────────────────────
                    FormSectionHeader(
                      icon: Icons.description_outlined,
                      title: 'Document',
                      expanded: _docExpanded,
                      onToggle: () =>
                          setState(() => _docExpanded = !_docExpanded),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _docExpanded
                          ? Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Doc Type
                                  _FieldLabel('Doc Type *'),
                                  const SizedBox(height: 6),
                                  _FieldBox(
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest
                                          .withValues(alpha: 0.45),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 14),
                                    child: GestureDetector(
                                      onTap: _pickDocType,
                                      child: Container(
                                        color: Colors.transparent,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _docType != null
                                                    ? '${_docType!}  —  ${_docTypeOptions.firstWhere((o) => o.code == _docType!).label}'
                                                    : 'Select document type',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: _docType != null
                                                      ? cs.onSurface
                                                      : cs.onSurface.withValues(alpha: 0.35),
                                                ),
                                              ),
                                            ),
                                            Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                                size: 20,
                                                color: cs.onSurface
                                                    .withValues(alpha: 0.45)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // Doc Date
                                  _FieldLabel('Date'),
                                  const SizedBox(height: 6),
                                  _FieldBox(
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest
                                          .withValues(alpha: 0.45),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 14),
                                    child: GestureDetector(
                                      onTap: _pickDate,
                                      child: Container(
                                        color: Colors.transparent,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                DateFormat('dd MMM yyyy').format(_docDate),
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                            Icon(Icons.calendar_today_outlined,
                                                size: 16,
                                                color: cs.onSurface.withValues(alpha: 0.45)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),

                    // ── Notes section ─────────────────────────────────
                    FormSectionHeader(
                      icon: Icons.notes_outlined,
                      title: 'Notes',
                      expanded: _notesExpanded,
                      onToggle: () =>
                          setState(() => _notesExpanded = !_notesExpanded),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _notesExpanded
                          ? Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  _FieldLabel('Description'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _descCtrl,
                                    decoration: _inputDeco(
                                        'Enter description...'),
                                    maxLines: 2,
                                    textInputAction:
                                        TextInputAction.next,
                                  ),
                                  const SizedBox(height: 14),
                                  _FieldLabel('Remarks'),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: _remarkCtrl,
                                    decoration:
                                        _inputDeco('Enter remarks...'),
                                    maxLines: 2,
                                    textInputAction: TextInputAction.done,
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),

                    // ── Items section ─────────────────────────────────
                    FormSectionHeader(
                      icon: Icons.inventory_2_outlined,
                      title: 'Items',
                      badge: _lines.isNotEmpty ? '${_lines.length}' : null,
                      expanded: _itemsExpanded,
                      onToggle: () =>
                          setState(() => _itemsExpanded = !_itemsExpanded),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _itemsExpanded
                          ? Column(
                                children: [
                                  ...List.generate(
                                        _lines.length,
                                        (i) => _LineItemCard(
                                              index: i,
                                              item: _lines[i],
                                              taxTypes: _taxTypes,
                                              locations: _locations,
                                              amtFmt: _amtFmt,
                                              showImage: _showImage,
                                              onRemove: () => _removeLine(i),
                                              onChanged: () => setState(() {}),
                                              onPickItem: () => _pickItem(i),
                                              apiKey: _apiKey,
                                              companyGUID: _companyGUID,
                                              userID: _userID,
                                              userSessionID: _userSessionID,
                                              enableTax: _isEnableTax,
                                              priceCategory: _priceCategory,
                                            )),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      // TODO: open item picker
                                    },
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add Item'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(
                                          double.infinity, 44),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      side: BorderSide(
                                          color: primary
                                              .withValues(alpha: 0.4)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              ),

            // ── Save button ───────────────────────────────────────────
            SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
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
    ),
    );
  }
}

// ── Field label ────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
          letterSpacing: 0.2,
        ),
      );
}

// ── Field box (tap-to-select fields) ──────────────────────────────────

class _FieldBox extends StatelessWidget {
  final Widget child;
  final BoxDecoration decoration;
  final EdgeInsets padding;

  const _FieldBox({
    required this.child,
    required this.decoration,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: decoration,
        padding: padding,
        child: child,
      );
}

// ─────────────────────────────────────────────────────────────────────
// Line item model
// ─────────────────────────────────────────────────────────────────────

class _LineItem {
  int dtlID = 0;
  int stockID = 0;
  String stockCode = '';
  String uom = '';
  String? itemImage; // base64 from API
  final descriptionCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final unitPriceCtrl = TextEditingController(text: '0');
  final discountCtrl = TextEditingController(text: '0');
  TaxType? selectedTaxType;
  Location? selectedLocation;

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get unitPrice => double.tryParse(unitPriceCtrl.text) ?? 0;

  // Parses compound discount strings like "10%+5" (10% off then RM5 off).
  // Rules:
  //   - Parts separated by "+"
  //   - Part ending with "%" → percentage of remaining amount
  //   - Part without "%" → fixed RM amount
  //   - Plain number with no "+" or "%" → percentage (backward compat)
  static double _parseDiscountAmt(String text, double subtotal) {
    final t = text.trim();
    if (t.isEmpty || t == '0') return 0;
    if (!t.contains('+') && !t.contains('%')) {
      return subtotal * (double.tryParse(t) ?? 0) / 100;
    }
    final parts = t.split('+');
    double remaining = subtotal;
    double totalDisc = 0;
    for (final part in parts) {
      final p = part.trim();
      if (p.isEmpty) continue;
      if (p.endsWith('%')) {
        final pct = double.tryParse(p.replaceAll('%', '')) ?? 0;
        final disc = remaining * pct / 100;
        totalDisc += disc;
        remaining -= disc;
      } else {
        final fixed = double.tryParse(p) ?? 0;
        totalDisc += fixed;
        remaining -= fixed;
      }
    }
    return totalDisc;
  }

  double get discountAmt => _parseDiscountAmt(discountCtrl.text, qty * unitPrice);
  double get discount {
    final sub = qty * unitPrice;
    if (sub == 0) return 0;
    return discountAmt / sub * 100;
  }

  double get lineTotal => qty * unitPrice - discountAmt;
  double get lineTaxableAmt => selectedTaxType != null ? lineTotal : 0;
  double get lineTaxAmt =>
      lineTaxableAmt * (selectedTaxType?.taxRate ?? 0) / 100;

  void dispose() {
    descriptionCtrl.dispose();
    qtyCtrl.dispose();
    unitPriceCtrl.dispose();
    discountCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Line item card
// ─────────────────────────────────────────────────────────────────────

class _LineItemCard extends StatefulWidget {
  final int index;
  final _LineItem item;
  final List<TaxType> taxTypes;
  final List<Location> locations;
  final NumberFormat amtFmt;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onPickItem;
  final bool showImage;
  final bool enableTax;
  final int priceCategory;
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  const _LineItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.taxTypes,
    required this.locations,
    required this.amtFmt,
    required this.showImage,
    required this.enableTax,
    required this.priceCategory,
    required this.onRemove,
    required this.onChanged,
    required this.onPickItem,
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
  });

  @override
  State<_LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends State<_LineItemCard> {
  bool _expanded = false;
  double? _pointerDownX;
  double? _pointerDownY;

  @override
  void initState() {
    super.initState();
    for (final ctrl in [
      widget.item.qtyCtrl,
      widget.item.unitPriceCtrl,
      widget.item.discountCtrl,
    ]) {
      ctrl.addListener(() => setState(() {}));
    }
    widget.item.descriptionCtrl.addListener(() => setState(() {}));
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LineItemEditSheet(
        item: widget.item,
        taxTypes: widget.taxTypes,
        enableTax: widget.enableTax,
        priceCategory: widget.priceCategory,
        apiKey: widget.apiKey,
        companyGUID: widget.companyGUID,
        userID: widget.userID,
        userSessionID: widget.userSessionID,
        onChanged: () {
          widget.onChanged();
          if (mounted) setState(() {});
        },
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
            '${widget.index + 1}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: primary),
          ),
        ),
      );

  String _fmtNum(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final item = widget.item;
    final fmt = widget.amtFmt;

    // ── Build image or badge ──────────────────────────────────────────────
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
            errorBuilder: (_, __, ___) => _indexBadge(primary),
          ),
        );
      } catch (_) {
        leading = _indexBadge(primary);
      }
    } else {
      leading = _indexBadge(primary);
    }

    // ── Breakdown amounts (shown when expanded) ───────────────────────────
    final discAmt = item.discountAmt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        // Outer GestureDetector catches right-swipe since Slidable has no
        // startActionPane and therefore rejects rightward drags from its arena.
        child: Listener(
          onPointerDown: (e) {
            _pointerDownX = e.localPosition.dx;
            _pointerDownY = e.localPosition.dy;
          },
          onPointerUp: (e) {
            final sx = _pointerDownX;
            final sy = _pointerDownY;
            _pointerDownX = null;
            _pointerDownY = null;
            if (sx != null && sy != null) {
              final dx = e.localPosition.dx - sx;
              final dy = (e.localPosition.dy - sy).abs();
              if (dx > 280 && dy < 40) {
                widget.onPickItem();
              }
            }
          },
          child: Slidable(
            key: widget.key,
            // Slide LEFT → edit + delete
            endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.48,
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1565C0))),
                  ],
                ),
              ),
              CustomSlidableAction(
                onPressed: (_) => widget.onRemove(),
                backgroundColor: Colors.red.withValues(alpha: 0.12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.delete_outline, size: 26, color: Colors.red),
                    SizedBox(height: 4),
                    Text('Delete',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                color: (Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface).withValues(alpha: 0.5),
                border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Image / badge — vertically centered
                  leading,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: stock code (left) | qty badge (right)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
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
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                'x ${_fmtNum(item.qty)}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primary),
                              ),
                            ),
                          ],
                        ),
                        // Row 2: description
                        const SizedBox(height: 2),
                          Text(
                            item.descriptionCtrl.text,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.65)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 4),
                        // Row 3: UOM + badges (left) | total (right)
                        Row(
                          children: [
                            Text(
                              item.uom,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onSurface.withValues(alpha: 0.5)),
                            ),
                            if (item.discountCtrl.text.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.discountCtrl.text,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Color.fromARGB(255, 255, 123, 0),
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            if (widget.enableTax && item.selectedTaxType != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.selectedTaxType!.taxCode ?? '',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.teal,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              fmt.format(item.lineTotal),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: primary),
                            ),
                          ],
                        ),
                        // Expanded: subtotal / discount / tax breakdown
                        if (_expanded) ...[
                          const SizedBox(height: 8),
                          Divider(
                              height: 1,
                              color: cs.outline.withValues(alpha: 0.2)),
                          const SizedBox(height: 8),
                          _breakdownRow(
                              'Subtotal',
                              fmt.format(item.qty * item.unitPrice),
                              cs),
                            const SizedBox(height: 3),
                            _breakdownRow(
                                'Discount',
                                '- ${fmt.format(discAmt)}',
                                cs,
                                valueColor: Mycolor.discountTextColor),
                        
                          if (widget.enableTax) ...[
                            const SizedBox(height: 3),
                            _breakdownRow(
                                'Tax (${item.selectedTaxType?.taxRate ?? ''}%) ',
                                '+ ${fmt.format(item.lineTaxAmt)}',
                                cs,
                                valueColor: Mycolor.taxTextColor),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }

  Widget _breakdownRow(String label, String value, ColorScheme cs,
      {Color? valueColor}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: valueColor ?? cs.onSurface.withValues(alpha: 0.65))),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Line item edit sheet
// ─────────────────────────────────────────────────────────────────────

class _LineItemEditSheet extends StatefulWidget {
  final _LineItem item;
  final List<TaxType> taxTypes;
  final bool enableTax;
  final int priceCategory;
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;
  final VoidCallback onChanged;

  const _LineItemEditSheet({
    required this.item,
    required this.taxTypes,
    required this.enableTax,
    required this.priceCategory,
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
    required this.onChanged,
  });

  @override
  State<_LineItemEditSheet> createState() => _LineItemEditSheetState();
}

class _LineItemEditSheetState extends State<_LineItemEditSheet> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _discCtrl;
  TaxType? _taxType;
  String _uom = '';

  List<StockUOMDto> _uomList = [];
  bool _loadingUOM = true;
  int _qtyDp = 2;
  int _priceDp = 2;

  final _amtFmt = NumberFormat('#,##0.00');
  

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _qtyCtrl = TextEditingController(text: item.qtyCtrl.text);
    _priceCtrl = TextEditingController(text: item.unitPriceCtrl.text);
    _discCtrl = TextEditingController(text: item.discountCtrl.text);
    _taxType = item.selectedTaxType;
    _uom = item.uom;
    _qtyCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
    _discCtrl.addListener(() => setState(() {}));
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      SessionManager.getQuantityDecimalPoint(),
      SessionManager.getSalesDecimalPoint(),
      _fetchUOMList(),
    ]);
    if (!mounted) return;
    setState(() {
      _qtyDp = results[0] as int;
      _priceDp = results[1] as int;
      _loadingUOM = false;
    });
  }

  Future<List<StockUOMDto>> _fetchUOMList() async {
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getStock,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'stockID': widget.item.stockID,
        },
      );
      final detail = StockDetail.fromJson(json as Map<String, dynamic>);
      if (mounted) {
        setState(() {
          _uomList = detail.stockUOMDtoList;
          // Apply the correct price for the current UOM based on price category
          final current = _uomList.where((u) => u.uom == _uom).firstOrNull;
          if (current != null) {
            _priceCtrl.text = _formatDp(_priceForCategory(current), _priceDp);
          }
        });
      }
    } catch (_) {}
    return _uomList;
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _discCtrl.dispose();
    super.dispose();
  }

  // ── Live computed values ─────────────────────────────────────────────
  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;
  double get _unitPrice => double.tryParse(_priceCtrl.text) ?? 0;
  double get _subtotal => _qty * _unitPrice;
  double get _discAmt => _LineItem._parseDiscountAmt(_discCtrl.text, _subtotal);
  double get _lineTotal => _subtotal - _discAmt;
  double get _taxAmt {
    final rate = _taxType?.taxRate ?? 0;
    if (rate == 0) return 0;
    return _lineTotal * (rate / 100);
  }

  // ── Qty helpers ──────────────────────────────────────────────────────
  void _clampQty() {
    final v = double.tryParse(_qtyCtrl.text) ?? 0;
    if (v < 1) _qtyCtrl.text = _formatDp(1.0, _qtyDp);
  }

  void _stepQty(int delta) {
    final current = double.tryParse(_qtyCtrl.text) ?? 1;
    final next = (current + delta).clamp(1.0, double.infinity);
    _qtyCtrl.text = _formatDp(next, _qtyDp);
  }

  String _formatDp(double v, int dp) {
    if (dp == 0) return v.toInt().toString();
    return v.toStringAsFixed(dp);
  }

  double _priceForCategory(StockUOMDto uom) {
    switch (widget.priceCategory) {
      case 2: return uom.price2;
      case 3: return uom.price3;
      case 4: return uom.price4;
      case 5: return uom.price5;
      case 6: return uom.price6;
      default: return uom.price1;
    }
  }

  void _onUOMSelected(StockUOMDto uom) {
    setState(() {
      _uom = uom.uom;
      _priceCtrl.text = _formatDp(_priceForCategory(uom), _priceDp);
    });
  }

  void _apply() {
    final item = widget.item;
    item.qtyCtrl.text = _qtyCtrl.text;
    item.uom = _uom;
    item.unitPriceCtrl.text = _priceCtrl.text;
    item.discountCtrl.text = _discCtrl.text;
    item.selectedTaxType = _taxType;
    widget.onChanged();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    final int _salesDp = 2;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Item title
            Text(widget.item.stockCode,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primary)),
            if (widget.item.descriptionCtrl.text.isNotEmpty)
              Text(widget.item.descriptionCtrl.text,
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 20),

            // ── UOM selector ────────────────────────────────────────────
            Text('UOM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            _loadingUOM
                ? const SizedBox(height: 44, child: Center(child: DotsLoading()))
                : _uomList.isEmpty
                    ? uomChip(context, _uom, selected: true)
                    : SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 4),
                          itemCount: _uomList.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final u = _uomList[i];
                            return uomChip(context, u.uom,
                                selected: _uom == u.uom,
                                onTap: () => _onUOMSelected(u));
                          },
                        ),
                      ),
            const SizedBox(height: 20),

            // ── Qty stepper ──────────────────────────────────────────────
            Text('Quantity', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 8),
            Row(
              children: [
                stepBtn(context, Icons.remove_rounded, () => _stepQty(-1)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    decoration: sheetInputDeco(context),
                    onEditingComplete: _clampQty,
                    onTapOutside: (_) => _clampQty(),
                  ),
                ),
                const SizedBox(width: 10),
                stepBtn(context, Icons.add_rounded, () => _stepQty(1)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Unit Price + Discount ────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Unit Price', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.5))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                        style: const TextStyle(fontSize: 14),
                        decoration: sheetInputDeco(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Discount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.5))),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _discCtrl,
                        keyboardType: TextInputType.text,
                        autocorrect: false,
                        enableSuggestions: false,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.+%]'))],
                        style: const TextStyle(fontSize: 14),
                        decoration: sheetInputDeco(context).copyWith(
                          //hintText: 'e.g. 10% or 10%+5',
                          //hintStyle: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.3)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Tax ──────────────────────────────────────────────────────
            if (widget.enableTax) ...[
              Text('Tax Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.5))),
              const SizedBox(height: 8),
              DropdownButtonFormField<TaxType?>(
                value: _taxType,
                isExpanded: true,
                style: const TextStyle(fontSize: 13, color: Colors.black),
                dropdownColor: Colors.white,
                decoration: sheetInputDeco(context),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No Tax',
                        style: TextStyle(fontSize: 13, color: Colors.black54)),
                  ),
                  ...widget.taxTypes.map((t) => DropdownMenuItem(
                        value: t,
                        child: Text('${t.taxCode} (${t.taxRate?.toStringAsFixed(0)}%)',
                            style: const TextStyle(fontSize: 13, color: Colors.black)),
                      )),
                ],
                onChanged: (v) => setState(() => _taxType = v),
              ),
              const SizedBox(height: 20),
            ],

            const SizedBox(height: 16),
            // ── Summary ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  FormTotalPriceSummaryRow(
                    label: 'Subtotal',
                    value: StockCommon.formatDP(_subtotal, _salesDp),
                    muted: muted),

                  const SizedBox(height: 6),
                  FormTotalPriceSummaryRow(
                    label: 'Discount',
                    value: '- ${StockCommon.formatDP(_discAmt, _salesDp)}',
                    muted: muted,
                    valueColor: _discAmt == 0 ? muted : Mycolor.discountTextColor),
                        
                  if (widget.enableTax) ...[
                    const SizedBox(height: 6),
                    FormTotalPriceSummaryRow(
                      label: 'Tax', 
                      value: '+ ${StockCommon.formatDP(_taxAmt, _salesDp)}',
                      muted: muted,
                      valueColor: _taxType?.taxCode == null ? muted : Mycolor.taxTextColor),
                  ],
                  Divider(height: 16, color: primary.withValues(alpha: 0.15)),
                  FormTotalPriceSummaryRow(
                      label: 'Total', 
                      value: StockCommon.formatDP(_lineTotal + (widget.enableTax ? _taxAmt : 0), _salesDp),
                      muted: muted,
                      valueColor: Mycolor.primary),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Apply button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _apply,
                child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

}


