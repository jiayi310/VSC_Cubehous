import 'package:flutter/material.dart';
import '../../api/api_endpoints.dart';
import '../../api/base_client.dart';
import '../../common/dots_loading.dart';
import '../../models/sales_agent.dart';
import 'customer_picker_page.dart' show PickerDirChip;

// ─────────────────────────────────────────────────────────────────────
// Sales agent picker page
// ─────────────────────────────────────────────────────────────────────

class SalesAgentPickerPage extends StatefulWidget {
  final String apiKey;
  final String companyGUID;
  final int userID;
  final String userSessionID;

  const SalesAgentPickerPage({
    super.key,
    required this.apiKey,
    required this.companyGUID,
    required this.userID,
    required this.userSessionID,
  });

  @override
  State<SalesAgentPickerPage> createState() => _SalesAgentPickerPageState();
}

class _SalesAgentPickerPageState extends State<SalesAgentPickerPage> {
  final _searchCtrl = TextEditingController();
  List<SalesAgent> _all = [];
  List<SalesAgent> _filtered = [];
  bool _loading = true;
  String? _error;

  String _sortBy = 'Name';
  bool _sortAsc = true;

  bool get _activeSort => _sortBy != 'Name' || !_sortAsc;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_applyFilter);
    _fetch();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    List<SalesAgent> result = q.isEmpty
        ? List.of(_all)
        : _all
            .where((a) =>
                (a.name ?? '').toLowerCase().contains(q) ||
                (a.description ?? '').toLowerCase().contains(q))
            .toList();

    result.sort((x, y) {
      int cmp;
      if (_sortBy == 'Description') {
        cmp = (x.description ?? '').compareTo(y.description ?? '');
      } else {
        cmp = (x.name ?? '').compareTo(y.name ?? '');
      }
      return _sortAsc ? cmp : -cmp;
    });

    setState(() => _filtered = result);
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final response = await BaseClient.post(
        ApiEndpoints.getSalesAgentList,
        body: {
          'apiKey': widget.apiKey,
          'companyGUID': widget.companyGUID,
          'userID': widget.userID,
          'userSessionID': widget.userSessionID,
        },
      );
      final data = (response as List<dynamic>)
          .map((e) => SalesAgent.fromJson(e as Map<String, dynamic>))
          .where((a) => a.isDisabled != true)
          .toList();
      setState(() {
        _all = data;
        _loading = false;
      });
      _applyFilter();
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AgentSortSheet(
        sortBy: _sortBy,
        sortAsc: _sortAsc,
        onApply: (sortBy, sortAsc) {
          setState(() { _sortBy = sortBy; _sortAsc = sortAsc; });
          _applyFilter();
        },
        onReset: () {
          setState(() { _sortBy = 'Name'; _sortAsc = true; });
          _applyFilter();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Sales Agent',
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
                    decoration: InputDecoration(
                      hintText: 'Search sales agent...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchCtrl.clear())
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showSortSheet,
                        child: const SizedBox(
                          width: 44, height: 44,
                          child: Icon(Icons.tune_outlined, size: 20),
                        ),
                      ),
                    ),
                    if (_activeSort)
                      Positioned(
                        top: 0, right: 0,
                        child: Container(
                          width: 10, height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
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
                      FilledButton(onPressed: _fetch, child: const Text('Retry')),
                    ],
                  ),
                )
              : _filtered.isEmpty
                  ? const Center(child: Text('No sales agents found'))
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (ctx, i) {
                        final a = _filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primary.withValues(alpha: 0.1),
                            child: Text(
                              (a.name ?? '?').isNotEmpty ? a.name![0].toUpperCase() : '?',
                              style: TextStyle(color: primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(a.name ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: (a.description ?? '').isNotEmpty
                              ? Text(a.description!, style: const TextStyle(fontSize: 12))
                              : null,
                          trailing: Icon(Icons.chevron_right,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                          onTap: () => Navigator.pop(context, a),
                        );
                      },
                    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sales agent sort sheet
// ─────────────────────────────────────────────────────────────────────

class _AgentSortSheet extends StatefulWidget {
  final String sortBy;
  final bool sortAsc;
  final void Function(String sortBy, bool sortAsc) onApply;
  final VoidCallback onReset;

  const _AgentSortSheet({
    required this.sortBy,
    required this.sortAsc,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_AgentSortSheet> createState() => _AgentSortSheetState();
}

class _AgentSortSheetState extends State<_AgentSortSheet> {
  late String _sortBy;
  late bool _sortAsc;

  static const _sortOptions = [
    ('Name', 'Name'),
    ('Description', 'Description'),
  ];

  @override
  void initState() {
    super.initState();
    _sortBy = widget.sortBy;
    _sortAsc = widget.sortAsc;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final surface = Theme.of(context).colorScheme.surface;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.7,
      expand: false,
      builder: (_, scrollCtrl) => Material(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
              child: Row(
                children: [
                  const Text('Sort', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  TextButton(
                    onPressed: () { Navigator.pop(context); widget.onReset(); },
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  Text('Sort By', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _sortBy,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: _sortOptions
                        .map((o) => DropdownMenuItem(value: o.$2, child: Text(o.$1)))
                        .toList(),
                    onChanged: (v) => setState(() => _sortBy = v!),
                  ),
                  const SizedBox(height: 16),
                  Text('Sort Direction', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: PickerDirChip(
                        label: 'Ascending', icon: Icons.arrow_upward_rounded,
                        selected: _sortAsc,
                        onTap: () => setState(() => _sortAsc = true),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: PickerDirChip(
                        label: 'Descending', icon: Icons.arrow_downward_rounded,
                        selected: !_sortAsc,
                        onTap: () => setState(() => _sortAsc = false),
                      )),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onApply(_sortBy, _sortAsc);
                      },
                      child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
