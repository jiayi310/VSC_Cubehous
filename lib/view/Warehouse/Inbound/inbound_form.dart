import 'dart:convert';

import 'package:cubehous/api/api_endpoints.dart';
import 'package:cubehous/api/base_client.dart';
import 'package:cubehous/common/direction_chip.dart';
import 'package:cubehous/common/dots_loading.dart';
import 'package:cubehous/common/my_color.dart';
import 'package:cubehous/common/pagination_bar.dart';
import 'package:cubehous/common/session_manager.dart';
import 'package:cubehous/common/stock_common.dart';
import 'package:cubehous/models/customer.dart';
import 'package:cubehous/models/inbound.dart';
import 'package:cubehous/models/location.dart';
import 'package:cubehous/models/purchase_order.dart';
import 'package:cubehous/models/receiving.dart';
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
  int _defaultLocationID = 0;

  // ── Section expand state ────────────────────────────────────────────
  final _formScrollCtrl = ScrollController();
  bool _isSaving = false;
  bool _isUpdatingPrices = false;
  bool _isLoadingPO = false;
  bool _scanning = false;
  bool _scanSearching = false;
  bool _showImage = true;
  bool _isEnableTax = false;
  bool _docExpanded = true;
  bool _notesExpanded = true;
  bool _itemsExpanded = true;
  bool _rcvPOExpanded = true;
  bool _loadingDropdowns = true;
 
  List<Location> _locations = [];
  List<TaxType> _taxTypes = [];
  Customer? _selectedCustomer;
  int get _priceCategory => _selectedCustomer?.priceCategory ?? 1;
  ReceivingPurchaseItem? _selectedPO;
  String _supplierCode = '';
  String _supplierName = '';
  String _address1 = '', _address2 = '', _address3 = '', _address4 = '';
  bool _supplierExpanded = true;

  // ── Header state ─────────────────────────────────────────────────
  String? _docType;
  DateTime _docDate = DateTime.now();
  final _descriptionCtrl = TextEditingController();
  final _remarkCtrl  = TextEditingController();

  // ── Items ────────────────────────────────────────────────────────────
  final List<_LineItem> _lines = [];

  late DateFormat _dateFmt;
  late NumberFormat _amtFmt;
  late NumberFormat _qtyFmt;

  static const _docTypeOptions = [
    (code: 'RCV', label: 'Receiving'),
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
    _descriptionCtrl.dispose();
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
      SessionManager.getQuantityDecimalPoint(),
      SessionManager.getDateFormat(),
      SessionManager.getPurchaseDecimalPoint(),
    ]);
    if (mounted) {
      setState(() {
        _showImage = (results[0] as String) == 'show';
        _isEnableTax = results[1] as bool;
        _defaultLocationID = results[2] as int;
        final qtyDp = results[3] as int;
        _qtyFmt = NumberFormat('#,##0.${'0' * qtyDp}');
        _dateFmt = DateFormat(results[4] as String);
        final amtDp = results[5] as int;
        _amtFmt = NumberFormat('#,##0.${'0' * amtDp}');
      });
    }
    
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
      await _checkAndRestoreDraft();
      if (_isEditMode && widget.initialDoc != null) {
        if (mounted) setState(() => _initFromDoc(widget.initialDoc!));
        if (_showImage) _loadImagesForLines();
      }
    } catch (_) {
      setState(() => _loadingDropdowns = false);
    }
  }

// ── Draft helpers ─────────────────────────────────────────────────────
  bool get _hasChanges =>
      _docType != null ||
      _selectedPO != null ||
      _lines.isNotEmpty ||
      _descriptionCtrl.text.isNotEmpty ||
      _remarkCtrl.text.isNotEmpty;

  Future<void> _saveDraft() async {
    final draft = {
      'docType': _docType,
      'docDate': _docDate.toIso8601String(),
      'description': _descriptionCtrl.text,
      'remark': _remarkCtrl.text,
      'selectedPODocID': _selectedPO?.docID,
      'selectedPODocNo': _selectedPO?.docNo,
      'selectedPODocDate': _selectedPO?.docDate,
      'selectedPOSupplierCode': _selectedPO?.supplierCode,
      'selectedPOSupplierName': _selectedPO?.supplierName,
      'supplierCode': _supplierCode,
      'supplierName': _supplierName,
      'address1': _address1,
      'address2': _address2,
      'address3': _address3,
      'address4': _address4,
      'lines': _lines.map((l) => {
        'stockID': l.stockID,
        'stockCode': l.stockCode,
        'uom': l.uom,
        'description': l.descriptionCtrl.text,
        'qty': l.qtyCtrl.text,
        'unitPrice': l.unitPriceCtrl.text,
        'discount': l.discountCtrl.text,
        'taxTypeID': l.selectedTaxType?.taxTypeID,
        'locationID': l.selectedLocation?.locationID,
        'fromPO': l.fromPO,
      }).toList(),
    };
    await SessionManager.saveInboundDraft(jsonEncode(draft));
  }

  void _restoreDraft(Map<String, dynamic> j) {
    _docType = j['docType'] as String?;
    _docDate = DateTime.tryParse(j['docDate'] as String? ?? '') ?? DateTime.now();
    _descriptionCtrl.text = j['description'] as String? ?? '';
    _remarkCtrl.text = j['remark'] as String? ?? '';
    _supplierCode = j['supplierCode'] as String? ?? '';
    _supplierName = j['supplierName'] as String? ?? '';
    _address1 = j['address1'] as String? ?? '';
    _address2 = j['address2'] as String? ?? '';
    _address3 = j['address3'] as String? ?? '';
    _address4 = j['address4'] as String? ?? '';
    final poDocID = j['selectedPODocID'] as int?;
    if (poDocID != null) {
      _selectedPO = ReceivingPurchaseItem(
        docID: poDocID,
        docNo: j['selectedPODocNo'] as String? ?? '',
        docDate: j['selectedPODocDate'] as String? ?? '',
        supplierCode: j['selectedPOSupplierCode'] as String? ?? '',
        supplierName: j['selectedPOSupplierName'] as String? ?? '',
      );
    }
    final rawLines = j['lines'] as List<dynamic>? ?? [];
    _lines.clear();
    for (final raw in rawLines) {
      final m = raw as Map<String, dynamic>;
      final line = _LineItem();
      line.stockID = (m['stockID'] as int?) ?? 0;
      line.stockCode = (m['stockCode'] as String?) ?? '';
      line.uom = (m['uom'] as String?) ?? '';
      line.fromPO = (m['fromPO'] as bool?) ?? false;
      line.descriptionCtrl.text = (m['description'] as String?) ?? '';
      line.qtyCtrl.text = (m['qty'] as String?) ?? '1';
      line.unitPriceCtrl.text = (m['unitPrice'] as String?) ?? '0';
      line.discountCtrl.text = (m['discount'] as String?) ?? '0';
      final taxTypeID = m['taxTypeID'] as int?;
      if (taxTypeID != null) {
        line.selectedTaxType = _taxTypes.where((t) => t.taxTypeID == taxTypeID).firstOrNull;
      }
      final locationID = m['locationID'] as int?;
      if (locationID != null) {
        line.selectedLocation = _locations.where((l) => l.locationID == locationID).firstOrNull;
      }
      _lines.add(line);
    }
  }

  void _initFromDoc(InboundDoc doc) {
    _editDocID = doc.docID;
    _editDocNo = doc.docNo;
    _docType = doc.docType;
    _docDate = DateTime.tryParse(doc.docDate) ?? DateTime.now();
    _descriptionCtrl.text = doc.description ?? '';
    _remarkCtrl.text = doc.remark ?? '';
    _lines.clear();
    for (final d in doc.lines) {
      final line = _LineItem();
      line.dtlID = d.dtlID;
      line.stockID = d.stockID;
      line.stockCode = d.stockCode;
      line.uom = d.uom;
      line.itemImage = d.image;
      line.descriptionCtrl.text = d.description;
      line.qtyCtrl.text = d.qty.toString();
      line.unitPriceCtrl.text = d.unitPrice.toString();
      line.discountCtrl.text = d.discount.toString();
      if (d.taxTypeID != null) {
        line.selectedTaxType = _taxTypes.where((t) => t.taxTypeID == d.taxTypeID).firstOrNull;
      }
      if (d.locationID != null) {
        line.selectedLocation = _locations.where((l) => l.locationID == d.locationID).firstOrNull;
      }
      _lines.add(line);
    }
  }

  Future<void> _loadImagesForLines() async {
    final body = {
      'apiKey': _apiKey,
      'companyGUID': _companyGUID,
      'userID': _userID,
      'userSessionID': _userSessionID,
    };
    for (final line in _lines) {
      if (line.stockID == 0) continue;
      try {
        final json = await BaseClient.post(
          ApiEndpoints.getStock,
          body: {...body, 'stockID': line.stockID},
        );
        final detail = StockDetail.fromJson(json as Map<String, dynamic>);
        if (detail.image != null && detail.image!.isNotEmpty) {
          if (mounted) setState(() => line.itemImage = detail.image);
        }
      } catch (_) {}
    }
  }

  Future<void> _checkAndRestoreDraft() async {
    if (_isEditMode) return;
    final raw = await SessionManager.getInboundDraft();
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) setState(() => _restoreDraft(j));
    } catch (_) {
      await SessionManager.clearInboundDraft();
    }
  }

  Future<bool> _onWillPop() async {
    if (_isEditMode) return true;
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
                width: 64, height: 64,
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
                  style: TextStyle(fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.6), height: 1.5),
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
                            style: TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface.withValues(alpha: 0.5))),
                      ),
                    ),
                    VerticalDivider(width: 1, color: cs.outline.withValues(alpha: 0.15)),
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
                            style: TextStyle(fontSize: 14,
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
    if (result == null) return false; // cancelled
    if (result == 'save') await _saveDraft();
    if (result == 'discard') await SessionManager.clearInboundDraft();
    return true;
  }

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

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Theme.of(context).colorScheme.error,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _save() async {
    if (_docType == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Please select a document type'),
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    if (_docType == 'RCV' && _selectedPO == null) {
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
      final details = _lines.map((l) => {
        'dtlID': l.dtlID,
        'stockID': l.stockID,
        'stockCode': l.stockCode,
        'uom': l.uom,
        'description': l.descriptionCtrl.text.trim(),
        'qty': l.qty,
        'unitPrice': l.unitPrice,
        'discount': l.discount,
        'taxTypeID': l.selectedTaxType?.taxTypeID ?? 0,
        'locationID': l.selectedLocation?.locationID ?? 0,
      }).toList();

      final body = {
        'apiKey': _apiKey,
        'companyGUID': _companyGUID,
        'userID': _userID,
        'userSessionID': _userSessionID,
        'docType': _docType,
        'docDate': _docDate.toIso8601String(),
        'description': _descriptionCtrl.text.trim(),
        'remark': _remarkCtrl.text.trim(),
        'purchaseDocID': _selectedPO?.docID ?? 0,
        'inboundDetails': details,
      };

      if (_isEditMode) {
        await BaseClient.post(
          ApiEndpoints.updateInbound,
          body: {...body, 'docID': _editDocID},
        );
      } else {
        await BaseClient.post(ApiEndpoints.createInbound, body: body);
        await SessionManager.clearInboundDraft();
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(e is BadRequestException ? e.message : 'Failed: $e'),
            behavior: SnackBarBehavior.floating,
          ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_formScrollCtrl.hasClients) {
            _formScrollCtrl.animateTo(
              _formScrollCtrl.position.maxScrollExtent,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
            );
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

      // Keep manually-added lines, dispose PO-origin ones
      final kept = <_LineItem>[];
      for (final l in _lines) {
        if (!l.fromPO) {
          kept.add(l);
        } else {
          l.dispose();
        }
      }

      // Pre-fill lines from PO items
      for (final pl in doc.purchaseDetails) {
        final line = _LineItem();
        line.stockID = pl.stockID ?? 0;
        line.stockCode = pl.stockCode;
        line.uom = pl.uom;
        line.fromPO = true;
        line.descriptionCtrl.text = pl.description;
        line.qtyCtrl.text = pl.qty.toString();
        line.unitPriceCtrl.text = pl.unitPrice.toString();
        kept.add(line);
      }

      setState(() {
        _supplierCode = doc.supplierCode;
        _supplierName = doc.supplierName;
        _address1 = doc.address1 ?? '';
        _address2 = doc.address2 ?? '';
        _address3 = doc.address3 ?? '';
        _address4 = doc.address4 ?? '';
        _lines
          ..clear()
          ..addAll(kept);
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
      final kept = _lines.where((l) => !l.fromPO).toList();
      for (final l in _lines) {
        if (l.fromPO) l.dispose();
      }
      _lines
        ..clear()
        ..addAll(kept);
      _supplierCode = '';
      _supplierName = '';
      _address1 = '';
      _address2 = '';
      _address3 = '';
      _address4 = '';
    });
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
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
        body: (_loadingDropdowns || _isLoadingPO)
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
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: _docExpanded
                          ? Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // Doc Type
                                  FieldLabel(label: 'Doc Type *'),
                                  const SizedBox(height: 12),
                                  InkWell(
                                    onTap: _pickDocType,
                                    borderRadius: BorderRadius.circular(12),
                                    child: FieldBox(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.notes, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _docType == null
                                                ? Text(
                                                    'Select document type',
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        color: cs.onSurface.withValues(alpha: 0.4)),
                                                  )
                                                : Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        _docTypeOptions
                                                            .firstWhere((o) => o.code == _docType,
                                                                orElse: () => (code: _docType!, label: _docType!))
                                                            .label,
                                                        style: const TextStyle(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600),
                                                      ),
                                                      Text(_docType!,
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color: primary)),
                                                    ],
                                                  ),
                                          ),
                                          Icon(Icons.chevron_right_rounded,
                                              size: 18,
                                              color: cs.onSurface.withValues(alpha: 0.4)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Doc Date
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
                                  const SizedBox(height: 4),
                                ],
                              )
                          : const SizedBox.shrink(),
                    ),

                    // ── Notes ─────────────────────────────────────
                    FormSectionHeader(
                            icon: Icons.notes_outlined,
                            title: 'Notes',
                            expanded: _notesExpanded,
                            onToggle: () => setState(() => _notesExpanded = !_notesExpanded)),
                    AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          child: _notesExpanded
                              ? Column(
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
                                )
                              : const SizedBox.shrink(),
                        ),

                    // ── RCV Select PO ─────────────────────────────────
                    if (_docType == 'RCV') ...[
                      FormSectionHeader(
                        icon: Icons.receipt_long_outlined,
                        title: 'Purchase Order',
                        expanded: _rcvPOExpanded,
                        onToggle: () => setState(() => _rcvPOExpanded = !_rcvPOExpanded),
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: _rcvPOExpanded
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FieldLabel(label: 'PO Ref *'),
                                  InkWell(
                                    onTap: _openPOPicker,
                                    borderRadius: BorderRadius.circular(12),
                                    child: FieldBox(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.receipt_outlined, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _selectedPO != null
                                                ? Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(_selectedPO!.docNo,
                                                          style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w600,
                                                              color: primary)),
                                                      Text(_selectedPO!.supplierName,
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color: cs.onSurface.withValues(alpha: 0.6))),
                                                    ],
                                                  )
                                                : Text(
                                                    'Select Purchase Order',
                                                    style: TextStyle(
                                                        fontSize: 14,
                                                        color: cs.onSurface.withValues(alpha: 0.4)),
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
                                  // Supplier card (shown after PO selected)
                                  if (_supplierName.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: primary.withValues(alpha: 0.04),
                                        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_supplierName,
                                              style: const TextStyle(
                                                  fontSize: 13, fontWeight: FontWeight.w700)),
                                          if (_supplierCode.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(_supplierCode,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: cs.onSurface.withValues(alpha: 0.55))),
                                          ],
                                          if ([_address1, _address2, _address3, _address4]
                                              .any((a) => a.isNotEmpty)) ...[
                                            const SizedBox(height: 4),
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
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],


                    // ── Items ─────────────────────────────────
                    FormSectionHeader(
                      icon: Icons.list_alt_outlined,
                      title: 'Items',
                      expanded: _itemsExpanded,
                      onToggle: () => setState(() => _itemsExpanded = !_itemsExpanded),
                      badge: '${_lines.length}'
                    ),
                    AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          child: _itemsExpanded
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SlidableAutoCloseBehavior(
                                      child: Column(
                                        children: _lines.asMap().entries.map((e) => _LineItemCard(
                                              key: ValueKey(e.key),
                                              index: e.key,
                                              item: e.value,
                                              taxTypes: _taxTypes,
                                              locations: _locations,
                                              amtFmt: _amtFmt,
                                              qtyFmt: _qtyFmt,
                                              showImage: _showImage,
                                              onRemove: () => _removeLine(e.key),
                                              onChanged: () => setState(() {}),
                                              onPickItem: () => _pickItem(e.key),
                                              apiKey: _apiKey,
                                              companyGUID: _companyGUID,
                                              userID: _userID,
                                              userSessionID: _userSessionID,
                                              enableTax: _isEnableTax,
                                              priceCategory: _priceCategory,
                                            )).toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: _addLine,
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
                        const SizedBox(height: 50),
                  ],
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
                      child: Text(
                          _isEditMode ? 'Update' : 'Save',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
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

// ─────────────────────────────────────────────────────────────────────
// Line item model
// ─────────────────────────────────────────────────────────────────────

class _LineItem {
  int dtlID = 0;
  int stockID = 0;
  String stockCode = '';
  String uom = '';
  String? itemImage; // base64 from API
  bool fromPO = false;
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
  final NumberFormat qtyFmt;
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
    required this.qtyFmt,
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

    final int salesDp = 2;

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
                initialValue: _taxType,
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
                    value: StockCommon.formatDP(_subtotal, salesDp),
                    muted: muted),

                  const SizedBox(height: 6),
                  FormTotalPriceSummaryRow(
                    label: 'Discount',
                    value: '- ${StockCommon.formatDP(_discAmt, salesDp)}',
                    muted: muted,
                    valueColor: _discAmt == 0 ? muted : Mycolor.discountTextColor),
                        
                  if (widget.enableTax) ...[
                    const SizedBox(height: 6),
                    FormTotalPriceSummaryRow(
                      label: 'Tax', 
                      value: '+ ${StockCommon.formatDP(_taxAmt, salesDp)}',
                      muted: muted,
                      valueColor: _taxType?.taxCode == null ? muted : Mycolor.taxTextColor),
                  ],
                  Divider(height: 16, color: primary.withValues(alpha: 0.15)),
                  FormTotalPriceSummaryRow(
                      label: 'Total', 
                      value: StockCommon.formatDP(_lineTotal + (widget.enableTax ? _taxAmt : 0), salesDp),
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


