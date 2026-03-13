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
import '../../models/Sales.dart';
import '../../models/customer.dart';

// ─────────────────────────────────────────────────────────────────────
// Selected Order helper (plain Dart, not a widget)
// ─────────────────────────────────────────────────────────────────────

class _SelectedOrder {
  final SalesListItem sale;
  final TextEditingController paymentAmtCtrl;

  _SelectedOrder(this.sale)
      : paymentAmtCtrl = TextEditingController(
            text: sale.outstanding.toStringAsFixed(2));

  void dispose() => paymentAmtCtrl.dispose();

  double get paymentAmt => double.tryParse(paymentAmtCtrl.text) ?? 0;
}

// ─────────────────────────────────────────────────────────────────────
// Collection Form Page
// ─────────────────────────────────────────────────────────────────────

class CollectionFormPage extends StatefulWidget {
  const CollectionFormPage({super.key});

  @override
  State<CollectionFormPage> createState() => _CollectionFormPageState();
}

class _CollectionFormPageState extends State<CollectionFormPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  // Form state
  DateTime _docDate = DateTime.now();
  Customer? _selectedCustomer;
  final _salesAgentCtrl = TextEditingController();
  final _refNoCtrl = TextEditingController();
  String? _selectedPaymentType;
  List<PaymentTypeItem> _paymentTypes = [];
  bool _loadingPaymentTypes = true;

  // Outstanding sales orders for selected customer
  List<SalesListItem> _outstandingSales = [];
  bool _loadingSales = false;

  // Selected sales orders with editable payment amount
  final List<_SelectedOrder> _selectedOrders = [];

  // Image
  XFile? _imageFile;
  bool _isSaving = false;

  final _dateFmt = DateFormat('dd MMM yyyy');
  final _amtFmt = NumberFormat('#,##0.00');

  double get _totalAmt =>
      _selectedOrders.fold(0.0, (s, o) => s + o.paymentAmt);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _salesAgentCtrl.dispose();
    _refNoCtrl.dispose();
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
    await _loadPaymentTypes();
  }

  Future<void> _loadPaymentTypes() async {
    setState(() => _loadingPaymentTypes = true);
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getPaymentTypeList,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
        },
      );
      final raw = response as List<dynamic>;
      final list = raw.map((e) {
        if (e is String) return PaymentTypeItem(paymentType: e);
        if (e is Map<String, dynamic>) return PaymentTypeItem.fromJson(e);
        return PaymentTypeItem(paymentType: e.toString());
      }).where((pt) => pt.paymentType.isNotEmpty).toList();
      setState(() {
        _paymentTypes = list;
        if (list.isNotEmpty) _selectedPaymentType = list.first.paymentType;
        _loadingPaymentTypes = false;
      });
    } catch (e) {
      setState(() => _loadingPaymentTypes = false);
      _showSnack('Failed to load payment types: $e');
    }
  }

  Future<void> _loadOutstandingSales() async {
    if (_selectedCustomer == null) return;
    setState(() {
      _loadingSales = true;
      _outstandingSales = [];
      _selectedOrders.clear();
    });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getSalesListForCollect,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'pageIndex': 0,
          'pageSize': 200,
          'sortBy': 'DocDate',
          'isSortByAscending': false,
          'searchTerm': null,
          'customerID': _selectedCustomer!.customerID,
        },
      );
      final result = SalesResponse.fromJson(response as Map<String, dynamic>);
      final filtered = result.data ?? [];
      setState(() {
        _outstandingSales = filtered;
        _loadingSales = false;
      });
    } catch (_) {
      setState(() => _loadingSales = false);
    }
  }

  Future<void> _pickCustomer() async {
    final customer = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(
        apiKey: _apiKey,
        companyGUID: _companyGUID,
      ),
    );
    if (customer != null) {
      setState(() {
        _selectedCustomer = customer;
        _salesAgentCtrl.text = customer.salesAgent;
      });
      await _loadOutstandingSales();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _docDate = picked);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source != null) {
      final file = await ImagePicker()
          .pickImage(source: source, imageQuality: 70);
      if (file != null) setState(() => _imageFile = file);
    }
  }

  void _toggleOrder(SalesListItem sale) {
    setState(() {
      final idx =
          _selectedOrders.indexWhere((o) => o.sale.docID == sale.docID);
      if (idx >= 0) {
        _selectedOrders[idx].dispose();
        _selectedOrders.removeAt(idx);
      } else {
        _selectedOrders.add(_SelectedOrder(sale));
      }
    });
  }

  bool _isSelected(SalesListItem sale) =>
      _selectedOrders.any((o) => o.sale.docID == sale.docID);

  _SelectedOrder? _getSelected(SalesListItem sale) {
    final idx = _selectedOrders.indexWhere((o) => o.sale.docID == sale.docID);
    return idx >= 0 ? _selectedOrders[idx] : null;
  }

  Future<void> _save() async {
    final c = _selectedCustomer;
    if (c == null) {
      _showSnack('Please select a customer');
      return;
    }
    if (_selectedOrders.isEmpty) {
      _showSnack('Please select at least one sales order');
      return;
    }
    if (_selectedPaymentType == null || _selectedPaymentType!.isEmpty) {
      _showSnack('Please select a payment type');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String? imageBase64;
      if (_imageFile != null) {
        final bytes = await File(_imageFile!.path).readAsBytes();
        imageBase64 = base64Encode(bytes);
      }

      final totalAmt = _totalAmt;

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
            'address1': c.address1 ?? '',
            'address2': c.address2 ?? '',
            'address3': c.address3 ?? '',
            'address4': c.address4 ?? '',
            'salesAgent': _salesAgentCtrl.text,
            'paymentType': _selectedPaymentType,
            'refNo': _refNoCtrl.text,
            'paymentTotal': totalAmt,
            'image': imageBase64 ?? '',
            'lastModifiedDateTime': DateTime.now().toIso8601String(),
            'lastModifiedUserID': _userID,
            'createdDateTime': DateTime.now().toIso8601String(),
            'createdUserID': _userID,
            'collectMappings': _selectedOrders
                .map((o) => {
                      'collectMappingID': 0,
                      'collectDocID': 0,
                      'paymentAmt': o.paymentAmt,
                      'salesDocID': o.sale.docID,
                      'salesDocNo': o.sale.docNo,
                      'salesDocDate': o.sale.docDate,
                      'salesAgent': o.sale.salesAgent ?? '',
                      'salesFinalTotal': o.sale.finalTotal,
                      'salesOutstanding': o.sale.outstanding,
                      'editOutstanding': o.sale.outstanding - o.paymentAmt,
                      'editPaymentAmt': o.paymentAmt,
                    })
                .toList(),
          },
        },
      );

      setState(() => _isSaving = false);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        _showSnack('Failed to save: ${e.toString()}');
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Collection',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Section 1: Header card ────────────────────────
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Header',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: primary)),
                          const SizedBox(height: 12),

                          // Date picker row
                          InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined,
                                      size: 18, color: muted),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Date',
                                            style: TextStyle(
                                                fontSize: 11, color: muted)),
                                        const SizedBox(height: 2),
                                        Text(
                                          _dateFmt.format(_docDate),
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.expand_more_rounded,
                                      size: 18, color: muted),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Customer picker row
                          InkWell(
                            onTap: _pickCustomer,
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: _selectedCustomer != null
                                        ? primary.withValues(alpha: 0.5)
                                        : Theme.of(context)
                                            .colorScheme
                                            .outline
                                            .withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline,
                                      size: 18,
                                      color: _selectedCustomer != null
                                          ? primary
                                          : muted),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _selectedCustomer != null
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('Customer',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: muted)),
                                              const SizedBox(height: 2),
                                              Text(
                                                _selectedCustomer!.name,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                              Text(
                                                _selectedCustomer!.customerCode,
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: muted),
                                              ),
                                            ],
                                          )
                                        : Text(
                                            'Select Customer',
                                            style: TextStyle(
                                                fontSize: 14, color: muted),
                                          ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      size: 18, color: muted),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Sales Agent text field
                          TextField(
                            controller: _salesAgentCtrl,
                            decoration: InputDecoration(
                              labelText: 'Sales Agent',
                              prefixIcon: const Icon(Icons.badge_outlined,
                                  size: 20),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 2: Payment card ───────────────────────
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: primary)),
                          const SizedBox(height: 12),

                          // Payment Type dropdown
                          if (_loadingPaymentTypes)
                            const Center(child: DotsLoading())
                          else if (_paymentTypes.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.4)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'No payment types available',
                                style: TextStyle(fontSize: 14, color: muted),
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              value: _selectedPaymentType,
                              decoration: InputDecoration(
                                labelText: 'Payment Type',
                                prefixIcon: const Icon(Icons.payment_outlined,
                                    size: 20),
                                isDense: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              items: _paymentTypes
                                  .map((pt) => DropdownMenuItem(
                                        value: pt.paymentType,
                                        child: Text(pt.paymentType),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedPaymentType = v),
                            ),

                          const SizedBox(height: 12),

                          // Ref No text field
                          TextField(
                            controller: _refNoCtrl,
                            decoration: InputDecoration(
                              labelText: 'Reference No',
                              prefixIcon: const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 20),
                              isDense: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Section 3: Outstanding Orders card ───────────
                  if (_selectedCustomer != null)
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Outstanding Orders',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primary)),
                            const SizedBox(height: 12),
                            if (_loadingSales)
                              const Center(
                                  child: Padding(
                                padding: EdgeInsets.all(16),
                                child: DotsLoading(),
                              ))
                            else if (_outstandingSales.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16),
                                  child: Text(
                                    'No outstanding orders found',
                                    style: TextStyle(
                                        fontSize: 13, color: muted),
                                  ),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics:
                                    const NeverScrollableScrollPhysics(),
                                itemCount: _outstandingSales.length,
                                itemBuilder: (context, i) {
                                  final sale = _outstandingSales[i];
                                  final selected = _isSelected(sale);
                                  final selectedOrder =
                                      _getSelected(sale);
                                  return _OutstandingOrderTile(
                                    sale: sale,
                                    isSelected: selected,
                                    onToggle: () => _toggleOrder(sale),
                                    paymentCtrl: selectedOrder
                                        ?.paymentAmtCtrl,
                                    amtFmt: _amtFmt,
                                    onPaymentChanged: () => setState(() {}),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                  if (_selectedCustomer != null) const SizedBox(height: 12),

                  // ── Section 4: Photo card ────────────────────────
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Receipt (Optional)',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: primary)),
                          const SizedBox(height: 12),
                          if (_imageFile == null)
                            GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 32),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline
                                        .withValues(alpha: 0.4),
                                    style: BorderStyle.solid,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.camera_alt_outlined,
                                        size: 36, color: muted),
                                    const SizedBox(height: 8),
                                    Text('Tap to add photo',
                                        style: TextStyle(
                                            fontSize: 13, color: muted)),
                                  ],
                                ),
                              ),
                            )
                          else
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(_imageFile!.path),
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _imageFile = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 18, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: _pickImage,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                              Icons.camera_alt_outlined,
                                              size: 14,
                                              color: Colors.white),
                                          SizedBox(width: 4),
                                          Text('Change',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // ── Sticky bottom bar ─────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.15),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total',
                            style: TextStyle(fontSize: 12, color: muted)),
                        Text(
                          'RM ${_amtFmt.format(_totalAmt)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(120, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Outstanding Order Tile
// ─────────────────────────────────────────────────────────────────────

class _OutstandingOrderTile extends StatelessWidget {
  final SalesListItem sale;
  final bool isSelected;
  final VoidCallback onToggle;
  final TextEditingController? paymentCtrl;
  final NumberFormat amtFmt;
  final VoidCallback onPaymentChanged;

  const _OutstandingOrderTile({
    required this.sale,
    required this.isSelected,
    required this.onToggle,
    required this.paymentCtrl,
    required this.amtFmt,
    required this.onPaymentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    DateTime? docDate;
    try {
      docDate = DateTime.parse(sale.docDate);
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? primary.withValues(alpha: 0.4)
                : Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.2),
          ),
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? primary.withValues(alpha: 0.04) : null,
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => onToggle(),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                sale.docNo,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                docDate != null
                                    ? DateFormat('dd/MM/yyyy')
                                        .format(docDate)
                                    : sale.docDate,
                                style: TextStyle(
                                    fontSize: 11, color: muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                'Total: RM ${amtFmt.format(sale.finalTotal)}',
                                style: TextStyle(
                                    fontSize: 11, color: muted),
                              ),
                              const Spacer(),
                              Text(
                                'Outstanding: RM ${amtFmt.format(sale.outstanding)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isSelected && paymentCtrl != null)
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: TextField(
                  controller: paymentCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  onChanged: (_) => onPaymentChanged(),
                  decoration: InputDecoration(
                    labelText: 'Payment Amount',
                    prefixText: 'RM ',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
// Customer Picker Sheet
// ─────────────────────────────────────────────────────────────────────

class _CustomerPickerSheet extends StatefulWidget {
  final String apiKey;
  final String companyGUID;

  const _CustomerPickerSheet({
    required this.apiKey,
    required this.companyGUID,
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
  int _currentPage = 0;
  int _totalCount = 0;
  static const _pageSize = 20;

  bool get _hasMore => _customers.length < _totalCount;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _fetchCustomers(reset: true);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetchCustomers({required bool reset}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
      });
    }
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getCustomerList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'pageIndex': reset ? 0 : _currentPage,
          'pageSize': _pageSize,
          'searchTerm': _searchCtrl.text.trim().isEmpty
              ? null
              : _searchCtrl.text.trim(),
          'sortBy': 'CustomerName',
          'isSortByAscending': true,
        },
      );

      final result =
          CustomerResponse.fromJson(response as Map<String, dynamic>);
      final newItems = result.data ?? [];

      setState(() {
        if (reset) {
          _customers = newItems;
        } else {
          _customers = [..._customers, ...newItems];
        }
        _totalCount =
            result.pagination?.totalRecord ?? newItems.length;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });
    await _fetchCustomers(reset: false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, __) => Material(
        color: surface,
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Text('Select Customer',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _fetchCustomers(reset: true),
                onChanged: (v) {
                  if (v.isEmpty) _fetchCustomers(reset: true);
                },
                decoration: InputDecoration(
                  hintText: 'Search customers...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _fetchCustomers(reset: true);
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.search, size: 18),
                          onPressed: () =>
                              _fetchCustomers(reset: true),
                        ),
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
                  : _customers.isEmpty
                      ? Center(
                          child: Text('No customers found',
                              style:
                                  TextStyle(fontSize: 14, color: muted)),
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          itemCount: _customers.length +
                              (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, i) {
                            if (i == _customers.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: DotsLoading()),
                              );
                            }
                            final c = _customers[i];
                            final initial = c.name.isNotEmpty
                                ? c.name[0].toUpperCase()
                                : '?';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    primary.withValues(alpha: 0.12),
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                              ),
                              title: Text(c.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                c.customerCode,
                                style: TextStyle(
                                    fontSize: 12, color: muted),
                              ),
                              onTap: () => Navigator.pop(context, c),
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
