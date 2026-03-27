import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/date_pill.dart';
import 'inbound_form.dart';

class InboundListPage extends StatefulWidget {
  const InboundListPage({super.key});

  @override
  State<InboundListPage> createState() => _InboundListPageState();
}

class _InboundListPageState extends State<InboundListPage> {
  final _searchCtrl = TextEditingController();
  bool _searchActive = false;

  String _fromDate = '';
  String _toDate = '';
  String _docTypeFilter = 'All';

  final _dateFmt = DateFormat('dd MMM yyyy');

  static const _docTypeFilters = ['All', 'GRN', 'PUT'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    final formatted = _dateFmt.format(picked);
    setState(() {
      if (isFrom) {
        _fromDate = formatted;
      } else {
        _toDate = formatted;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final primary = cs.primary;

    return Scaffold(
      appBar: AppBar(
        title: _searchActive
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search doc no...',
                  border: InputBorder.none,
                ),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Inbound',
                style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: !_searchActive,
        actions: [
          IconButton(
            icon: Icon(_searchActive ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searchActive = !_searchActive;
              if (!_searchActive) _searchCtrl.clear();
            }),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Inbound',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InboundFormPage()),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DatePill(
                    label: 'From',
                    date: _fromDate.isEmpty ? 'All dates' : _fromDate,
                    onTap: () => _pickDate(isFrom: true),
                    primary: primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DatePill(
                    label: 'To',
                    date: _toDate.isEmpty ? 'All dates' : _toDate,
                    onTap: () => _pickDate(isFrom: false),
                    primary: primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ── DocType filter chips ──────────────────────────────────
          Container(
            height: 46,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: cs.outline.withValues(alpha: 0.12)),
              ),
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              itemCount: _docTypeFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final t = _docTypeFilters[i];
                final selected = _docTypeFilter == t;
                return FilterChip(
                  label: Text(t,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal)),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _docTypeFilter = t),
                  selectedColor: primary.withValues(alpha: 0.12),
                  checkmarkColor: primary,
                  side: BorderSide(
                      color: selected
                          ? primary
                          : cs.outline.withValues(alpha: 0.35)),
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),

          // ── List ─────────────────────────────────────────────────
          Expanded(child: _buildBody(cs, primary)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, Color primary) {
    // No API yet — empty state
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.move_to_inbox_outlined,
                size: 56,
                color: cs.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 14),
            Text(
              'No inbound documents',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to create a new inbound document',
              style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.3)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Inbound tile (ready for when API is wired up) ─────────────────────

class InboundTile extends StatelessWidget {
  final String docNo;
  final String docDate;
  final String docType;   // 'GRN' | 'PUT'
  final String refDocNo;
  final String status;
  final VoidCallback onTap;

  const InboundTile({
    super.key,
    required this.docNo,
    required this.docDate,
    required this.docType,
    required this.refDocNo,
    required this.status,
    required this.onTap,
  });

  static Color _typeColor(String type) {
    switch (type) {
      case 'GRN':
        return const Color(0xFF1565C0);
      case 'PUT':
        return const Color(0xFF00695C);
      default:
        return const Color(0xFF546E7A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final typeColor = _typeColor(docType);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: cs.outline.withValues(alpha: 0.1)),
          ),
        ),
        child: Row(
          children: [
            // DocType badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                docType,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: typeColor,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Doc info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(docNo,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  if (refDocNo.isNotEmpty)
                    Text(refDocNo,
                        style: TextStyle(
                            fontSize: 12,
                            color:
                                cs.onSurface.withValues(alpha: 0.5))),
                ],
              ),
            ),
            // Date + status
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(docDate,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 4),
                _StatusBadge(status: status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        color = Colors.green;
      case 'VOID':
        color = Colors.red;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        status,
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.3),
      ),
    );
  }
}
