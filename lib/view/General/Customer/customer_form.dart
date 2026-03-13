import 'package:flutter/material.dart';
import '../../../api/api_endpoints.dart';
import '../../../api/base_client.dart';
import '../../../common/dots_loading.dart';
import '../../../common/session_manager.dart';
import '../../../models/customer.dart';
import '../../../models/customer_type.dart';
import '../../../models/SalesAgent.dart';

class CustomerFormPage extends StatefulWidget {
  /// Null = create mode, non-null = edit mode
  final Customer? customer;

  const CustomerFormPage({super.key, this.customer});

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  bool get _isEdit => widget.customer != null;

  // Session
  String _apiKey = '';
  String _companyGUID = '';
  int _userID = 0;
  String _userSessionID = '';

  // Dropdown data
  List<CustomerType> _customerTypes = [];
  List<SalesAgent> _salesAgents = [];
  bool _loadingDropdowns = true;

  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _customerCodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _name2Ctrl = TextEditingController();
  final _addr1Ctrl = TextEditingController();
  final _addr2Ctrl = TextEditingController();
  final _addr3Ctrl = TextEditingController();
  final _addr4Ctrl = TextEditingController();
  final _postCodeCtrl = TextEditingController();
  final _delAddr1Ctrl = TextEditingController();
  final _delAddr2Ctrl = TextEditingController();
  final _delAddr3Ctrl = TextEditingController();
  final _delAddr4Ctrl = TextEditingController();
  final _delPostCodeCtrl = TextEditingController();
  final _attentionCtrl = TextEditingController();
  final _phone1Ctrl = TextEditingController();
  final _phone2Ctrl = TextEditingController();
  final _fax1Ctrl = TextEditingController();
  final _fax2Ctrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  int _priceCategory = 1;
  int? _selectedCustomerTypeID;
  int? _selectedSalesAgentID;
  bool _isSaving = false;
  bool _sameAsBilling = false;

  @override
  void initState() {
    super.initState();
    _prefillIfEdit();
    _init();
  }

  void _prefillIfEdit() {
    final c = widget.customer;
    if (c == null) return;
    _customerCodeCtrl.text = c.customerCode;
    _nameCtrl.text = c.name;
    _name2Ctrl.text = c.name2;
    _addr1Ctrl.text = c.address1 ?? '';
    _addr2Ctrl.text = c.address2 ?? '';
    _addr3Ctrl.text = c.address3 ?? '';
    _addr4Ctrl.text = c.address4 ?? '';
    _postCodeCtrl.text = c.postCode ?? '';
    _delAddr1Ctrl.text = c.deliverAddr1 ?? '';
    _delAddr2Ctrl.text = c.deliverAddr2 ?? '';
    _delAddr3Ctrl.text = c.deliverAddr3 ?? '';
    _delAddr4Ctrl.text = c.deliverAddr4 ?? '';
    _delPostCodeCtrl.text = c.deliverPostCode ?? '';
    _attentionCtrl.text = c.attention ?? '';
    _phone1Ctrl.text = c.phone1 ?? '';
    _phone2Ctrl.text = c.phone2 ?? '';
    _fax1Ctrl.text = c.fax1 ?? '';
    _fax2Ctrl.text = c.fax2 ?? '';
    _emailCtrl.text = c.email ?? '';
    _priceCategory = c.priceCategory.clamp(1, 6);
    _selectedCustomerTypeID = c.customerTypeID;
    _selectedSalesAgentID = c.salesAgentID;
  }

  Future<void> _init() async {
    _apiKey = await SessionManager.getApiKey();
    _companyGUID = await SessionManager.getCompanyGUID();
    _userID = await SessionManager.getUserID();
    _userSessionID = await SessionManager.getUserSessionID();
    await _loadDropdowns();
  }

  List<Map<String, dynamic>> _toMapList(dynamic raw) {
    if (raw is List<dynamic>) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    if (raw is Map<String, dynamic>) {
      final data = raw['data'];
      if (data is List<dynamic>) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
    }
    return [];
  }

  Future<void> _loadDropdowns() async {
    try {
      final body = {'apiKey': _apiKey, 'companyGUID': _companyGUID,'userID': _userID,'userSessionID': _userSessionID,};
      final results = await Future.wait([
        BaseClient.post(ApiEndpoints.getCustomerTypeList, body: body),
        BaseClient.post(ApiEndpoints.getSalesAgentList, body: body),
      ]);
      setState(() {
        _customerTypes = _toMapList(results[0])
            .map(CustomerType.fromJson)
            .toList();
        _salesAgents = _toMapList(results[1])
            .map(SalesAgent.fromJson)
            .toList();
        _loadingDropdowns = false;
      });
    } catch (_) {
      setState(() => _loadingDropdowns = false);
    }
  }

  void _onSameAsBillingChanged(bool? value) {
    setState(() {
      _sameAsBilling = value ?? false;
      if (_sameAsBilling) {
        _delAddr1Ctrl.text = _addr1Ctrl.text;
        _delAddr2Ctrl.text = _addr2Ctrl.text;
        _delAddr3Ctrl.text = _addr3Ctrl.text;
        _delAddr4Ctrl.text = _addr4Ctrl.text;
        _delPostCodeCtrl.text = _postCodeCtrl.text;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final customerForm = {
        'customerCode': _customerCodeCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'name2': _name2Ctrl.text.trim(),
        'address1': _addr1Ctrl.text.trim(),
        'address2': _addr2Ctrl.text.trim(),
        'address3': _addr3Ctrl.text.trim(),
        'address4': _addr4Ctrl.text.trim(),
        'postCode': _postCodeCtrl.text.trim(),
        'deliverAddr1': _delAddr1Ctrl.text.trim(),
        'deliverAddr2': _delAddr2Ctrl.text.trim(),
        'deliverAddr3': _delAddr3Ctrl.text.trim(),
        'deliverAddr4': _delAddr4Ctrl.text.trim(),
        'deliverPostCode': _delPostCodeCtrl.text.trim(),
        'attention': _attentionCtrl.text.trim(),
        'phone1': _phone1Ctrl.text.trim(),
        'phone2': _phone2Ctrl.text.trim(),
        'fax1': _fax1Ctrl.text.trim(),
        'fax2': _fax2Ctrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'priceCategory': _priceCategory,
        'customerTypeID': _selectedCustomerTypeID,
        'salesAgentID': _selectedSalesAgentID,
        if (_isEdit) 'customerID': widget.customer!.customerID,
      };

      await BaseClient.post(
        _isEdit ? ApiEndpoints.updateCustomer : ApiEndpoints.createCustomer,
        body: {
          'apiKey': _apiKey,
          'companyGUID': _companyGUID,
          'userID': _userID,
          'userSessionID': _userSessionID,
          'customerForm': customerForm,
        },
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _customerCodeCtrl, _nameCtrl, _name2Ctrl, _addr1Ctrl, _addr2Ctrl,
      _addr3Ctrl, _addr4Ctrl, _postCodeCtrl, _delAddr1Ctrl, _delAddr2Ctrl,
      _delAddr3Ctrl, _delAddr4Ctrl, _delPostCodeCtrl, _attentionCtrl,
      _phone1Ctrl, _phone2Ctrl, _fax1Ctrl, _fax2Ctrl, _emailCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Edit Customer' : 'New Customer',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: DotsLoading(dotSize: 6),
            )
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
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Basic Info ──────────────────────────
                    _sectionHeader(Icons.person_outline, 'Basic Info'),
                    _field(
                      controller: _customerCodeCtrl,
                      label: 'Customer Code',
                      hint: 'e.g. CUST001',
                      required: true,
                      readOnly: _isEdit,
                    ),
                    _gap,
                    _field(
                      controller: _nameCtrl,
                      label: 'Name',
                      required: true,
                    ),
                    _gap,
                    _field(
                      controller: _name2Ctrl,
                      label: 'Name 2',
                    ),

                    // ── Contact ─────────────────────────────
                    _sectionHeader(Icons.contact_phone_outlined, 'Contact'),
                    _field(controller: _attentionCtrl, label: 'Attention to'),
                    _gap,
                    Row(
                      children: [
                        Expanded(
                            child: _field(
                                controller: _phone1Ctrl,
                                label: 'Phone 1',
                                keyboard: TextInputType.phone)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _field(
                                controller: _phone2Ctrl,
                                label: 'Phone 2',
                                keyboard: TextInputType.phone)),
                      ],
                    ),
                    _gap,
                    Row(
                      children: [
                        Expanded(
                            child: _field(
                                controller: _fax1Ctrl,
                                label: 'Fax 1',
                                keyboard: TextInputType.phone)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _field(
                                controller: _fax2Ctrl,
                                label: 'Fax 2',
                                keyboard: TextInputType.phone)),
                      ],
                    ),
                    _gap,
                    _field(
                      controller: _emailCtrl,
                      label: 'Email',
                      keyboard: TextInputType.emailAddress,
                    ),

                    // ── Billing Address ─────────────────────
                    _sectionHeader(Icons.home_outlined, 'Billing Address'),
                    _field(controller: _addr1Ctrl, label: 'Address Line 1'),
                    _gap,
                    _field(controller: _addr2Ctrl, label: 'Address Line 2'),
                    _gap,
                    _field(controller: _addr3Ctrl, label: 'Address Line 3'),
                    _gap,
                    _field(controller: _addr4Ctrl, label: 'Address Line 4'),
                    _gap,
                    _field(
                      controller: _postCodeCtrl,
                      label: 'Post Code',
                      keyboard: TextInputType.number,
                    ),

                    // ── Delivery Address ────────────────────
                    _deliveryAddressHeader(),
                    _field(
                        controller: _delAddr1Ctrl, label: 'Address Line 1', readOnly: _sameAsBilling),
                    _gap,
                    _field(
                        controller: _delAddr2Ctrl, label: 'Address Line 2', readOnly: _sameAsBilling),
                    _gap,
                    _field(
                        controller: _delAddr3Ctrl, label: 'Address Line 3', readOnly: _sameAsBilling),
                    _gap,
                    _field(
                        controller: _delAddr4Ctrl, label: 'Address Line 4', readOnly: _sameAsBilling),
                    _gap,
                    _field(
                      controller: _delPostCodeCtrl,
                      label: 'Post Code',
                      keyboard: TextInputType.number,
                      readOnly: _sameAsBilling,
                    ),

                    // ── Classification ──────────────────────
                    _sectionHeader(Icons.category_outlined, 'Others'),
                    _dropdown<int>(
                      label: 'Customer Type',
                      value: _selectedCustomerTypeID,
                      items: _customerTypes
                          .map((t) => DropdownMenuItem(
                              value: t.customerTypeID,
                              child: Text(t.customerType)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedCustomerTypeID = v),
                    ),
                    _gap,
                    _dropdown<int>(
                      label: 'Sales Agent',
                      value: _selectedSalesAgentID,
                      items: _salesAgents
                          .map((a) => DropdownMenuItem(
                              value: a.salesAgentID,
                              child: Text(a.name ?? '')))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedSalesAgentID = v),
                    ),
                    _gap,
                    _priceCategoryField(),

                    const SizedBox(height: 38),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _save,
                        child: Text(
                          _isEdit ? 'Save Changes' : 'Create Customer',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  static const _gap = SizedBox(height: 12);

  Widget _deliveryAddressHeader() {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, size: 16, color: primary),
          const SizedBox(width: 6),
          Text(
            'Delivery Address',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: primary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: primary.withValues(alpha: 0.2), thickness: 1),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _onSameAsBillingChanged(!_sameAsBilling),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _sameAsBilling,
                    onChanged: _onSameAsBillingChanged,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Same as Billing',
                  style: TextStyle(fontSize: 12, color: primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: primary,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: primary.withValues(alpha: 0.2),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    bool readOnly = false,
    TextInputType keyboard = TextInputType.text,
    IconData? prefixIcon,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
          fontSize: 14,
        ),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
        filled: true,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 1.5,
          ),
        ),
        suffixIcon: readOnly
            ? Icon(Icons.lock_outline,
                size: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3))
            : null,
      ),
      validator: required
          ? (v) =>
              (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1.5,
          ),
        ),
      ),
      items: [
        DropdownMenuItem<T>(
          value: null,
          child: Text(
            '—',
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.35),
              fontSize: 14,
            ),
          ),
        ),
        ...items.map((item) => DropdownMenuItem<T>(
              value: item.value,
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                child: item.child,
              ),
            )),
      ],
      onChanged: onChanged,
      style: TextStyle(
        fontSize: 14,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _priceCategoryField() {
    final primary = Theme.of(context).colorScheme.primary;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Category',
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(6, (i) {
            final cat = i + 1;
            final selected = _priceCategory == cat;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _priceCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: EdgeInsets.only(right: i < 5 ? 6 : 0),
                  height: 44,
                  decoration: BoxDecoration(
                    color: selected
                        ? primary
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '$cat',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : cs.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
