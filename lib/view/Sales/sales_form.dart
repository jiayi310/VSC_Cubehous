import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../common/session_manager.dart';
import '../../models/customer.dart';
import '../../models/TaxType.dart';

class SalesFormPage extends StatefulWidget {
  const SalesFormPage({super.key});

  @override
  State<SalesFormPage> createState() => _SalesFormPageState();
}

class _SalesFormPageState extends State<SalesFormPage> {
  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  // Header state
  DateTime _docDate = DateTime.now();
  Customer? _selectedCustomer;
  final _salesAgentCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final _shippingCtrl = TextEditingController();
  final _qtDocNoCtrl = TextEditingController();

  // Line items
  final List<_LineItem> _lines = [];

  // Dropdown data
  List<TaxType> _taxTypes = [];
  bool _loadingDropdowns = true;

  bool _isSaving = false;
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _amtFmt = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _salesAgentCtrl.dispose();
    _descriptionCtrl.dispose();
    _remarkCtrl.dispose();
    _shippingCtrl.dispose();
    _qtDocNoCtrl.dispose();
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
    await _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    try {
      final body = {
        'apiKey': _apiKey,
        'companyGUID': _companyGUID,
        'userID': _userID,
        'userSessionID': _userSessionID,
      };
      final result = await BaseClient.post(ApiEndpoints.getTaxList, body: body);
      setState(() {
        _taxTypes = (result as List<dynamic>)
            .map((e) => TaxType.fromJson(e as Map<String, dynamic>))
            .where((t) => !t.isDisabled)
            .toList();
        _loadingDropdowns = false;
      });
    } catch (_) {
      setState(() => _loadingDropdowns = false);
    }
  }

  // ── Calculated totals ─────────────────────────────────────────────────

  double get _subtotal => _lines.fold(0, (s, l) => s + l.lineTotal);
  double get _taxAmt => _lines.fold(0, (s, l) => s + l.lineTaxAmt);
  double get _finalTotal => _subtotal + _taxAmt;

  // ── Save ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
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
      if (l.stockCodeCtrl.text.trim().isEmpty) {
        _showError('Item ${i + 1}: stock code is required.');
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
      final now = DateTime.now().toIso8601String();
      final details = _lines.map((l) {
        final taxableAmt = l.lineTaxableAmt;
        return {
          'dtlID': 0,
          'docID': 0,
          'stockCode': l.stockCodeCtrl.text.trim(),
          'description': l.descriptionCtrl.text.trim(),
          'uom': l.uomCtrl.text.trim(),
          'qty': l.qty,
          'unitPrice': l.unitPrice,
          'discount': l.discount,
          'total': l.lineTotal,
          'taxCode': l.selectedTaxType?.taxCode,
          'taxableAmt': taxableAmt,
          'taxRate': l.selectedTaxType?.taxRate ?? 0,
          'taxAmt': l.lineTaxAmt,
          'location': l.locationCtrl.text.trim().isEmpty
              ? null
              : l.locationCtrl.text.trim(),
        };
      }).toList();

      await BaseClient.post(
        ApiEndpoints.createSales,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'salesForm': {
            'docID': 0,
            'docNo': '',
            'docDate': _docDate.toIso8601String(),
            'customerCode': c.customerCode,
            'customerName': c.name,
            'address1': c.address1,
            'address2': c.address2,
            'address3': c.address3,
            'address4': c.address4,
            'deliverAddr1': c.deliverAddr1,
            'deliverAddr2': c.deliverAddr2,
            'deliverAddr3': c.deliverAddr3,
            'deliverAddr4': c.deliverAddr4,
            'salesAgent': _salesAgentCtrl.text.trim(),
            'phone': c.phone1,
            'fax': c.fax1,
            'email': c.email,
            'attention': c.attention,
            'subtotal': _subtotal,
            'taxableAmt': _lines.fold(0.0, (s, l) => s + l.lineTaxableAmt),
            'taxAmt': _taxAmt,
            'finalTotal': _finalTotal,
            'paymentTotal': 0,
            'outstanding': 0,
            'description': _descriptionCtrl.text.trim(),
            'remark': _remarkCtrl.text.trim(),
            'shippingMethodDescription': _shippingCtrl.text.trim(),
            'qtDocNo': _qtDocNoCtrl.text.trim(),
            'isVoid': false,
            'isPicking': false,
            'isPacking': false,
            'pickingDocID': 0,
            'pickingDocNo': '',
            'lastModifiedUserID': _userID,
            'lastModifiedDateTime': now,
            'createdUserID': _userID,
            'createdDateTime': now,
            'salesDetails': details,
          },
        },
      );

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

  // ── Customer picker ───────────────────────────────────────────────────

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<Customer>(
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
    if (picked != null) {
      setState(() => _selectedCustomer = picked);
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _docDate = picked);
  }

  // ── Line management ───────────────────────────────────────────────────

  void _addLine() {
    setState(() => _lines.add(_LineItem()));
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Sales Order',
            style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Padding(
                padding: EdgeInsets.all(16), child: DotsLoading(dotSize: 6))
          else
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: _loadingDropdowns
          ? const Center(child: DotsLoading())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Header card ──────────────────────────────────
                        _sectionHeader(
                            Icons.receipt_long_outlined, 'Document'),
                        _FieldLabel(label: 'Date'),
                        InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: _FieldBox(
                            child: Row(
                              children: [
                                const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 16),
                                const SizedBox(width: 8),
                                Text(_dateFmt.format(_docDate),
                                    style:
                                        const TextStyle(fontSize: 14)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _FieldLabel(label: 'Customer *'),
                        InkWell(
                          onTap: _pickCustomer,
                          borderRadius: BorderRadius.circular(12),
                          child: _FieldBox(
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline,
                                    size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _selectedCustomer == null
                                      ? Text(
                                          'Tap to select customer',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withValues(
                                                      alpha: 0.4)),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedCustomer!.name,
                                              style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.w600),
                                            ),
                                            Text(
                                              _selectedCustomer!
                                                  .customerCode,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary),
                                            ),
                                          ],
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
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _salesAgentCtrl,
                          style: const TextStyle(fontSize: 14),
                          decoration: _inputDeco('Sales Agent'),
                        ),

                        // ── Reference card ───────────────────────────────
                        _sectionHeader(
                            Icons.link_outlined, 'References'),
                        TextFormField(
                          controller: _qtDocNoCtrl,
                          style: const TextStyle(fontSize: 14),
                          decoration:
                              _inputDeco('Quotation Ref No.'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _shippingCtrl,
                          style: const TextStyle(fontSize: 14),
                          decoration:
                              _inputDeco('Shipping Method'),
                        ),

                        // ── Line items ───────────────────────────────────
                        _sectionHeader(
                            Icons.list_alt_outlined, 'Items'),
                        ..._lines.asMap().entries.map((e) =>
                            _LineItemCard(
                              key: ValueKey(e.key),
                              index: e.key,
                              item: e.value,
                              taxTypes: _taxTypes,
                              amtFmt: _amtFmt,
                              onRemove: () => _removeLine(e.key),
                              onChanged: () => setState(() {}),
                            )),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _addLine,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Item'),
                          style: OutlinedButton.styleFrom(
                            minimumSize:
                                const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                        ),

                        // ── Footer card ──────────────────────────────────
                        _sectionHeader(
                            Icons.notes_outlined, 'Notes'),
                        TextFormField(
                          controller: _descriptionCtrl,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14),
                          decoration: _inputDeco('Description'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _remarkCtrl,
                          maxLines: 2,
                          style: const TextStyle(fontSize: 14),
                          decoration: _inputDeco('Remark'),
                        ),
                        const SizedBox(height: 24),
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
                      child: const Text(
                        'Create Sales Order',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTotalsFooter() {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Subtotal',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5))),
            Text('RM ${_amtFmt.format(_subtotal)}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tax',
                style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.5))),
            Text('RM ${_amtFmt.format(_taxAmt)}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Total',
                style:
                    TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
            Text(
              'RM ${_amtFmt.format(_finalTotal)}',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: primary),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
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
          const SizedBox(width: 8),
          Expanded(
              child: Divider(
                  color: primary.withValues(alpha: 0.2), thickness: 1)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
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
// Line item state model
// ─────────────────────────────────────────────────────────────────────

class _LineItem {
  final stockCodeCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final uomCtrl = TextEditingController();
  final locationCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');
  final unitPriceCtrl = TextEditingController(text: '0');
  final discountCtrl = TextEditingController(text: '0');
  TaxType? selectedTaxType;

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;
  double get unitPrice => double.tryParse(unitPriceCtrl.text) ?? 0;
  double get discount => double.tryParse(discountCtrl.text) ?? 0;
  double get lineTotal => qty * unitPrice * (1 - discount / 100);
  double get lineTaxableAmt => selectedTaxType != null ? lineTotal : 0;
  double get lineTaxAmt =>
      lineTaxableAmt * (selectedTaxType?.taxRate ?? 0) / 100;

  void dispose() {
    stockCodeCtrl.dispose();
    descriptionCtrl.dispose();
    uomCtrl.dispose();
    locationCtrl.dispose();
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
  final NumberFormat amtFmt;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _LineItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.taxTypes,
    required this.amtFmt,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_LineItemCard> createState() => _LineItemCardState();
}

class _LineItemCardState extends State<_LineItemCard> {
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
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    final item = widget.item;
    final total = item.lineTotal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 0),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${widget.index + 1}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primary),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'RM ${widget.amtFmt.format(total)}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: primary),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: widget.onRemove,
                  visualDensity: VisualDensity.compact,
                  color: cs.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: _miniField(
                        ctrl: item.stockCodeCtrl,
                        label: 'Stock Code *',
                        onChanged: widget.onChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniField(
                        ctrl: item.uomCtrl,
                        label: 'UOM',
                        onChanged: widget.onChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _miniField(
                  ctrl: item.descriptionCtrl,
                  label: 'Description',
                  onChanged: widget.onChanged,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _miniField(
                        ctrl: item.qtyCtrl,
                        label: 'Qty *',
                        keyboard: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'))
                        ],
                        onChanged: widget.onChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniField(
                        ctrl: item.unitPriceCtrl,
                        label: 'Unit Price',
                        keyboard: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'))
                        ],
                        onChanged: widget.onChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniField(
                        ctrl: item.discountCtrl,
                        label: 'Disc %',
                        keyboard: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'))
                        ],
                        onChanged: widget.onChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _miniDropdown<TaxType?>(
                        label: 'Tax',
                        value: item.selectedTaxType,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text('No Tax',
                                style: TextStyle(
                                    color: cs.onSurface
                                        .withValues(alpha: 0.4),
                                    fontSize: 13)),
                          ),
                          ...widget.taxTypes.map(
                            (t) => DropdownMenuItem(
                              value: t,
                              child: Text(
                                  '${t.taxCode} (${t.taxRate?.toStringAsFixed(0)}%)',
                                  style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => item.selectedTaxType = v);
                          widget.onChanged();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _miniField(
                        ctrl: item.locationCtrl,
                        label: 'Location',
                        onChanged: widget.onChanged,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniField({
    required TextEditingController ctrl,
    required String label,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    VoidCallback? onChanged,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 13),
      onChanged: (_) => onChanged?.call(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        filled: true,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _miniDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        filled: true,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 1.5),
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Customer picker sheet
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
  State<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Customer> _customers = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 0;
  int _total = 0;
  static const _pageSize = 20;
  bool get _hasMore => _customers.length < _total;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _fetch(reset: true);
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
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _fetch({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 0;
      });
    }
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getCustomerList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
          'pageIndex': reset ? 0 : _page,
          'pageSize': _pageSize,
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
      setState(() {
        _customers = reset ? data : [..._customers, ...data];
        _total = total;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() {
      _loadingMore = true;
      _page++;
    });
    await _fetch(reset: false);
  }

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sc) => Material(
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _fetch(reset: true),
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
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: _loading
                  ? const Center(child: DotsLoading())
                  : _error != null
                      ? Center(child: Text('Error: $_error'))
                      : ListView.builder(
                          controller: _scrollCtrl,
                          itemCount: _customers.length +
                              (_loadingMore ? 1 : 0),
                          itemBuilder: (ctx, i) {
                            if (i == _customers.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: DotsLoading()),
                              );
                            }
                            final c = _customers[i];
                            return ListTile(
                              title: Text(c.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500)),
                              subtitle: Text(c.customerCode,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary)),
                              trailing: const Icon(Icons.chevron_right,
                                  size: 18),
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
        color:
            Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}
