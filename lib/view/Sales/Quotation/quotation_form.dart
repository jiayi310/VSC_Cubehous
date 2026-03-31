import 'dart:convert';
import 'package:cubehous/common/my_color.dart';
import 'package:cubehous/common/stock_common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';
import '../../../models/customer.dart';
import '../../../models/location.dart';
import '../../../models/tax_type.dart';
import '../../../models/sales_agent.dart';
import '../../../models/shipping_method.dart';
import '../../../models/stock.dart';
import '../../../models/stock_detail.dart';
import '../../../models/quotation.dart';
import '../../Common/customer_picker_page.dart';
import '../../Common/decoration.dart';
import '../../Common/sales_agent_picker_page.dart';
import '../../Common/Stock/item_picker_page.dart';

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
  String _attention = '', _phone = '', _fax = '', _email = '', _name = '';

  // Line items
  final List<_LineItemQuotation> _lines = [];

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
  late NumberFormat _amtFmt;
  late NumberFormat _qtyFmt;
  late String _currency = '';

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
      SessionManager.getSalesDecimalPoint(),
      SessionManager.getQuantityDecimalPoint(),
      SessionManager.getCurrencySymbol(),
    ]);
    if (mounted) {
      setState(() {
        _showImage = (results[0] as String) == 'show';
        _isEnableTax = results[1] as bool;
        _defaultLocationID = results[2] as int;
        final dp = results[3] as int;
        _amtFmt = NumberFormat('#,##0.${'0' * dp}');
        final dp2 = results[4] as int;
        _qtyFmt = NumberFormat('#,##0.${'0' * dp2}');
        _currency = results[5] as String;
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
      'name': _name, 'attention': _attention, 'phone': _phone, 'fax': _fax, 'email': _email,
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
    _name = j['name'] as String? ?? '';
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
      final line = _LineItemQuotation()
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
    _name = doc.customerName;
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
      final line = _LineItemQuotation()
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
          'taxCode': l.selectedTaxType?.taxCode ?? '',
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
            'customerName': _name,
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
      _name = picked.name;
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
        final price = await StockCommon.fetchUOMPrice(line.stockID, line.uom, _priceCategory);
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
    final na = TextEditingController(text: _name);
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
      builder: (ctx) => Padding(
        padding: MediaQuery.viewInsetsOf(ctx),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                          _name = na.text.trim();
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SheetSection(label: 'Billing Address'),
                      SheetField(ctrl: a1, hint: 'Address line 1'),
                      SheetField(ctrl: a2, hint: 'Address line 2'),
                      SheetField(ctrl: a3, hint: 'Address line 3'),
                      SheetField(ctrl: a4, hint: 'Address line 4'),
                      const SizedBox(height: 16),
                      SheetSection(label: 'Delivery Address'),
                      SheetField(ctrl: d1, hint: 'Address line 1'),
                      SheetField(ctrl: d2, hint: 'Address line 2'),
                      SheetField(ctrl: d3, hint: 'Address line 3'),
                      SheetField(ctrl: d4, hint: 'Address line 4'),
                      const SizedBox(height: 16),
                      SheetSection(label: 'Contact'),
                      SheetField(ctrl: na, hint: 'Name'),
                      SheetField(ctrl: att, hint: 'Attention'),
                      SheetField(ctrl: em, hint: 'Email', inputType: TextInputType.emailAddress),
                      SheetField(ctrl: ph, hint: 'Phone', inputType: TextInputType.phone),
                      SheetField(ctrl: fx, hint: 'Fax', inputType: TextInputType.phone),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

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
          module: "QUOTATION",
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
          module: "QUOTATION",
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
      final line = _LineItemQuotation();
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
          final _LineItemQuotation line;
          if (emptyIndex >= 0) {
            line = _lines[emptyIndex];
          } else {
            line = _LineItemQuotation();
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
                        FormSectionHeader(
                            icon: Icons.receipt_long_outlined,
                            title: 'Document',
                            expanded: _docExpanded,
                            onToggle: () => setState(() => _docExpanded = !_docExpanded)),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          child: _docExpanded
                              ? Column(
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
                                                style: const TextStyle(fontSize: 14)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // ── Customer ────────────────────────
                                    FieldLabel(label: 'Customer *'),
                                    FieldBox(
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
                                                                fontWeight: FontWeight.w800)),
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
                                    FieldLabel(label: 'Sales Agent'),
                                    InkWell(
                                      onTap: _pickSalesAgent,
                                      borderRadius: BorderRadius.circular(12),
                                      child: FieldBox(
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
                                                          fontWeight: FontWeight.w600,
                                                          ),
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
                                    const SizedBox(height: 12),
                                    // ── Shipping Method ─────────────────
                                    FieldLabel(label: 'Shipping Method'),
                                    InkWell(
                                      onTap: _pickShippingMethod,
                                      borderRadius: BorderRadius.circular(12),
                                      child: FieldBox(
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
                        FormSectionHeader(
                            icon: Icons.list_alt_outlined,
                            title: 'Items',
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
                                        children: _lines.asMap().entries.map((e) => _LineItemCardQuotation(
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
                _buildTotalsFooter(),
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
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: () => setState(() => _footerExpanded = !_footerExpanded),
      child: Container(
        color: cs.surfaceContainerLow,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
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
                        const SizedBox(height: 10),
                        FormTotalPriceSummaryRow(
                          label: 'Subtotal', 
                          value: _amtFmt.format(_grossSubtotal),
                          muted: muted),
                        FormTotalPriceSummaryRow(
                            label: 'Discount', 
                            value: '- ${_amtFmt.format(_discountAmt)}',
                            muted: muted,
                            valueColor: _discountAmt == 0 ? muted : Mycolor.discountTextColor),
                        
                        if (_isEnableTax) 
                          FormTotalPriceSummaryRow(
                            label: 'Tax', 
                            value: '+ ${_amtFmt.format(_taxAmt)}',
                            muted: muted,
                            valueColor: _discountAmt == 0 ? muted : Mycolor.taxTextColor),
                        
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
                  '$_currency ${_amtFmt.format(_finalTotal)}',
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
}

// ─────────────────────────────────────────────────────────────────────
// Line item model
// ─────────────────────────────────────────────────────────────────────

class _LineItemQuotation {
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
  //   - Number without "%" → fixed amount (e.g. "0.5" = 0.50 off)
  //   - Number with "%" → percentage of remaining subtotal (e.g. "10%" = 10% off)
  //   - Combined with "+" → applied sequentially on remaining amount
  static double _parseDiscountAmt(String text, double subtotal) {
    final t = text.trim();
    if (t.isEmpty || t == '0') return 0;
    if (!t.contains('+') && !t.contains('%')) {
      return double.tryParse(t) ?? 0;
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

class _LineItemCardQuotation extends StatefulWidget {
  final int index;
  final _LineItemQuotation item;
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

  const _LineItemCardQuotation({
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
  State<_LineItemCardQuotation> createState() => _LineItemCardQuotationState();
}

class _LineItemCardQuotationState extends State<_LineItemCardQuotation> {
  bool _expanded = false;
  double? _pointerDownX;
  double? _pointerDownY;
  late final VoidCallback _rebuildListener;

  @override
  void initState() {
    super.initState();
    _rebuildListener = () { if (mounted) setState(() {}); };
    for (final ctrl in [
      widget.item.qtyCtrl,
      widget.item.unitPriceCtrl,
      widget.item.discountCtrl,
      widget.item.descriptionCtrl,
    ]) {
      ctrl.addListener(_rebuildListener);
    }
  }

  @override
  void dispose() {
    for (final ctrl in [
      widget.item.qtyCtrl,
      widget.item.unitPriceCtrl,
      widget.item.discountCtrl,
      widget.item.descriptionCtrl,
    ]) {
      ctrl.removeListener(_rebuildListener);
    }
    super.dispose();
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
        amtFmt: widget.amtFmt,
        qtyFmt: widget.qtyFmt,
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final item = widget.item;
    final salesFmt = widget.amtFmt;
    final qtyFmt = widget.qtyFmt;

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
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

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
                            fontSize: 10,
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
                            fontSize: 10,
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                                'x ${qtyFmt.format(item.qty)}',
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
                            if (item.discountAmt != 0) ...[
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
                              salesFmt.format(item.lineTotal + item.lineTaxAmt),
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
                          ItemBreakdownRow(
                            label: 'Unit Price',
                            value: salesFmt.format(item.unitPrice),
                            muted: muted),
                          const SizedBox(height: 3),
                          ItemBreakdownRow(
                            label: 'Subtotal', 
                            value: salesFmt.format(item.qty * item.unitPrice),
                            muted: muted),
                          const SizedBox(height: 3),
                          ItemBreakdownRow(
                            label: 'Discount', 
                            value: '- ${salesFmt.format(discAmt)}', 
                            muted: muted,
                            valueColor: discAmt == 0 ? muted : Mycolor.discountTextColor),
                        
                          if (widget.enableTax) ...[
                            const SizedBox(height: 3),
                            ItemBreakdownRow(
                            label: 'Tax (${item.selectedTaxType?.taxRate ?? ''}%) ',
                            value: '+ ${salesFmt.format(item.lineTaxAmt)}',
                            muted: muted,
                            valueColor: item.lineTaxAmt == 0 ? muted : Mycolor.taxTextColor),
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


}

// ─────────────────────────────────────────────────────────────────────
// Line item edit sheet
// ─────────────────────────────────────────────────────────────────────

class _LineItemEditSheet extends StatefulWidget {
  final _LineItemQuotation item;
  final List<TaxType> taxTypes;
  final bool enableTax;
  final int priceCategory;
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;
  final VoidCallback onChanged;
  final NumberFormat amtFmt;
  final NumberFormat qtyFmt;

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
    required this.amtFmt,
    required this.qtyFmt
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
  int _salesDp = 2;

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
    final qtyDp = results[0] as int;
    final salesDp = results[1] as int;
    final qty = double.tryParse(_qtyCtrl.text) ?? 1.0;
    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
    setState(() {
      _qtyDp = qtyDp;
      _salesDp = salesDp;
      _loadingUOM = false;
      _qtyCtrl.text = StockCommon.formatDP(qty, qtyDp);
      _priceCtrl.text = StockCommon.formatDP(price, salesDp);
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
  double get _discAmt => _LineItemQuotation._parseDiscountAmt(_discCtrl.text, _subtotal);
  double get _lineTotal => _subtotal - _discAmt;
  double get _taxAmt {
    final rate = _taxType?.taxRate ?? 0;
    if (rate == 0) return 0;
    return _lineTotal * (rate / 100);
  }

  // ── Qty helpers ──────────────────────────────────────────────────────
  void _clampQty() {
    final v = double.tryParse(_qtyCtrl.text) ?? 0;
    if (v < 1) _qtyCtrl.text = StockCommon.formatDP(1.0, _qtyDp);
  }

  void _stepQty(int delta) {
    final current = double.tryParse(_qtyCtrl.text) ?? 1;
    final next = (current + delta).clamp(1.0, double.infinity);
    _qtyCtrl.text = StockCommon.formatDP(next, _qtyDp);
  }

  void _onUOMSelected(StockUOMDto uom) {
    setState(() {
      _uom = uom.uom;
      _priceCtrl.text = StockCommon.formatDP(StockCommon.priceForCategory(uom, widget.priceCategory), _salesDp);
    });
  }

  void _pickTaxType(BuildContext context) {
    final options = <TaxType?>[null, ...widget.taxTypes];
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        minChildSize: 0.8,
        maxChildSize: 0.8,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Tax Code',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: sc,
                itemCount: options.length,
                itemBuilder: (_, i) {
                  final t = options[i];
                  final label = t == null
                      ? 'No Tax'
                      : '${t.taxCode} (${t.taxRate?.toStringAsFixed(0)}%)';
                  final selected = t?.taxTypeID == _taxType?.taxTypeID;
                  return ListTile(
                    title: Text(label),
                    trailing: selected
                        ? const Icon(Icons.check, color: Color(0xFF153D81))
                        : null,
                    onTap: () {
                      setState(() => _taxType = t);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
            // Item title: StockCode, Desc
            Text(
              widget.item.stockCode,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primary)
            ),
            Text(
              widget.item.descriptionCtrl.text,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.5)
                ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis
            ),
            
            const SizedBox(height: 25),

            // ── UOM selector ────────────────────────────────────────────
            Text(
              'UOM', 
              style: TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.5)
              )
            ),
            const SizedBox(height: 8),
            _loadingUOM
                ? const SizedBox(height: 44, child: Center(child: DotsLoading()))
                : _uomList.isEmpty
                    ? uomChip(context, _uom, selected: true)
                    : SizedBox(
                        height: 35,
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
            const SizedBox(height: 18),

            // ── Qty stepper ──────────────────────────────────────────────
            Text(
              'Quantity', 
              style: TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.5)
              )
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                stepBtn(context, Icons.remove_rounded, () => _stepQty(-1)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))], // ignore: deprecated_member_use
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
            const SizedBox(height: 18),

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
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))], // ignore: deprecated_member_use
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
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.+%]'))], // ignore: deprecated_member_use
                        style: const TextStyle(fontSize: 14),
                        decoration: sheetInputDeco(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // ── Tax ──────────────────────────────────────────────────────
            if (widget.enableTax) ...[
              Text(
                'Tax Code', 
                style: TextStyle(
                  fontSize: 11, 
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.5)
                )
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _pickTaxType(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _taxType == null
                              ? 'No Tax'
                              : '${_taxType!.taxCode} (${_taxType!.taxRate?.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 13,
                            color: _taxType == null
                                ? cs.onSurface.withValues(alpha: 0.4)
                                : cs.onSurface,
                          ),
                        ),
                      ),
                      Icon(Icons.expand_more_rounded,
                          size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),
            // ── Summary ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(10),
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
                  FormTotalPriceSummaryRow(
                    label: 'Discount',
                    value: '- ${StockCommon.formatDP(_discAmt, _salesDp)}',
                    muted: muted,
                    valueColor: _discAmt == 0 ? muted : Mycolor.discountTextColor),
                        
                  if (widget.enableTax) ...[
                    FormTotalPriceSummaryRow(
                      label: 'Tax', 
                      value: '+ ${StockCommon.formatDP(_taxAmt, _salesDp)}',
                      muted: muted,
                      valueColor: _taxAmt == 0 ? muted : Mycolor.taxTextColor),
                        
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
            const SizedBox(height: 10),

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
