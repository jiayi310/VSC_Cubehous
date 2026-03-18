import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Header state
  DateTime _docDate = DateTime.now();
  Customer? _selectedCustomer;
  final _salesAgentCtrl = TextEditingController();

  // Payment fields
  String? _selectedPaymentType;
  List<PaymentTypeItem> _paymentTypes = [];
  bool _loadingPaymentTypes = true;
  bool _paymentTypesError = false;
  final _refNoCtrl = TextEditingController();
  final _paymentTotalCtrl = TextEditingController(text: '0');

  // Selected orders
  final List<_SelectedOrder> _selectedOrders = [];

  // Photo
  String? _imageBase64;

  // UI state
  bool _isSaving = false;

  final _dateFmt = DateFormat('dd MMM yyyy');
  final _amtFmt = NumberFormat('#,##0.00');

  // ── Computed getters ────────────────────────────────────────────────

  double get _totalSalesAmt =>
      _selectedOrders.fold(0.0, (s, o) => s + o.sale.finalTotal);

  double get _totalOutstanding =>
      _selectedOrders.fold(0.0, (s, o) => s + o.sale.outstanding);

  double get _totalPaymentAmt =>
      _selectedOrders.fold(0.0, (s, o) => s + o.paymentAmt);

  // ── Lifecycle ───────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _paymentTotalCtrl.addListener(_distributePayment);
    _init();
  }

  @override
  void dispose() {
    _salesAgentCtrl.dispose();
    _refNoCtrl.dispose();
    _paymentTotalCtrl.dispose();
    for (final o in _selectedOrders) {
      o.dispose();
    }
    super.dispose();
  }

  bool get _isEdit => widget.initialDoc != null;

  Future<void> _init() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    if (_isEdit) _initFromDoc(widget.initialDoc!);
    await _loadPaymentTypes();
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

  Future<void> _loadPaymentTypes() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userSessionID = await SessionManager.getUserSessionID();
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
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPaymentTypes = false;
          _paymentTypesError = true;
        });
      }
      _showError('Failed to load payment types: $e');
    }
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

  // ── Customer picker ─────────────────────────────────────────────────

  Future<void> _pickCustomer() async {
    final customer = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(
        apiKey: _apiKey,
        companyGUID: _companyGUID,
        userID: _userID,
        userSessionID: _userSessionID,
      ),
    );
    if (customer != null) {
      setState(() {
        _selectedCustomer = customer;
        _salesAgentCtrl.text = customer.salesAgent;
        for (final o in _selectedOrders) {
          o.dispose();
        }
        _selectedOrders.clear();
        _paymentTotalCtrl.text = '0';
      });
      await _openSalesPicker();
    }
  }

  Future<void> _openSalesPicker() async {
    if (_selectedCustomer == null) return;
    final result = await Navigator.push<List<SalesListItem>>(
      context,
      MaterialPageRoute(
        builder: (_) => _SalesPickerPage(
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
      _distributePayment();
    }
  }

  // ── Date picker ─────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _docDate = picked);
  }

  // ── Photo picker ────────────────────────────────────────────────────

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
              'salesAgent': _salesAgentCtrl.text.trim(),
              'paymentType': _selectedPaymentType,
              'refNo': refNo,
              'paymentTotal': paymentTotal,
              'address1': c.address1,
              'address2': c.address2,
              'address3': c.address3,
              'address4': c.address4,
              'image': _imageBase64,
              'collectMappings': collectMappings,
            },
          },
        );
      } else {
        final collectMappings = _selectedOrders
            .map((o) => {
                  'salesDocID': o.sale.docID,
                  'salesDocNo': o.sale.docNo,
                  'paymentAmt': o.paymentAmt,
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
            'collectForm': {
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

  // ── Field decoration helper ─────────────────────────────────────────

  InputDecoration _fieldDeco(String label, ColorScheme cs, Color primary) =>
      InputDecoration(
        labelText: label,
        filled: true,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: primary)),
      );

  Widget _sectionHeader(String title, Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value,
    Color color,
    ColorScheme cs, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Collection' : 'New Collection',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Padding(
                padding: EdgeInsets.all(16), child: DotsLoading(dotSize: 6))
          else
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── DOCUMENT ─────────────────────────────────────
                  _sectionHeader('DOCUMENT', primary),

                  // Date picker row
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: cs.outline.withValues(alpha: 0.0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.5)),
                          const SizedBox(width: 10),
                          Text(
                            _dateFmt.format(_docDate),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          Icon(Icons.edit_outlined,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.3)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Customer picker row
                  InkWell(
                    onTap: _pickCustomer,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: cs.outline.withValues(alpha: 0.0)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 16,
                              color: cs.onSurface.withValues(alpha: 0.5)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _selectedCustomer == null
                                ? Text(
                                    'Select Customer',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: cs.onSurface
                                            .withValues(alpha: 0.4)),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedCustomer!.name,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        _selectedCustomer!.customerCode,
                                        style: TextStyle(
                                            fontSize: 12, color: primary),
                                      ),
                                    ],
                                  ),
                          ),
                          Icon(Icons.chevron_right,
                              size: 18,
                              color: cs.onSurface.withValues(alpha: 0.3)),
                        ],
                      ),
                    ),
                  ),

                  // ── PAYMENT ───────────────────────────────────────
                  _sectionHeader('PAYMENT', primary),

                  // Payment Type dropdown
                  if (_loadingPaymentTypes)
                    const SizedBox(
                        height: 48,
                        child: Center(child: DotsLoading(dotSize: 5)))
                  else if (_paymentTypesError)
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _loadingPaymentTypes = true;
                          _paymentTypesError = false;
                        });
                        _loadPaymentTypes();
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Retry loading payment types'),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPaymentType,
                      decoration: _fieldDeco('Payment Type *', cs, primary),
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

                  const SizedBox(height: 10),

                  // Ref No
                  TextFormField(
                    controller: _refNoCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: _fieldDeco('Ref No', cs, primary),
                  ),

                  const SizedBox(height: 10),

                  // Payment Total
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
                        _fieldDeco('Payment Total', cs, primary).copyWith(
                      prefixText: 'RM ',
                    ),
                  ),

                  // ── ATTACHED SALES ────────────────────────────────
                  _sectionHeader('ATTACHED SALES', primary),

                  // Header row: count + action button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Attached Sales (${_selectedOrders.length})',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface.withValues(alpha: 0.7)),
                      ),
                      if (_selectedCustomer != null)
                        TextButton(
                          onPressed: _openSalesPicker,
                          child: Text(
                            _selectedOrders.isEmpty
                                ? 'Add Sales'
                                : 'Change Sales',
                            style:
                                TextStyle(fontSize: 13, color: primary),
                          ),
                        )
                      else
                        Text(
                          'Select a customer first',
                          style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color:
                                  cs.onSurface.withValues(alpha: 0.4)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Selected order cards
                  ..._selectedOrders.map((o) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildSalesOrderCard(o, cs, primary),
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
                              color:
                                  cs.onSurface.withValues(alpha: 0.4)),
                        ),
                      ),
                    ),

                  // ── RECEIPT (Optional) ────────────────────────────
                  _sectionHeader('RECEIPT (Optional)', primary),

                  _buildPhotoSection(cs),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Sticky bottom bar ────────────────────────────────────
          _buildBottomBar(cs, primary),
        ],
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
                'Outstanding: RM ${_amtFmt.format(o.sale.outstanding)}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange),
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
            decoration: InputDecoration(
              labelText: 'Payment Amount',
              prefixText: 'RM ',
              filled: true,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primary)),
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

  Widget _buildBottomBar(ColorScheme cs, Color primary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
            top: BorderSide(color: cs.outline.withValues(alpha: 0.15))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow(
              'Sales Total',
              'RM ${_amtFmt.format(_totalSalesAmt)}',
              cs.onSurface.withValues(alpha: 0.6),
              cs,
            ),
            const SizedBox(height: 3),
            _summaryRow(
              'Outstanding',
              'RM ${_amtFmt.format(_totalOutstanding)}',
              Colors.orange,
              cs,
            ),
            const SizedBox(height: 3),
            _summaryRow(
              'Payment',
              'RM ${_amtFmt.format(_totalPaymentAmt)}',
              primary,
              cs,
              bold: true,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sales Picker Page — full page multi-select
// ─────────────────────────────────────────────────────────────────────

class _SalesPickerPage extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final String userSessionID;
  final int userID;
  final int customerID;
  final List<SalesListItem> initialSelected;

  const _SalesPickerPage({
    required this.apiKey,
    required this.companyGUID,
    required this.userSessionID,
    required this.userID,
    required this.customerID,
    required this.initialSelected,
  });

  @override
  State<_SalesPickerPage> createState() => _SalesPickerPageState();
}

class _SalesPickerPageState extends State<_SalesPickerPage> {
  final _searchCtrl = TextEditingController();
  Set<int> _selected = {};
  List<SalesListItem> _sales = [];
  bool _isLoading = false;
  String? _error;

  final _dateFmt = DateFormat('dd MMM yyyy');
  final _amtFmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.map((s) => s.docID).toSet();
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getSalesListForCollect,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'pageIndex': 0,
          'pageSize': 200,
          'sortBy': 'DocDate',
          'isSortByAscending': false,
          'searchTerm': _searchCtrl.text.trim().isEmpty
              ? null
              : _searchCtrl.text.trim(),
          'customerID': widget.customerID,
        },
      );
      final raw = response as Map<String, dynamic>;
      final data = (raw['data'] as List<dynamic>?)
              ?.map((e) => SalesListItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      if (mounted) {
        setState(() {
          _sales = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _confirm() {
    final result =
        _sales.where((s) => _selected.contains(s.docID)).toList();
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Select Sales',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_selected.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '${_selected.length} selected',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primary),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _fetch(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search sales...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _fetch();
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
        ),
      ),
      body: _isLoading
          ? const Center(child: DotsLoading())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 12),
                      FilledButton(
                          onPressed: _fetch, child: const Text('Retry')),
                    ],
                  ),
                )
              : _sales.isEmpty
                  ? const Center(child: Text('No sales available'))
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: _sales.length,
                            itemBuilder: (ctx, i) {
                              final sale = _sales[i];
                              final isSelected =
                                  _selected.contains(sale.docID);

                              String formattedDate = sale.docDate;
                              try {
                                final parsed =
                                    DateTime.parse(sale.docDate);
                                formattedDate = _dateFmt.format(parsed);
                              } catch (_) {}

                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selected.add(sale.docID);
                                    } else {
                                      _selected.remove(sale.docID);
                                    }
                                  });
                                },
                                title: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      sale.docNo,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: primary),
                                    ),
                                    Text(
                                      formattedDate,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: cs.onSurface
                                              .withValues(alpha: 0.5)),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    if (sale.salesAgent != null &&
                                        sale.salesAgent!.isNotEmpty)
                                      Text(
                                        sale.salesAgent!,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurface
                                                .withValues(alpha: 0.5)),
                                      ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          'Total: RM ${_amtFmt.format(sale.finalTotal)}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: cs.onSurface
                                                  .withValues(alpha: 0.55)),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'O/S: RM ${_amtFmt.format(sale.outstanding)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.orange),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: SafeArea(
                            top: false,
                            child: SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                onPressed:
                                    _selected.isEmpty ? null : _confirm,
                                child: Text(
                                  'Confirm (${_selected.length} selected)',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Customer Picker Bottom Sheet — infinite scroll with paginated search
// ─────────────────────────────────────────────────────────────────────

class _CustomerPickerSheet extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  const _CustomerPickerSheet({
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
  });

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Customer> _customers = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;

  int _currentPage = 0;
  int _totalCount = 0;
  bool _hasMore = true;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _fetch(reset: true);
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!_isLoading && !_isLoadingMore && _hasMore) {
        _fetch(reset: false);
      }
    }
  }

  Future<void> _fetch({required bool reset}) async {
    if (!reset && (_isLoadingMore || !_hasMore)) return;
    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final page = reset ? 0 : _currentPage + 1;
      final response = await BaseClient.post(
        ApiEndpoints.getCustomerList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'pageIndex': page,
          'pageSize': _pageSize,
          'sortBy': 'CustomerCode',
          'isSortByAscending': true,
          'searchTerm': _searchCtrl.text.trim().isEmpty
              ? null
              : _searchCtrl.text.trim(),
        },
      );
      final raw = response as Map<String, dynamic>;
      final data = (raw['data'] as List<dynamic>?)
              ?.map((e) => Customer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final total =
          (raw['paginationOpt']?['totalRecord'] as int?) ?? data.length;

      if (mounted) {
        setState(() {
          if (reset) {
            _customers = data;
          } else {
            _customers.addAll(data);
          }
          _currentPage = page;
          _totalCount = total;
          _hasMore = _customers.length < total;
          _isLoading = false;
          _isLoadingMore = false;
        });
        if (reset && _scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, __) => Material(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          children: [
            const SizedBox(height: 12),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text(
                    'Select Customer',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '$_totalCount customers',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _fetch(reset: true),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search customers...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _fetch(reset: true);
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
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: DotsLoading())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Error: $_error'),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () => _fetch(reset: true),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _customers.isEmpty
                          ? const Center(
                              child: Text('No customers found'))
                          : ListView.builder(
                              controller: _scrollCtrl,
                              itemCount: _customers.length +
                                  (_isLoadingMore ? 1 : 0),
                              itemBuilder: (ctx, i) {
                                if (i == _customers.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Center(
                                        child:
                                            DotsLoading(dotSize: 6)),
                                  );
                                }
                                final c = _customers[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        primary.withValues(alpha: 0.12),
                                    child: Text(
                                      c.name.isNotEmpty
                                          ? c.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                          color: primary,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  title: Text(c.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500)),
                                  subtitle: Text(
                                    c.customerCode,
                                    style: TextStyle(
                                        fontSize: 12, color: primary),
                                  ),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: cs.onSurface
                                        .withValues(alpha: 0.3),
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 4),
                                  onTap: () =>
                                      Navigator.pop(context, c),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
