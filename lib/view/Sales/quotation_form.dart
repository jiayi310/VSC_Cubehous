import 'dart:convert';
import 'package:cubehous/common/my_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../common/session_manager.dart';
import '../../models/customer.dart';
import '../../models/location.dart';
import '../../models/tax_type.dart';
import '../../models/sales_agent.dart';
import '../../models/shipping_method.dart';
import '../../models/stock.dart';
import '../../models/stock_detail.dart';
import '../../models/quotation.dart';
import '../Common/customer_picker_page.dart';
import '../Common/sales_agent_picker_page.dart';
import '../Common/item_picker_page.dart';

class QuotationFormPage extends StatefulWidget {
  final QuotationDoc? initialDoc;
  const QuotationFormPage({super.key, this.initialDoc});

  @override
  State<QuotationFormPage> createState() => _QuotationFormPageState();
}

class _QuotationFormPageState extends State<QuotationFormPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  bool get _isEditMode => widget.initialDoc != null;
  int _editDocID = 0;
  String _editDocNo = '';
  int _defaultLocationID = 0;

  // Header state
  DateTime _docDate = DateTime.now();
  Customer? _selectedCustomer;
  SalesAgent? _selectedSalesAgent;
  final _descriptionCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  // Quotation-specific customer info (editable per quotation, does not affect original customer)
  String _addr1 = '', _addr2 = '', _addr3 = '', _addr4 = '';
  String _deliverAddr1 = '', _deliverAddr2 = '', _deliverAddr3 = '', _deliverAddr4 = '';
  String _attention = '', _phone = '', _fax = '', _email = '';

  // Line items
  final List<_LineItem> _lines = [];

  // Dropdown data
  List<TaxType> _taxTypes = [];
  List<Location> _locations = [];
  List<ShippingMethod> _shippingMethods = [];
  ShippingMethod? _selectedShippingMethod;
  bool _loadingDropdowns = true;

  final _formScrollCtrl = ScrollController();
  bool _footerExpanded = false;
  bool _isSaving = false;
  bool _isUpdatingPrices = false;
  bool _scanning = false;
  bool _scanSearching = false;
  bool _showImage = true;
  bool _isEnableTax = false;
  bool _docExpanded = true;
  bool _notesExpanded = true;
  bool _itemsExpanded = true;
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _amtFmt = NumberFormat('#,##0.00');

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
        BaseClient.post(ApiEndpoints.getShippingMethodList, body: body),
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
        _shippingMethods = (results[2] as List<dynamic>)
            .map((e) => ShippingMethod.fromJson(e as Map<String, dynamic>))
            .where((s) => !s.isDisabled)
            .toList();
        _loadingDropdowns = false;
      });
      await _checkAndRestoreDraft();
      if (_isEditMode && widget.initialDoc != null) {
        if (mounted) setState(() => _initFromDoc(widget.initialDoc!));
      }
    } catch (_) {
      setState(() => _loadingDropdowns = false);
    }
  }

  // ── Draft helpers ─────────────────────────────────────────────────────

  bool get _hasChanges =>
      _selectedCustomer != null ||
      _lines.isNotEmpty ||
      _descriptionCtrl.text.isNotEmpty ||
      _remarkCtrl.text.isNotEmpty ||
      _selectedSalesAgent != null ||
      _selectedShippingMethod != null;

  Future<void> _saveDraft() async {
    final draft = {
      'docDate': _docDate.toIso8601String(),
      'description': _descriptionCtrl.text,
      'remark': _remarkCtrl.text,
      'addr1': _addr1, 'addr2': _addr2, 'addr3': _addr3, 'addr4': _addr4,
      'deliverAddr1': _deliverAddr1, 'deliverAddr2': _deliverAddr2,
      'deliverAddr3': _deliverAddr3, 'deliverAddr4': _deliverAddr4,
      'attention': _attention, 'phone': _phone, 'fax': _fax, 'email': _email,
      'customer': _selectedCustomer == null ? null : {
        'customerID': _selectedCustomer!.customerID,
        'customerCode': _selectedCustomer!.customerCode,
        'name': _selectedCustomer!.name,
        'name2': _selectedCustomer!.name2,
        'address1': _selectedCustomer!.address1,
        'address2': _selectedCustomer!.address2,
        'address3': _selectedCustomer!.address3,
        'address4': _selectedCustomer!.address4,
        'postCode': _selectedCustomer!.postCode,
        'deliverAddr1': _selectedCustomer!.deliverAddr1,
        'deliverAddr2': _selectedCustomer!.deliverAddr2,
        'deliverAddr3': _selectedCustomer!.deliverAddr3,
        'deliverAddr4': _selectedCustomer!.deliverAddr4,
        'deliverPostCode': _selectedCustomer!.deliverPostCode,
        'attention': _selectedCustomer!.attention,
        'phone1': _selectedCustomer!.phone1,
        'phone2': _selectedCustomer!.phone2,
        'fax1': _selectedCustomer!.fax1,
        'fax2': _selectedCustomer!.fax2,
        'email': _selectedCustomer!.email,
        'priceCategory': _selectedCustomer!.priceCategory,
        'customerTypeID': _selectedCustomer!.customerTypeID,
        'customerType': _selectedCustomer!.customerType,
        'salesAgentID': _selectedCustomer!.salesAgentID,
        'salesAgent': _selectedCustomer!.salesAgent,
      },
      'salesAgent': _selectedSalesAgent == null ? null : {
        'salesAgentID': _selectedSalesAgent!.salesAgentID,
        'salesAgent': _selectedSalesAgent!.name,
        'description': _selectedSalesAgent!.description,
        'isDisabled': _selectedSalesAgent!.isDisabled,
      },
      'shippingMethod': _selectedShippingMethod == null ? null : {
        'shippingMethodID': _selectedShippingMethod!.shippingMethodID,
        'description': _selectedShippingMethod!.description,
        'isDisabled': _selectedShippingMethod!.isDisabled,
      },
      'lines': _lines.map((l) => {
        'stockID': l.stockID,
        'stockCode': l.stockCode,
        'uom': l.uom,
        'itemImage': l.itemImage,
        'description': l.descriptionCtrl.text,
        'qty': l.qtyCtrl.text,
        'unitPrice': l.unitPriceCtrl.text,
        'discount': l.discountCtrl.text,
        'taxTypeID': l.selectedTaxType?.taxTypeID,
        'taxTypeName': l.selectedTaxType?.taxCode,
        'taxRate': l.selectedTaxType?.taxRate,
      }).toList(),
    };
    await SessionManager.saveQuotationDraft(jsonEncode(draft));
  }

  void _restoreDraft(Map<String, dynamic> j) {
    _docDate = DateTime.tryParse(j['docDate'] as String? ?? '') ?? DateTime.now();
    _descriptionCtrl.text = j['description'] as String? ?? '';
    _remarkCtrl.text = j['remark'] as String? ?? '';
    _addr1 = j['addr1'] as String? ?? '';
    _addr2 = j['addr2'] as String? ?? '';
    _addr3 = j['addr3'] as String? ?? '';
    _addr4 = j['addr4'] as String? ?? '';
    _deliverAddr1 = j['deliverAddr1'] as String? ?? '';
    _deliverAddr2 = j['deliverAddr2'] as String? ?? '';
    _deliverAddr3 = j['deliverAddr3'] as String? ?? '';
    _deliverAddr4 = j['deliverAddr4'] as String? ?? '';
    _attention = j['attention'] as String? ?? '';
    _phone = j['phone'] as String? ?? '';
    _fax = j['fax'] as String? ?? '';
    _email = j['email'] as String? ?? '';

    final cj = j['customer'] as Map<String, dynamic>?;
    if (cj != null) _selectedCustomer = Customer.fromJson(cj);

    final aj = j['salesAgent'] as Map<String, dynamic>?;
    if (aj != null) _selectedSalesAgent = SalesAgent.fromJson(aj);

    final sj = j['shippingMethod'] as Map<String, dynamic>?;
    if (sj != null) _selectedShippingMethod = ShippingMethod.fromJson(sj);

    for (final lj in (j['lines'] as List<dynamic>? ?? [])) {
      final m = lj as Map<String, dynamic>;
      final line = _LineItem()
        ..stockID = (m['stockID'] as int?) ?? 0
        ..stockCode = (m['stockCode'] as String?) ?? ''
        ..uom = (m['uom'] as String?) ?? ''
        ..itemImage = m['itemImage'] as String?;
      line.descriptionCtrl.text = m['description'] as String? ?? '';
      line.qtyCtrl.text = m['qty'] as String? ?? '1';
      line.unitPriceCtrl.text = m['unitPrice'] as String? ?? '0';
      line.discountCtrl.text = m['discount'] as String? ?? '0';
      final taxTypeID = m['taxTypeID'] as int?;
      if (taxTypeID != null) {
        line.selectedTaxType =
            _taxTypes.where((t) => t.taxTypeID == taxTypeID).firstOrNull;
      }
      _lines.add(line);
    }
  }

  void _initFromDoc(QuotationDoc doc) {
    _editDocID = doc.docID;
    _editDocNo = doc.docNo;
    _docDate = DateTime.tryParse(doc.docDate) ?? DateTime.now();
    _descriptionCtrl.text = doc.description ?? '';
    _remarkCtrl.text = doc.remark ?? '';
    _addr1 = doc.address1 ?? '';
    _addr2 = doc.address2 ?? '';
    _addr3 = doc.address3 ?? '';
    _addr4 = doc.address4 ?? '';
    _deliverAddr1 = doc.deliverAddr1 ?? '';
    _deliverAddr2 = doc.deliverAddr2 ?? '';
    _deliverAddr3 = doc.deliverAddr3 ?? '';
    _deliverAddr4 = doc.deliverAddr4 ?? '';
    _attention = doc.attention ?? '';
    _phone = doc.phone ?? '';
    _fax = doc.fax ?? '';
    _email = doc.email ?? '';

    _selectedCustomer = Customer(
      customerID: doc.customerID,
      customerCode: doc.customerCode,
      name: doc.customerName,
      name2: '',
      address1: doc.address1,
      address2: doc.address2,
      address3: doc.address3,
      address4: doc.address4,
      deliverAddr1: doc.deliverAddr1,
      deliverAddr2: doc.deliverAddr2,
      deliverAddr3: doc.deliverAddr3,
      deliverAddr4: doc.deliverAddr4,
      attention: doc.attention,
      phone1: doc.phone,
      fax1: doc.fax,
      email: doc.email,
      priceCategory: 1,
      customerType: '',
      salesAgent: '',
    );

    if ((doc.salesAgent ?? '').isNotEmpty) {
      _selectedSalesAgent = SalesAgent(name: doc.salesAgent);
    }

    if (doc.shippingMethodID != null && doc.shippingMethodID! > 0) {
      _selectedShippingMethod = _shippingMethods
              .where((s) => s.shippingMethodID == doc.shippingMethodID)
              .firstOrNull ??
          ShippingMethod(
            shippingMethodID: doc.shippingMethodID!,
            description: doc.shippingMethodDescription ?? '',
          );
    }

    for (final detail in doc.quotationDetails) {
      final line = _LineItem()
        ..dtlID = detail.dtlID
        ..stockID = detail.stockID
        ..stockCode = detail.stockCode
        ..uom = detail.uom
        ..itemImage = detail.image;
      line.descriptionCtrl.text = detail.description;
      line.qtyCtrl.text = detail.qty.toString();
      line.unitPriceCtrl.text = detail.unitPrice.toString();
      line.discountCtrl.text = detail.discount.toString();
      if (detail.taxTypeID != null && detail.taxTypeID! > 0) {
        line.selectedTaxType =
            _taxTypes.where((t) => t.taxTypeID == detail.taxTypeID).firstOrNull;
      }
      if (detail.locationID != null && detail.locationID! > 0) {
        line.selectedLocation =
            _locations.where((l) => l.locationID == detail.locationID).firstOrNull;
      }
      _lines.add(line);
    }
  }

  Future<void> _checkAndRestoreDraft() async {
    if (_isEditMode) return;
    final raw = await SessionManager.getQuotationDraft();
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) setState(() => _restoreDraft(j));
    } catch (_) {
      await SessionManager.clearQuotationDraft();
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
    if (result == 'discard') await SessionManager.clearQuotationDraft();
    return true;
  }

  // ── Price category helpers ────────────────────────────────────────────
  int get _priceCategory => _selectedCustomer?.priceCategory ?? 1;

  double _priceForCategory(StockUOMDto uom, int cat) {
    switch (cat) {
      case 2: return uom.price2;
      case 3: return uom.price3;
      case 4: return uom.price4;
      case 5: return uom.price5;
      case 6: return uom.price6;
      default: return uom.price1;
    }
  }

  /// Fetches StockDetail and returns the price for [uomName] and current
  /// customer price category. Returns null if the call fails.
  Future<double?> _fetchUOMPrice(int stockID, String uomName) async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    try {
      final json = await BaseClient.post(
        ApiEndpoints.getStock,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'stockID': stockID,
        },
      );
      final detail = StockDetail.fromJson(json as Map<String, dynamic>);
      final uomDto =
          detail.stockUOMDtoList.where((u) => u.uom == uomName).firstOrNull;
      if (uomDto != null) return _priceForCategory(uomDto, _priceCategory);
    } catch (_) {}
    return null;
  }

  // ── Calculated totals ────────────────────────────────────────────────

  // Gross before discount (display only)
  double get _grossSubtotal =>
      _lines.fold(0, (s, l) => s + l.qty * l.unitPrice);
  double get _discountAmt =>
      _lines.fold(0, (s, l) => s + l.discountAmt);
  // After-discount subtotal — sent to API
  double get _subtotal => _lines.fold(0, (s, l) => s + l.lineTotal);
  double get _taxAmt => _lines.fold(0, (s, l) => s + l.lineTaxAmt);
  double get _finalTotal => _subtotal + (_isEnableTax ? _taxAmt : 0);

  // ── Save ─────────────────────────────────────────────────────────────

  Future<void> _save() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    if (_selectedCustomer == null) {
      _showError('Please select a customer.');
      return;
    }
    if (_lines.isEmpty) {
      _showError('Please add at least one item.');
      return;
    }
    for (int i = 0; i < _lines.length; i++) {
      final l = _lines[i];
      if (l.stockID == 0) {
        _showError('Item ${i + 1}: please select an item.');
        return;
      }
      if (l.qty <= 0) {
        _showError('Item ${i + 1}: quantity must be greater than 0.');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final c = _selectedCustomer!;
      final docID = _isEditMode ? _editDocID : 0;
      final docNo = _isEditMode ? _editDocNo : '';
      final details = _lines.map((l) {
        return {
          'dtlID': _isEditMode ? l.dtlID : 0,
          'docID': docID,
          'stockID': l.stockID,
          'stockCode': l.stockCode,
          'description': l.descriptionCtrl.text.trim(),
          'uom': l.uom,
          'qty': l.qty,
          'unitPrice': l.unitPrice,
          'discount': l.discount,
          'total': l.lineTotal,
          'taxTypeID': l.selectedTaxType?.taxTypeID,
          'taxCode': l.selectedTaxType?.taxCode,
          'taxableAmt': l.lineTaxableAmt,
          'taxRate': l.selectedTaxType?.taxRate ?? 0,
          'taxAmt': l.lineTaxAmt,
          'locationID': l.selectedLocation?.locationID ?? _defaultLocationID,
          'location': l.selectedLocation?.location ??
              _locations.where((loc) => loc.locationID == _defaultLocationID).firstOrNull?.location,
        };
      }).toList();

      await BaseClient.post(
        _isEditMode ? ApiEndpoints.updateQuotation : ApiEndpoints.createQuotation,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'quotationForm': {
            'docID': docID,
            'docNo': docNo,
            'docDate': _docDate.toIso8601String(),
            'customerID': c.customerID,
            'customerCode': c.customerCode,
            'customerName': c.name,
            'address1': _addr1,
            'address2': _addr2,
            'address3': _addr3,
            'address4': _addr4,
            'deliverAddr1': _deliverAddr1,
            'deliverAddr2': _deliverAddr2,
            'deliverAddr3': _deliverAddr3,
            'deliverAddr4': _deliverAddr4,
            'salesAgent': _selectedSalesAgent?.name ?? '',
            'phone': _phone,
            'fax': _fax,
            'email': _email,
            'attention': _attention,
            'subtotal': _subtotal,
            'taxableAmt': _lines.fold(0.0, (s, l) => s + l.lineTaxableAmt),
            'taxAmt': _taxAmt,
            'finalTotal': _finalTotal,
            'description': _descriptionCtrl.text.trim(),
            'remark': _remarkCtrl.text.trim(),
            'shippingMethodID': _selectedShippingMethod?.shippingMethodID,
            'shippingMethodDescription': _selectedShippingMethod?.description ?? '',
            'isVoid': false,
            'lastModifiedUserID': _userID,
            'lastModifiedDateTime': DateTime.now().toIso8601String(),
            'createdUserID': _userID,
            'createdDateTime': DateTime.now().toIso8601String(),
            'quotationDetails': details,
          },
        },
      );

      if (!_isEditMode) await SessionManager.clearQuotationDraft();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      _showError(e.toString());
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

  // ── Pickers ──────────────────────────────────────────────────────────

  Future<void> _pickCustomer() async {
    final picked = await Navigator.push<Customer>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerPickerPage(
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final oldCategory = _priceCategory;
    final newCategory = picked.priceCategory;

    setState(() {
      _selectedCustomer = picked;
      _addr1 = picked.address1 ?? '';
      _addr2 = picked.address2 ?? '';
      _addr3 = picked.address3 ?? '';
      _addr4 = picked.address4 ?? '';
      _deliverAddr1 = picked.deliverAddr1 ?? '';
      _deliverAddr2 = picked.deliverAddr2 ?? '';
      _deliverAddr3 = picked.deliverAddr3 ?? '';
      _deliverAddr4 = picked.deliverAddr4 ?? '';
      _attention = picked.attention ?? '';
      _phone = picked.phone1 ?? '';
      _fax = picked.fax1 ?? '';
      _email = picked.email ?? '';
    });

    // Prompt to reset prices only when category changed and items exist
    if (_lines.isNotEmpty && newCategory != oldCategory) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Update Item Prices?'),
          content: Text(
            '${picked.name} uses Price $newCategory. '
            'Do you want to update all ${_lines.length} item(s) to Price $newCategory?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Current'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Update'),
            ),
          ],
        ),
      );
      if (confirm == true && mounted) {
        await _resetLinePrices();
      }
    }
  }

  Future<void> _resetLinePrices() async {
    setState(() => _isUpdatingPrices = true);
    try {
      await Future.wait(_lines.map((line) async {
        if (line.stockID == 0) return;
        final price = await _fetchUOMPrice(line.stockID, line.uom);
        if (price != null && mounted) line.unitPriceCtrl.text = price.toString();
      }));
    } finally {
      if (mounted) setState(() => _isUpdatingPrices = false);
    }
  }

  Future<void> _editCustomerInfo() async {
    if (_selectedCustomer == null) return;
    final a1 = TextEditingController(text: _addr1);
    final a2 = TextEditingController(text: _addr2);
    final a3 = TextEditingController(text: _addr3);
    final a4 = TextEditingController(text: _addr4);
    final d1 = TextEditingController(text: _deliverAddr1);
    final d2 = TextEditingController(text: _deliverAddr2);
    final d3 = TextEditingController(text: _deliverAddr3);
    final d4 = TextEditingController(text: _deliverAddr4);
    final att = TextEditingController(text: _attention);
    final ph = TextEditingController(text: _phone);
    final fx = TextEditingController(text: _fax);
    final em = TextEditingController(text: _email);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, sc) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Edit Customer Info',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save_rounded),
                      tooltip: 'Save',
                      onPressed: () {
                        setState(() {
                          _addr1 = a1.text.trim();
                          _addr2 = a2.text.trim();
                          _addr3 = a3.text.trim();
                          _addr4 = a4.text.trim();
                          _deliverAddr1 = d1.text.trim();
                          _deliverAddr2 = d2.text.trim();
                          _deliverAddr3 = d3.text.trim();
                          _deliverAddr4 = d4.text.trim();
                          _attention = att.text.trim();
                          _phone = ph.text.trim();
                          _fax = fx.text.trim();
                          _email = em.text.trim();
                        });
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SheetSection(label: 'Billing Address'),
                    _SheetField(ctrl: a1, hint: 'Address line 1'),
                    _SheetField(ctrl: a2, hint: 'Address line 2'),
                    _SheetField(ctrl: a3, hint: 'Address line 3'),
                    _SheetField(ctrl: a4, hint: 'Address line 4'),
                    const SizedBox(height: 16),
                    _SheetSection(label: 'Delivery Address'),
                    _SheetField(ctrl: d1, hint: 'Address line 1'),
                    _SheetField(ctrl: d2, hint: 'Address line 2'),
                    _SheetField(ctrl: d3, hint: 'Address line 3'),
                    _SheetField(ctrl: d4, hint: 'Address line 4'),
                    const SizedBox(height: 16),
                    _SheetSection(label: 'Contact'),
                    _SheetField(ctrl: att, hint: 'Attention'),
                    _SheetField(ctrl: ph, hint: 'Phone', inputType: TextInputType.phone),
                    _SheetField(ctrl: fx, hint: 'Fax', inputType: TextInputType.phone),
                    _SheetField(ctrl: em, hint: 'Email', inputType: TextInputType.emailAddress),
                  ],
                ),
              ),
              SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );

    for (final c in [a1, a2, a3, a4, d1, d2, d3, d4, att, ph, fx, em]) {
      c.dispose();
    }
  }

  Future<void> _pickSalesAgent() async {
    final picked = await Navigator.push<SalesAgent>(
      context,
      MaterialPageRoute(
        builder: (_) => SalesAgentPickerPage(
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (picked != null) setState(() => _selectedSalesAgent = picked);
  }

  Future<void> _pickShippingMethod() async {
    if (_shippingMethods.isEmpty) return;
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
                      _selectedShippingMethod?.shippingMethodID == s.shippingMethodID;
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
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (picked != null && mounted) {
      final price =
          await _fetchUOMPrice(picked.stockID, picked.baseUOM) ??
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
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (picked != null && mounted) {
      final price =
          await _fetchUOMPrice(picked.stockID, picked.baseUOM) ??
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
            await _fetchUOMPrice(found.stockID, found.baseUOM) ??
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canPop = await _onWillPop();
        if (canPop && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onDoubleTap: () => _formScrollCtrl.animateTo(
            0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          ),
          child: Text(_isEditMode ? 'Edit Quotation' : 'New Quotation',
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
                        // ── Document ──────────────────────────────────
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
                                    _FieldLabel(label: 'Date'),
                                    InkWell(
                                      onTap: _pickDate,
                                      borderRadius: BorderRadius.circular(12),
                                      child: _FieldBox(
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
                                    // ── Customer ────────────────────────
                                    _FieldLabel(label: 'Customer *'),
                                    _FieldBox(
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person_outline, size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: InkWell(
                                              onTap: _pickCustomer,
                                              child: _selectedCustomer == null
                                                  ? Text(
                                                      'Select customer',
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurface
                                                              .withValues(alpha: 0.4)),
                                                    )
                                                  : Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(_selectedCustomer!.customerCode,
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .primary)),
                                                        Text(_selectedCustomer!.name,
                                                            style: const TextStyle(
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w600)),
                                                        
                                                      ],
                                                    ),
                                            ),
                                          ),
                                          if (_selectedCustomer != null)
                                            IconButton(
                                              icon: Icon(Icons.edit_outlined,
                                                  size: 18,
                                                  color: Theme.of(context).colorScheme.primary),
                                              tooltip: 'Edit info for this quotation',
                                              onPressed: _editCustomerInfo,
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            )
                                          else
                                            Icon(Icons.chevron_right,
                                                size: 18,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.3)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // ── Sales Agent ──────────────────────
                                    _FieldLabel(label: 'Sales Agent'),
                                    InkWell(
                                      onTap: _pickSalesAgent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: _FieldBox(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.badge_outlined, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _selectedSalesAgent == null
                                                  ? Text(
                                                      'Select sales agent',
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurface
                                                              .withValues(alpha: 0.4)),
                                                    )
                                                  : Text(
                                                      _selectedSalesAgent!.name ?? '',
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600),
                                                    ),
                                            ),
                                            if (_selectedSalesAgent != null)
                                              GestureDetector(
                                                onTap: () => setState(() => _selectedSalesAgent = null),
                                                child: Icon(Icons.clear,
                                                    size: 16,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.4)),
                                              )
                                            else
                                              Icon(Icons.chevron_right,
                                                  size: 18,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.3)),
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
                                    _FieldLabel(label: 'Description'),
                                    TextFormField(
                                      controller: _descriptionCtrl,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: _inputDeco(''),
                                    ),
                                    const SizedBox(height: 12),
                                    _FieldLabel(label: 'Remark'),
                                    TextFormField(
                                      controller: _remarkCtrl,
                                      maxLines: 1,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: _inputDeco(''),
                                    ),
                                    const SizedBox(height: 12),
                                    // ── Shipping Method ─────────────────
                                    _FieldLabel(label: 'Shipping Method'),
                                    InkWell(
                                      onTap: _pickShippingMethod,
                                      borderRadius: BorderRadius.circular(12),
                                      child: _FieldBox(
                                        child: Row(
                                          children: [
                                            const Icon(Icons.local_shipping_outlined, size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _selectedShippingMethod == null
                                                  ? Text(
                                                      'Select shipping method',
                                                      style: TextStyle(
                                                          fontSize: 14,
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .onSurface
                                                              .withValues(alpha: 0.4)),
                                                    )
                                                  : Text(
                                                      _selectedShippingMethod!.description,
                                                      style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600),
                                                    ),
                                            ),
                                            if (_selectedShippingMethod != null)
                                              GestureDetector(
                                                onTap: () => setState(() => _selectedShippingMethod = null),
                                                child: Icon(Icons.clear,
                                                    size: 16,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.4)),
                                              )
                                            else
                                              Icon(Icons.chevron_right,
                                                  size: 18,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withValues(alpha: 0.3)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),

                        // ── Items ─────────────────────────────────────
                        _sectionHeader(Icons.list_alt_outlined, 'Items',
                            expanded: _itemsExpanded,
                            onToggle: () => setState(() => _itemsExpanded = !_itemsExpanded),
                            badge: '${_lines.length}'),
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
                if (_lines.isNotEmpty) _buildTotalsFooter(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: Text(
                          _isEditMode ? 'Update Quotation' : 'Create Quotation',
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
          if (_isUpdatingPrices)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DotsLoading(),
                    SizedBox(height: 12),
                    Text('Updating prices…',
                        style: TextStyle(color: Colors.white, fontSize: 13)),
                  ],
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildTotalsFooter() {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;

    Widget row(String label, String value, {Color? labelColor, Color? valueColor, bool bold = false}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: labelColor ?? cs.onSurface.withValues(alpha: 0.55))),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: valueColor ?? cs.onSurface)),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _footerExpanded = !_footerExpanded),
      child: Container(
        color: cs.surfaceContainerLow,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Expanded detail rows
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: _footerExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                          'TOTAL SUMMARY',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                              color: primary),
                        ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        row('Subtotal',
                            _amtFmt.format(_grossSubtotal),
                            valueColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
                        row('Discount',
                              '- ${_amtFmt.format(_discountAmt)}',
                              labelColor: _discountAmt == 0 ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55) : Mycolor.discountTextColor,
                              valueColor: _discountAmt == 0 ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55) : Mycolor.discountTextColor),
                        if (_isEnableTax) row(
                          'Tax', 
                          '+ ${_amtFmt.format(_taxAmt)}', 
                          labelColor: _taxAmt == 0 ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55) : Mycolor.taxTextColor,
                          valueColor: _taxAmt == 0 ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55) : Mycolor.taxTextColor),
                        Divider(
                            height: 12,
                            color: cs.outline.withValues(alpha: 0.2)),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
            // Always-visible total row
            Row(
              children: [
                Text(
                  'Total',
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.55)),
                ),
                const Spacer(),
                Text(
                  _amtFmt.format(_finalTotal),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: primary),
                ),
                const SizedBox(width: 4),
                Icon(
                  _footerExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
                child:
                    Divider(color: primary.withValues(alpha: 0.2), thickness: 1)),
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
      labelText: label,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
      ),
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
                    ? _uomChip(_uom, true, primary, cs, null)
                    : SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 4),
                          itemCount: _uomList.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            final u = _uomList[i];
                            return _uomChip(u.uom, _uom == u.uom, primary, cs,
                                () => _onUOMSelected(u));
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
                _stepBtn(Icons.remove_rounded, () => _stepQty(-1), primary, cs),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    decoration: _fieldDeco(null, cs, primary),
                    onEditingComplete: _clampQty,
                    onTapOutside: (_) => _clampQty(),
                  ),
                ),
                const SizedBox(width: 10),
                _stepBtn(Icons.add_rounded, () => _stepQty(1), primary, cs),
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
                        decoration: _fieldDeco(null, cs, primary),
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
                        decoration: _fieldDeco(null, cs, primary).copyWith(
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
                decoration: _fieldDeco(null, cs, primary),
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
                  _summaryRow(
                    'Subtotal', 
                    _amtFmt.format(_subtotal), 
                    cs),

                  const SizedBox(height: 6),
                    _summaryRow(
                      _discAmt == 0 ? 'Discount' : 'Discount (${_discCtrl.text})',
                      '- ${_amtFmt.format(_discAmt)}',
                      cs,
                      labelColor: _discAmt == 0 ? cs.onSurface.withValues(alpha: 0.6) : Mycolor.discountTextColor,
                      valueColor: _discAmt == 0 ? cs.onSurface.withValues(alpha: 0.6) : Mycolor.discountTextColor),
                  
                  if (widget.enableTax) ...[
                    const SizedBox(height: 6),
                    _summaryRow(
                      'Tax',
                      '+ ${_amtFmt.format(_taxAmt)}', 
                      cs,
                      labelColor: _taxType?.taxCode == null ? cs.onSurface.withValues(alpha: 0.6) : Mycolor.taxTextColor,
                      valueColor: _taxType?.taxCode == null ? cs.onSurface.withValues(alpha: 0.6) : Mycolor.taxTextColor),
                  ],
                  Divider(height: 16, color: primary.withValues(alpha: 0.15)),
                  _summaryRow(
                    'Total', 
                    _amtFmt.format(_lineTotal + (widget.enableTax ? _taxAmt : 0)), 
                    cs,
                    bold: true, 
                    labelColor: primary,
                    valueColor: primary),
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

  Widget _uomChip(String label, bool selected, Color primary, ColorScheme cs, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary : primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? primary : primary.withValues(alpha: 0.2)),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : primary,
            )),
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap, Color primary, ColorScheme cs) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: primary),
      ),
    );
  }

  Widget _summaryRow(String label, String value, ColorScheme cs,
      {Color? labelColor, Color? valueColor, bool bold = false}) {
    return Row(
      children: [
        Text(label, 
          style: TextStyle(
            fontSize: 12, 
            color: labelColor ?? cs.onSurface.withValues(alpha: 0.55))),
        const Spacer(),
        Text(value, style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: valueColor ?? cs.onSurface.withValues(alpha: 0.6),
        )),
      ],
    );
  }

  InputDecoration _fieldDeco(String? label, ColorScheme cs, Color primary) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12),
      filled: true,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────
// Helpers
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

class _SheetSection extends StatelessWidget {
  final String label;
  const _SheetSection({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType inputType;
  const _SheetField({
    required this.ctrl,
    required this.hint,
    this.inputType = TextInputType.text,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl,
            keyboardType: inputType,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
