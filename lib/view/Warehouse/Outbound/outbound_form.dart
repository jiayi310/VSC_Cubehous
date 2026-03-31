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
import '../../../models/sales.dart';
import '../../../models/shipping_method.dart';
import '../../../models/stock.dart';
import '../../Common/decoration.dart';
import '../../Common/Stock/item_picker_page.dart';

class OutboundFormPage extends StatefulWidget {
  const OutboundFormPage({super.key});

  @override
  State<OutboundFormPage> createState() => _OutboundFormPageState();
}

class _OutboundFormPageState extends State<OutboundFormPage> {
  String _apiKey        = '';
  String _companyGUID   = '';
  int    _userID        = 0;
  String _userSessionID = '';

  bool _loading = true;
  bool _saving  = false;
  bool _showImage = true;

  final _formScrollCtrl = ScrollController();

  // ── Section expand state ──────────────────────────────────────────────
  bool _docExpanded   = true;
  bool _notesExpanded = true;
  bool _itemsExpanded = true;

  // ── Document fields ───────────────────────────────────────────────────
  String?          _docType;
  DateTime         _docDate = DateTime.now();
  SalesListItem?   _selectedSO;
  bool             _isLoadingSO = false;
  final _refDocNoCtrl = TextEditingController();

  // ── Notes fields ──────────────────────────────────────────────────────
  final _descriptionCtrl      = TextEditingController();
  final _remarksCtrl          = TextEditingController();
  final _shippingRefNoCtrl    = TextEditingController();
  ShippingMethod?  _selectedShippingMethod;
  List<ShippingMethod> _shippingMethods = [];

  // ── Line items ────────────────────────────────────────────────────────
  final List<_LineItem> _lines = [];

  late NumberFormat _qtyFmt;
  final _dateFmt = DateFormat('dd MMM yyyy');

  static const _docTypes = [
    ('Picking',  Icons.content_cut_outlined),
    ('Packing',  Icons.inventory_2_outlined),
    ('Transfer', Icons.swap_horiz_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _formScrollCtrl.dispose();
    _refDocNoCtrl.dispose();
    _descriptionCtrl.dispose();
    _remarksCtrl.dispose();
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
    ]);
    _apiKey        = results[0] as String;
    _companyGUID   = results[1] as String;
    _userID        = results[2] as int;
    _userSessionID = results[3] as String;
    _showImage     = (results[4] as String) == 'show';
    final dp = results[5] as int;
    _qtyFmt = NumberFormat('#,##0.${'0' * dp}');
    if (mounted) setState(() => _loading = false);
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
      _docType != null ||
      _lines.isNotEmpty ||
      _selectedSO != null ||
      _refDocNoCtrl.text.isNotEmpty ||
      _descriptionCtrl.text.isNotEmpty ||
      _remarksCtrl.text.isNotEmpty ||
      _shippingRefNoCtrl.text.isNotEmpty ||
      _selectedShippingMethod != null;

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
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
              const Text('Discard changes?',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'You have unsaved changes. Do you want to discard them?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: cs.onSurface.withValues(alpha: 0.6),
                      height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
              Divider(
                  height: 1,
                  color: cs.outline.withValues(alpha: 0.15)),
              IntrinsicHeight(
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(20))),
                        ),
                        onPressed: () => Navigator.pop(ctx, 'cancel'),
                        child: Text('Cancel',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: cs.onSurface
                                    .withValues(alpha: 0.5))),
                      ),
                    ),
                    VerticalDivider(
                        width: 1,
                        color: cs.outline.withValues(alpha: 0.15)),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                  bottomRight: Radius.circular(20))),
                        ),
                        onPressed: () => Navigator.pop(ctx, 'discard'),
                        child: const Text('Discard',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.red)),
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
    return result == 'discard';
  }

  Future<void> _save() async {
    if (_docType == null) {
      _showError('Please select a document type');
      return;
    }
    if (_docType == 'Packing' && _selectedSO == null) {
      _showError('Please select a sales order');
      return;
    }
    if (_lines.isEmpty) {
      _showError('Please add at least one item');
      return;
    }
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Outbound API not yet available'),
        behavior: SnackBarBehavior.floating,
      ),
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

  Future<void> _pickDocType() async {
    final cs = Theme.of(context).colorScheme;
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.35,
        minChildSize: 0.25,
        maxChildSize: 0.5,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text('Document Type',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                controller: sc,
                children: _docTypes.map((t) {
                  final selected = _docType == t.$1;
                  return ListTile(
                    leading: Icon(t.$2,
                        color: selected
                            ? cs.primary
                            : cs.onSurface.withValues(alpha: 0.5)),
                    title: Text(t.$1,
                        style: TextStyle(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400)),
                    trailing: selected
                        ? Icon(Icons.check, color: cs.primary)
                        : null,
                    onTap: () => Navigator.pop(ctx, t.$1),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    final changed = picked != _docType;
    setState(() {
      _docType = picked;
      if (changed) {
        _selectedSO = null;
        _selectedShippingMethod = null;
        _shippingRefNoCtrl.clear();
      }
    });
    if (picked == 'Packing') _loadShippingMethods();
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

  Future<void> _openSOPicker() async {
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
    if (so != null && mounted) {
      setState(() {
        _selectedSO = so;
        _isLoadingSO = false;
      });
    }
  }

  Future<void> _pickShippingMethod() async {
    if (_shippingMethods.isEmpty) return;
    final cs = Theme.of(context).colorScheme;
    final picked = await showModalBottomSheet<ShippingMethod>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.4,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (_, sc) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text('Shipping Method',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
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
                        ? Icon(Icons.check, color: cs.primary)
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

  Future<void> _addLine() async {
    final picked = await Navigator.push<Stock>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemPickerPage(
          module: 'OUTBOUND',
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (picked != null && mounted) {
      final line = _LineItem()
        ..stockID = picked.stockID
        ..stockCode = picked.stockCode
        ..uom = picked.baseUOM
        ..itemImage = picked.image
        ..descriptionCtrl.text = picked.description;
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

  Future<void> _pickItem(int index) async {
    final picked = await Navigator.push<Stock>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemPickerPage(
          module: 'OUTBOUND',
          apiKey: _apiKey,
          companyGUID: _companyGUID,
          userID: _userID,
          userSessionID: _userSessionID,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        final l = _lines[index];
        l.stockID = picked.stockID;
        l.stockCode = picked.stockCode;
        l.uom = picked.baseUOM;
        l.itemImage = picked.image;
        l.descriptionCtrl.text = picked.description;
      });
    }
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
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
            child: const Text('New Outbound',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: DotsLoading())
            : Column(
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
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: _docExpanded
                                ? _buildDocSection()
                                : const SizedBox.shrink(),
                          ),

                          // ── Notes ─────────────────────────────────
                          FormSectionHeader(
                            icon: Icons.notes_outlined,
                            title: 'Notes',
                            expanded: _notesExpanded,
                            onToggle: () => setState(
                                () => _notesExpanded = !_notesExpanded),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            child: _notesExpanded
                                ? _buildNotesSection()
                                : const SizedBox.shrink(),
                          ),

                          // ── Items ─────────────────────────────────
                          FormSectionHeader(
                            icon: Icons.list_alt_outlined,
                            title: 'Items',
                            expanded: _itemsExpanded,
                            onToggle: () => setState(
                                () => _itemsExpanded = !_itemsExpanded),
                            badge: '${_lines.length}',
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
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
                  // ── Save button ───────────────────────────────────
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const DotsLoading()
                            : const Text('Save',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Document section ──────────────────────────────────────────────────

  Widget _buildDocSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Doc Type
        FieldLabel(label: 'Document Type *'),
        InkWell(
          onTap: _pickDocType,
          borderRadius: BorderRadius.circular(12),
          child: FieldBox(
            child: Row(
              children: [
                const Icon(Icons.local_shipping_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: _docType == null
                      ? Text('Select document type',
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4)))
                      : Text(_docType!,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                ),
                if (_docType != null)
                  GestureDetector(
                    onTap: () => setState(() {
                      _docType = null;
                      _selectedSO = null;
                      _selectedShippingMethod = null;
                      _shippingRefNoCtrl.clear();
                    }),
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
        const SizedBox(height: 12),

        // Sales Order — only for Packing
        if (_docType == 'Packing') ...[
          FieldLabel(label: 'Sales Order *'),
          InkWell(
            onTap: _isLoadingSO ? null : _openSOPicker,
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
                              ? Text('Select sales order',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.4)))
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(_selectedSO!.docNo,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary)),
                                    Text(_selectedSO!.customerName,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                        ),
                        if (_selectedSO != null)
                          GestureDetector(
                            onTap: () =>
                                setState(() => _selectedSO = null),
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
          const SizedBox(height: 12),
        ],

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

        // Ref Doc No
        FieldLabel(label: 'Reference Doc No'),
        TextFormField(
          controller: _refDocNoCtrl,
          style: const TextStyle(fontSize: 14),
          decoration: formInputDeco(context),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Notes section ─────────────────────────────────────────────────────

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
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        FieldLabel(label: 'Remark'),
        TextFormField(
          controller: _remarksCtrl,
          maxLines: 1,
          style: const TextStyle(fontSize: 14),
          decoration: formInputDeco(context),
          onChanged: (_) => setState(() {}),
        ),

        // Shipping fields — only for Packing
        if (_docType == 'Packing') ...[
          const SizedBox(height: 12),
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
                        ? Text('Select shipping method',
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.4)))
                        : Text(_selectedShippingMethod!.description,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                  ),
                  if (_selectedShippingMethod != null)
                    GestureDetector(
                      onTap: () => setState(
                          () => _selectedShippingMethod = null),
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
          const SizedBox(height: 12),
          FieldLabel(label: 'Shipping Reference No'),
          TextFormField(
            controller: _shippingRefNoCtrl,
            maxLines: 1,
            style: const TextStyle(fontSize: 14),
            decoration: formInputDeco(context),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 4),
      ],
    );
  }

  // ── Items section ─────────────────────────────────────────────────────

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlidableAutoCloseBehavior(
          child: Column(
            children: _lines
                .asMap()
                .entries
                .map((e) => _LineItemCard(
                      key: ValueKey(e.key),
                      index: e.key,
                      item: e.value,
                      qtyFmt: _qtyFmt,
                      showImage: _showImage,
                      onRemove: () => _removeLine(e.key),
                      onChanged: () => setState(() {}),
                      onPickItem: () => _pickItem(e.key),
                      apiKey: _apiKey,
                      companyGUID: _companyGUID,
                      userID: _userID,
                      userSessionID: _userSessionID,
                    ))
                .toList(),
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
  int _totalPages  = 1;
  int _totalCount  = 0;
  final int _pageSize = 20;

  String _sortBy  = 'DocDate';
  bool   _sortAsc = false;

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
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
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
                      width: 40, height: 4,
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
    final start = _currentPage * _pageSize + 1;
    final end =
        ((_currentPage + 1) * _pageSize).clamp(0, _totalCount);
    final dateFmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Sales Order',
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
                      hintText: 'Search by SO no. or customer...',
                      prefixIcon:
                          const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear,
                                  size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _fetch(page: 0);
                              })
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 10),
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
                                'No sales orders available',
                                style: TextStyle(
                                    color: cs.onSurface
                                        .withValues(alpha: 0.4)),
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
                                                .withValues(
                                                    alpha: 0.5)),
                                      ),
                                    ),
                                  );
                                }
                                final so = _items[i];
                                DateTime? d;
                                try {
                                  d = DateTime.parse(so.docDate);
                                } catch (_) {}
                                return InkWell(
                                  onTap: () =>
                                      Navigator.pop(context, so),
                                  child: Container(
                                    padding: const EdgeInsets
                                        .symmetric(
                                        horizontal: 16,
                                        vertical: 12),
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
                                          width: 40, height: 40,
                                          decoration: BoxDecoration(
                                            color: primary
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                              Icons.receipt_outlined,
                                              size: 20,
                                              color: primary),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(so.docNo,
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: primary)),
                                              const SizedBox(height: 2),
                                              Text(so.customerName,
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (d != null)
                                          Text(
                                            dateFmt.format(d),
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: cs.onSurface
                                                    .withValues(
                                                        alpha: 0.5)),
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

// ─────────────────────────────────────────────────────────────────────
// Line item model
// ─────────────────────────────────────────────────────────────────────

class _LineItem {
  int stockID = 0;
  String stockCode = '';
  String uom = '';
  String? itemImage;
  final descriptionCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '1');

  double get qty => double.tryParse(qtyCtrl.text) ?? 0;

  void dispose() {
    descriptionCtrl.dispose();
    qtyCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Line item card
// ─────────────────────────────────────────────────────────────────────

class _LineItemCard extends StatefulWidget {
  final int index;
  final _LineItem item;
  final NumberFormat qtyFmt;
  final bool showImage;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final VoidCallback onPickItem;
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  const _LineItemCard({
    super.key,
    required this.index,
    required this.item,
    required this.qtyFmt,
    required this.showImage,
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
  double? _pointerDownX;
  double? _pointerDownY;
  late final VoidCallback _rebuildListener;

  @override
  void initState() {
    super.initState();
    _rebuildListener = () {
      if (mounted) setState(() {});
    };
    widget.item.qtyCtrl.addListener(_rebuildListener);
    widget.item.descriptionCtrl.addListener(_rebuildListener);
  }

  @override
  void dispose() {
    widget.item.qtyCtrl.removeListener(_rebuildListener);
    widget.item.descriptionCtrl.removeListener(_rebuildListener);
    super.dispose();
  }

  void _openEditSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LineItemEditSheet(
        item: widget.item,
        onChanged: () {
          widget.onChanged();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Widget _indexBadge(Color primary) => Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${widget.index + 1}',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primary),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;
    final item = widget.item;

    Widget leading;
    if (widget.showImage &&
        item.itemImage != null &&
        item.itemImage!.isNotEmpty) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 50, height: 50,
          child: ItemImage(base64: item.itemImage),
        ),
      );
    } else {
      leading = _indexBadge(primary);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
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
              if (dx > 280 && dy < 40) widget.onPickItem();
            }
          },
          child: Slidable(
            key: widget.key,
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.48,
              children: [
                CustomSlidableAction(
                  onPressed: (_) => _openEditSheet(),
                  backgroundColor:
                      const Color(0xFF1565C0).withValues(alpha: 0.12),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline,
                          size: 26, color: Colors.red),
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
              onTap: _openEditSheet,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: (Theme.of(context).cardTheme.color ??
                          cs.surface)
                      .withValues(alpha: 0.5),
                  border: Border.all(
                      color: cs.outline.withValues(alpha: 0.18)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: stockCode | qty
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.center,
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
                              Text(
                                'x ${widget.qtyFmt.format(item.qty)}',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primary),
                              ),
                            ],
                          ),
                          // Row 2: description
                          const SizedBox(height: 2),
                          Text(
                            item.descriptionCtrl.text,
                            style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface
                                    .withValues(alpha: 0.65)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Row 3: UOM
                          Text(
                            item.uom,
                            style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface
                                    .withValues(alpha: 0.5)),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Line item edit sheet
// ─────────────────────────────────────────────────────────────────────

class _LineItemEditSheet extends StatefulWidget {
  final _LineItem item;
  final VoidCallback onChanged;

  const _LineItemEditSheet({
    required this.item,
    required this.onChanged,
  });

  @override
  State<_LineItemEditSheet> createState() => _LineItemEditSheetState();
}

class _LineItemEditSheetState extends State<_LineItemEditSheet> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _descCtrl;
  int _qtyDp = 2;

  @override
  void initState() {
    super.initState();
    _qtyCtrl  = TextEditingController(text: widget.item.qtyCtrl.text);
    _descCtrl =
        TextEditingController(text: widget.item.descriptionCtrl.text);
    _qtyCtrl.addListener(() => setState(() {}));
    _loadDp();
  }

  Future<void> _loadDp() async {
    final dp = await SessionManager.getQuantityDecimalPoint();
    if (!mounted) return;
    setState(() => _qtyDp = dp);
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  double get _qty => double.tryParse(_qtyCtrl.text) ?? 0;

  void _stepQty(int delta) {
    final next = (_qty + delta).clamp(1.0, double.infinity);
    _qtyCtrl.text = next.toStringAsFixed(_qtyDp);
  }

  void _apply() {
    widget.item.qtyCtrl.text = _qtyCtrl.text;
    widget.item.descriptionCtrl.text = _descCtrl.text;
    widget.onChanged();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.stockCode,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: cs.primary)),
                    Text(widget.item.descriptionCtrl.text,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface
                                .withValues(alpha: 0.55)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              TextButton(
                onPressed: _apply,
                child: const Text('Apply',
                    style:
                        TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          SheetSection(label: 'Quantity'),
          Row(
            children: [
              GestureDetector(
                onTap: () => _stepQty(-1),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.remove, size: 20, color: cs.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[\d.]'))
                  ],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                  decoration: sheetInputDeco(context),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _stepQty(1),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add, size: 20, color: cs.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SheetSection(label: 'Description'),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 14),
            decoration: sheetInputDeco(context),
          ),
        ],
      ),
    );
  }
}
