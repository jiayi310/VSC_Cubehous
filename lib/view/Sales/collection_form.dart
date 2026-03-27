import 'dart:convert';
import 'dart:io';
import 'package:cubehous/common/my_color.dart';
import 'package:cubehous/models/sales_agent.dart';
import 'package:cubehous/view/Common/customer_picker_page.dart';
import 'package:cubehous/view/Common/decoration.dart';
import 'package:cubehous/view/Common/sales_agent_picker_page.dart';
import 'package:cubehous/view/Sales/collection_form_sales_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../common/session_manager.dart';
import '../../models/collection.dart';
import '../../models/sales.dart';
import '../../models/customer.dart';

// ─────────────────────────────────────────────────────────────────────
// Helper class for selected sales order with editable payment amount
// ─────────────────────────────────────────────────────────────────────

class _SelectedOrder {
  final SalesListItem sale;
  final TextEditingController paymentAmtCtrl;
  final int collectMappingID;

  _SelectedOrder(this.sale)
      : paymentAmtCtrl =
            TextEditingController(text: sale.outstanding.toStringAsFixed(2)),
        collectMappingID = 0;

  _SelectedOrder.fromMapping(
    this.sale, {
    required double paymentAmt,
    required this.collectMappingID,
  }) : paymentAmtCtrl =
            TextEditingController(text: paymentAmt.toStringAsFixed(2));

  void dispose() => paymentAmtCtrl.dispose();

  double get paymentAmt => double.tryParse(paymentAmtCtrl.text) ?? 0;
}

// ─────────────────────────────────────────────────────────────────────
// Collection Form Page
// ─────────────────────────────────────────────────────────────────────

class CollectionFormPage extends StatefulWidget {
  final CollectionDoc? initialDoc;
  const CollectionFormPage({super.key, this.initialDoc});

  @override
  State<CollectionFormPage> createState() => _CollectionFormPageState();
}

class _CollectionFormPageState extends State<CollectionFormPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  bool get _isEditMode => widget.initialDoc != null;
  int _editDocID = 0;
  String _editDocNo = '';
  final _formScrollCtrl = ScrollController();

  // Header state
  DateTime _docDate = DateTime.now();
  Customer? _selectedCustomer;
  SalesAgent? _selectedSalesAgent;
  final _salesAgentCtrl = TextEditingController();
  final _refNoCtrl = TextEditingController();
  final _paymentTotalCtrl = TextEditingController(text: '0');

  // Payment fields
  String? _selectedPaymentType;
  List<PaymentTypeItem> _paymentTypes = [];
  bool _loadingPaymentTypes = true;
  bool _paymentTypesError = false;
  bool _loadingDropdowns = true;
 
  // Selected orders
  final List<_SelectedOrder> _selectedOrders = [];

  // Photo
  String? _imageBase64;

  // UI state
  bool _footerExpanded = false;
  bool _docExpanded = true;
  bool _paymentExpanded = true;
  bool _ordersExpanded = true;
  bool _attachmentExpanded = true;
  bool _isSaving = false;

  late DateFormat _dateFmt;
  late NumberFormat _amtFmt;
  late String _currency = '';

  // ── Computed getters ────────────────────────────────────────────────

  double get _totalOutstanding {
    final salesOutstanding = _selectedOrders.fold(0.0, (s, o) => s + o.sale.outstanding);
    final paymentTotal = double.tryParse(_paymentTotalCtrl.text) ?? 0.0;
    return salesOutstanding - paymentTotal;
  }


  // ── Lifecycle ───────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _paymentTotalCtrl.addListener(_distributePayment);
    _init();
  }

  @override
  void dispose() {
    _formScrollCtrl.dispose();
    _salesAgentCtrl.dispose();
    _refNoCtrl.dispose();
    _paymentTotalCtrl.dispose();
    for (final o in _selectedOrders) {
      o.dispose();
    }
    super.dispose();
  }

  Future<void> _init() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    final results = await Future.wait([
      SessionManager.getSalesDecimalPoint(),
      SessionManager.getDateFormat(),
      SessionManager.getCurrencySymbol(),
    ]);
    if (mounted) {
      setState(() {
        final dp = results[0] as int;
        _amtFmt = NumberFormat('#,##0.${'0' * dp}');
        final de = results[1] as String;
        _dateFmt = DateFormat(de);
        _currency = results[2] as String;
      });
    }
    
    try {
      final result = await BaseClient.post(
        ApiEndpoints.getPaymentTypeList,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID
        },
      );
      final raw = result as List<dynamic>;
      final list = raw.map((e) {
        if (e is String) return PaymentTypeItem(paymentType: e);
        if (e is Map<String, dynamic>) return PaymentTypeItem.fromJson(e);
        return PaymentTypeItem(paymentType: e.toString());
      }).where((pt) => pt.paymentType.isNotEmpty).toList();
      if (mounted) {
        setState(() {
          _paymentTypes = list;
          _loadingPaymentTypes = false;
          _loadingDropdowns = false;
        });
      }

      await _checkAndRestoreDraft();
      if (_isEditMode && widget.initialDoc != null) {
        if (mounted) setState(() => _initFromDoc(widget.initialDoc!));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPaymentTypes = false;
          _paymentTypesError = true;
          _loadingDropdowns = false;
        });
      }
    }
  }

  bool get _isEdit => widget.initialDoc != null;

// ── Draft helpers ─────────────────────────────────────────────────────
  bool get _hasChanges =>
      _selectedCustomer != null ||
      _selectedOrders.isNotEmpty ||
      _refNoCtrl.text.isNotEmpty ||
      _paymentTotalCtrl.text.isNotEmpty ||
      _selectedSalesAgent != null ;

  Future<void> _saveDraft() async {
    final draft = {
      'docDate': _docDate.toIso8601String(),
      'refNo': _refNoCtrl.text,
      'paymentType': _selectedPaymentType,
      'paymentTotal': _paymentTotalCtrl.text,
      'imageBase64': _imageBase64,
      'customer': _selectedCustomer == null ? null : {
        'customerID': _selectedCustomer!.customerID,
        'customerCode': _selectedCustomer!.customerCode,
        'name': _selectedCustomer!.name,
        'name2': _selectedCustomer!.name2,
        'address1': _selectedCustomer!.address1,
        'address2': _selectedCustomer!.address2,
        'address3': _selectedCustomer!.address3,
        'address4': _selectedCustomer!.address4,
        'priceCategory': _selectedCustomer!.priceCategory,
        'customerType': _selectedCustomer!.customerType,
        'salesAgent': _selectedCustomer!.salesAgent,
      },
      'salesAgent': _selectedSalesAgent == null ? null : {
        'salesAgentID': _selectedSalesAgent!.salesAgentID,
        'name': _selectedSalesAgent!.name,
        'description': _selectedSalesAgent!.description,
        'isDisabled': _selectedSalesAgent!.isDisabled,
      },
      'orders': _selectedOrders.map((o) => {
        'docID': o.sale.docID,
        'docNo': o.sale.docNo,
        'docDate': o.sale.docDate,
        'customerID': o.sale.customerID,
        'customerCode': o.sale.customerCode,
        'customerName': o.sale.customerName,
        'salesAgent': o.sale.salesAgent,
        'subtotal': o.sale.subtotal,
        'taxAmt': o.sale.taxAmt,
        'finalTotal': o.sale.finalTotal,
        'paymentTotal': o.sale.paymentTotal,
        'outstanding': o.sale.outstanding,
        'paymentAmt': o.paymentAmtCtrl.text,
        'collectMappingID': o.collectMappingID,
      }).toList(),
    };
    await SessionManager.saveCollectionDraft(jsonEncode(draft));
  }

  void _restoreDraft(Map<String, dynamic> j) {
    _docDate = DateTime.tryParse(j['docDate'] as String? ?? '') ?? DateTime.now();
    _refNoCtrl.text = j['refNo'] as String? ?? '';
    _selectedPaymentType = j['paymentType'] as String?;
    _imageBase64 = j['imageBase64'] as String?;

    final cj = j['customer'] as Map<String, dynamic>?;
    if (cj != null) _selectedCustomer = Customer.fromJson(cj);

    final aj = j['salesAgent'] as Map<String, dynamic>?;
    if (aj != null) {
      _selectedSalesAgent = SalesAgent(
        salesAgentID: (aj['salesAgentID'] as int?) ?? 0,
        name: (aj['name'] as String?) ?? '',
        description: aj['description'] as String?,
        isDisabled: (aj['isDisabled'] as bool?) ?? false,
      );
      _salesAgentCtrl.text = _selectedSalesAgent!.name ?? '';
    }

    for (final oj in (j['orders'] as List<dynamic>? ?? [])) {
      final m = oj as Map<String, dynamic>;
      final sale = SalesListItem(
        docID: (m['docID'] as int?) ?? 0,
        docNo: (m['docNo'] as String?) ?? '',
        docDate: (m['docDate'] as String?) ?? '',
        customerID: (m['customerID'] as int?) ?? 0,
        customerCode: (m['customerCode'] as String?) ?? '',
        customerName: (m['customerName'] as String?) ?? '',
        salesAgent: m['salesAgent'] as String?,
        subtotal: (m['subtotal'] as num?)?.toDouble() ?? 0,
        taxAmt: (m['taxAmt'] as num?)?.toDouble() ?? 0,
        finalTotal: (m['finalTotal'] as num?)?.toDouble() ?? 0,
        paymentTotal: (m['paymentTotal'] as num?)?.toDouble() ?? 0,
        outstanding: (m['outstanding'] as num?)?.toDouble() ?? 0,
        description: null,
        remark: null,
        isVoid: false,
      );
      final paymentAmt = double.tryParse(m['paymentAmt'] as String? ?? '') ?? sale.outstanding;
      final collectMappingID = (m['collectMappingID'] as int?) ?? 0;
      _selectedOrders.add(_SelectedOrder.fromMapping(
        sale,
        paymentAmt: paymentAmt,
        collectMappingID: collectMappingID,
      ));
    }

    // Restore payment total without triggering distribute
    final paymentTotal = j['paymentTotal'] as String? ?? '';
    _paymentTotalCtrl.removeListener(_distributePayment);
    _paymentTotalCtrl.text = paymentTotal;
    _paymentTotalCtrl.addListener(_distributePayment);
  }
  

  void _initFromDoc(CollectionDoc doc) {
    try {
      _docDate = DateTime.parse(doc.docDate);
    } catch (_) {}

    _selectedCustomer = Customer(
      customerID: doc.customerID,
      customerCode: doc.customerCode,
      name: doc.customerName,
      name2: '',
      address1: doc.address1,
      address2: doc.address2,
      address3: doc.address3,
      address4: doc.address4,
      priceCategory: 0,
      customerType: '',
      salesAgent: doc.salesAgent ?? '',
    );
    _salesAgentCtrl.text = doc.salesAgent ?? '';
    _refNoCtrl.text = doc.refNo ?? '';
    _selectedPaymentType = doc.paymentType;
    _imageBase64 = doc.image?.isNotEmpty == true ? doc.image : null;

    for (final m in doc.collectMappings) {
      final sale = SalesListItem(
        docID: m.salesDocID,
        docNo: m.salesDocNo,
        docDate: m.salesDocDate,
        customerID: doc.customerID,
        customerCode: doc.customerCode,
        customerName: doc.customerName,
        salesAgent: m.salesAgent,
        subtotal: m.salesFinalTotal,
        taxAmt: 0,
        finalTotal: m.salesFinalTotal,
        paymentTotal: m.editPaymentAmt,
        outstanding: m.salesOutstanding,
        description: null,
        remark: null,
        isVoid: false,
      );
      _selectedOrders.add(_SelectedOrder.fromMapping(
        sale,
        paymentAmt: m.editPaymentAmt,
        collectMappingID: m.collectMappingID,
      ));
    }

    // Set payment total without triggering distribute (orders already set)
    _paymentTotalCtrl.removeListener(_distributePayment);
    _paymentTotalCtrl.text = doc.paymentTotal.toStringAsFixed(2);
    _paymentTotalCtrl.addListener(_distributePayment);
  }

  Future<void> _checkAndRestoreDraft() async {
    if (_isEditMode) return;
    final raw = await SessionManager.getCollectionDraft();
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      if (mounted) setState(() => _restoreDraft(j));
    } catch (_) {
      await SessionManager.clearCollectionDraft();
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
    if (result == 'discard') await SessionManager.clearCollectionDraft();
    return true;
  }

  // ── Payment distribution ────────────────────────────────────────────

  void _distributePayment() {
    double remaining = double.tryParse(_paymentTotalCtrl.text) ?? 0;
    for (final order in _selectedOrders) {
      final alloc = remaining.clamp(0.0, order.sale.outstanding);
      order.paymentAmtCtrl.text = alloc.toStringAsFixed(2);
      remaining -= alloc;
    }
    setState(() {});
  }


  Future<void> _pickCustomer() async {
    final customer = await Navigator.push<Customer>(
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
    if (customer == null || !mounted) return;

    setState(() {
        _selectedCustomer = customer;
        _salesAgentCtrl.text = customer.salesAgent;
        for (final o in _selectedOrders) {
          o.dispose();
        }
        _selectedOrders.clear();
        _paymentTotalCtrl.text = '0';
      });
      await _pickCustomerSales();
  }

  Future<void> _pickCustomerSales() async {
    if (_selectedCustomer == null) return;
    final result = await Navigator.push<List<SalesListItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionSalesPickerPage(
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
          customerID: _selectedCustomer!.customerID,
          initialSelected: _selectedOrders.map((o) => o.sale).toList(),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        final existing = {for (final o in _selectedOrders) o.sale.docID: o};
        for (final o in _selectedOrders) {
          if (!result.any((s) => s.docID == o.sale.docID)) o.dispose();
        }
        _selectedOrders.clear();
        for (final sale in result) {
          _selectedOrders.add(existing[sale.docID] ?? _SelectedOrder(sale));
        }
      });
      final currentTotal = double.tryParse(_paymentTotalCtrl.text) ?? 0;
      if (currentTotal == 0) {
        final total = _selectedOrders.fold(0.0, (s, o) => s + o.sale.outstanding);
        _paymentTotalCtrl.removeListener(_distributePayment);
        _paymentTotalCtrl.text = total.toStringAsFixed(2);
        _paymentTotalCtrl.addListener(_distributePayment);
      }
      _distributePayment();
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

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file =
          await ImagePicker().pickImage(source: source, imageQuality: 70);
      if (file == null) return;
      final bytes = await File(file.path).readAsBytes();
      final base64Str = base64Encode(bytes);
      setState(() => _imageBase64 = base64Str);
    } catch (_) {}
  }

  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPhoto(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Save ────────────────────────────────────────────────────────────

  Future<void> _save() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
    if (_selectedCustomer == null) {
      _showError('Please select a customer.');
      return;
    }
    if (_selectedOrders.isEmpty) {
      _showError('Please select at least one sales order.');
      return;
    }
    if (_selectedPaymentType == null || _selectedPaymentType!.isEmpty) {
      _showError('Please select a payment type.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final paymentTotal = double.tryParse(_paymentTotalCtrl.text) ?? 0;
      final c = _selectedCustomer!;
      final refNo =
          _refNoCtrl.text.trim().isEmpty ? null : _refNoCtrl.text.trim();

      if (_isEdit) {
        final doc = widget.initialDoc!;
        final collectMappings = _selectedOrders
            .map((o) => {
                  'collectMappingID': o.collectMappingID,
                  'collectDocID': doc.docID,
                  'paymentAmt': o.paymentAmt,
                  'salesDocID': o.sale.docID,
                  'salesDocNo': o.sale.docNo,
                  'salesDocDate': o.sale.docDate,
                  'salesAgent': o.sale.salesAgent,
                  'salesFinalTotal': o.sale.finalTotal,
                  'salesOutstanding': o.sale.outstanding,
                  'editOutstanding': o.sale.outstanding - o.paymentAmt,
                  'editPaymentAmt': o.paymentAmt,
                })
            .toList();
        await BaseClient.post(
          ApiEndpoints.updateCollection,
          body: {
            'apiKey': _apiKey,
            'companyGUID': _companyGUID,
            'userID': _userID,
            'userSessionID': _userSessionID,
            'collectionForm': {
              'docID': doc.docID,
              'docNo': doc.docNo,
              'docDate': _docDate.toIso8601String(),
              'customerID': c.customerID,
              'customerCode': c.customerCode,
              'customerName': c.name,
              'address1': c.address1,
              'address2': c.address2,
              'address3': c.address3,
              'address4': c.address4,
              'salesAgent': _salesAgentCtrl.text.trim(),
              'paymentType': _selectedPaymentType,
              'refNo': refNo,
              'paymentTotal': paymentTotal,
              'image': _imageBase64,
              'lastModifiedUserID': _userID,
              'lastModifiedDateTime': DateTime.now().toIso8601String(),
              'createdUserID': _userID,
              'createdDateTime': DateTime.now().toIso8601String(),
              'collectMappings': collectMappings,
            },
          },
        );
      } else {
        final collectMappings = _selectedOrders
            .map((o) => {
                  'collectMappingID': 0,
                  'collectDocID': 0,
                  'paymentAmt': o.paymentAmt,
                  'salesDocID': o.sale.docID,
                  'salesDocNo': o.sale.docNo,
                  'salesDocDate': o.sale.docDate,
                  'salesAgent': o.sale.salesAgent,
                  'salesFinalTotal': o.sale.finalTotal,
                  'salesOutstanding': o.sale.outstanding,
                  'editOutstanding': o.sale.outstanding - o.paymentAmt,
                  'editPaymentAmt': o.paymentAmt,
                })
            .toList();
        await BaseClient.post(
          ApiEndpoints.createCollection,
          body: {
            'apiKey': _apiKey,
            'companyGUID': _companyGUID,
            'userID': _userID,
            'userSessionID': _userSessionID,
            'collectionForm': {
              'docID': 0,
              'docNo': '',
              'docDate': _docDate.toIso8601String(),
              'customerID': c.customerID,
              'customerCode': c.customerCode,
              'customerName': c.name,
              'salesAgent': _salesAgentCtrl.text.trim(),
              'paymentType': _selectedPaymentType,
              'refNo': refNo,
              'paymentTotal': paymentTotal,
              'isVoid': false,
              'address1': c.address1,
              'address2': c.address2,
              'address3': c.address3,
              'address4': c.address4,
              'image': _imageBase64,
              'lastModifiedUserID': _userID,
              'lastModifiedDateTime': DateTime.now().toIso8601String(),
              'createdUserID': _userID,
              'createdDateTime': DateTime.now().toIso8601String(),
              'collectMappings': collectMappings,
            },
          },
        );
      }

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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return PopScope (
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
          child: Text(_isEditMode ? 'Edit Collection' : 'New Collection',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        centerTitle: true,
        actions: [

        ],
      ),
      body: _loadingDropdowns 
        ? const Center(child: DotsLoading())
        : Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                  controller: _formScrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── DOCUMENT ─────────────────────────────────────
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
            
                      // ── PAYMENT ───────────────────────────────────────
                      FormSectionHeader(
                        icon: Icons.list_alt_outlined,
                        title: 'Payment',
                        expanded: _paymentExpanded,
                        onToggle: () => setState(() => _paymentExpanded = !_paymentExpanded),),
                      AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          child: _paymentExpanded
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FieldLabel(label: 'PaymentType'),
                                    // Payment Type dropdown
                                    if (_loadingPaymentTypes)
                                      const SizedBox(
                                          height: 48,
                                          child: Center(child: DotsLoading(dotSize: 5)))
                                    else
                                      DropdownButtonFormField<String>(
                                        value: _selectedPaymentType,
                                        decoration: formInputDeco(context),
                                        items: _paymentTypes
                                            .map((pt) => DropdownMenuItem(
                                                  value: pt.paymentType,
                                                  child: Text(pt.paymentType,
                                                      style: const TextStyle(fontSize: 14)),
                                                ))
                                            .toList(),
                                        onChanged: (v) =>
                                            setState(() => _selectedPaymentType = v),
                                      ),
                                    const SizedBox(height: 12),
                                    FieldLabel(label: 'Ref. No.'),
                                    TextFormField(
                                      controller: _refNoCtrl,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: formInputDeco(context),
                                    ),
                                    const SizedBox(height: 12),
                                    FieldLabel(label: 'Payment Total'),
                                    TextFormField(
                                      controller: _paymentTotalCtrl,
                                      style: const TextStyle(fontSize: 14),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d*\.?\d{0,2}')),
                                      ],
                                      decoration:
                                          formInputDeco(context).copyWith(
                                        prefixText: '$_currency ',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),
                      
                      // ── ATTACHED SALES ───────────────────────────────────────
                      FormSectionHeader(
                        icon: Icons.list_alt_outlined,
                        title: 'ATTACHED SALES',
                        expanded: _ordersExpanded,
                        onToggle: () => setState(() => _ordersExpanded = !_ordersExpanded),
                        badge: '${_selectedOrders.length}'),
                      AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          child: _ordersExpanded
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SlidableAutoCloseBehavior(
                                      child: Column(
                                        children: [
                                          ..._selectedOrders.map((o) => Padding(
                                            padding: const EdgeInsets.only(bottom: 10),
                                            child: Slidable(
                                              key: ValueKey(o.sale.docID),
                                              endActionPane: ActionPane(
                                                motion: const DrawerMotion(),
                                                extentRatio: 0.25,
                                                children: [
                                                  CustomSlidableAction(
                                                    onPressed: (_) {
                                                      setState(() {
                                                        o.dispose();
                                                        _selectedOrders.remove(o);
                                                      });
                                                    },
                                                    backgroundColor: Colors.red.withValues(alpha: 0.12),
                                                    child: const Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.delete_outline, size: 26, color: Colors.red),
                                                        SizedBox(height: 4),
                                                        Text('Remove', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.red)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              child: _buildSalesOrderCard(o, cs, primary),
                                            ),
                                          )),
                                          if (_selectedOrders.isEmpty)
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 16, vertical: 20),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                    color: cs.outline.withValues(alpha: 0.2)),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  'No sales attached',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: cs.onSurface.withValues(alpha: 0.4)),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                )
                              : const SizedBox.shrink(),
                        ),

                      // ── ATTACHMENT────────────────────────────
                      FormSectionHeader(
                        icon: Icons.notes_outlined,
                        title: 'ATTACHMENT',
                        expanded: _attachmentExpanded,
                        onToggle: () => setState(() => _attachmentExpanded = !_attachmentExpanded)),
                              
                      _buildPhotoSection(cs),
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
          ],
        )
    ),
    );
  }

  // ── Sales order card ─────────────────────────────────────────────────

  Widget _buildSalesOrderCard(
      _SelectedOrder o, ColorScheme cs, Color primary) {
    String formattedDate = o.sale.docDate;
    try {
      final parsed = DateTime.parse(o.sale.docDate);
      formattedDate = _dateFmt.format(parsed);
    } catch (_) {}

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: DocNo | Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                o.sale.docNo,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primary),
              ),
              Text(
                formattedDate,
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2: Total | Outstanding
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: RM ${_amtFmt.format(o.sale.finalTotal)}',
                style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.55)),
              ),
              Text(
                'O/S: RM ${_amtFmt.format(o.sale.outstanding)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Mycolor.secondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 3: Payment Amount field
          TextFormField(
            controller: o.paymentAmtCtrl,
            style: const TextStyle(fontSize: 14),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}')),
            ],
            onChanged: (_) => setState(() {}),
            decoration: formInputDeco(
              context,
              prefixText: '$_currency ',
            ),
          ),
        ],
      ),
    );
  }

  // ── Photo section ────────────────────────────────────────────────────

  Widget _buildPhotoSection(ColorScheme cs) {
    if (_imageBase64 != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              base64Decode(_imageBase64!),
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showPhotoSheet,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit,
                        size: 16, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => setState(() => _imageBase64 = null),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close,
                        size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: _showPhotoSheet,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: cs.outline.withValues(alpha: 0.3),
              style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined,
                size: 28, color: cs.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: 6),
            Text(
              'Tap to attach receipt photo',
              style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────────

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
                          label: 'Sales Outstanding Total',
                          value: _amtFmt.format(_selectedOrders.fold(0.0, (s, o) => s + o.sale.outstanding)),
                          muted: muted),
                        FormTotalPriceSummaryRow(
                            label: 'Outstanding',
                            value: _amtFmt.format(_totalOutstanding),
                            muted: muted,
                            valueColor: _totalOutstanding == 0
                                ? muted
                                : _totalOutstanding < 0
                                    ? Mycolor.taxTextColor
                                    : Mycolor.discountTextColor),
                        
                        Divider(height: 12, color: cs.outline.withValues(alpha: 0.2)),
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
                  '$_currency ${_amtFmt.format(double.tryParse(_paymentTotalCtrl.text) ?? 0)}',
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
