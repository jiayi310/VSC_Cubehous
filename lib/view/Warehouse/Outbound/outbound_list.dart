import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/date_pill.dart';
import 'outbound_form.dart';

class OutboundListPage extends StatefulWidget {
  const OutboundListPage({super.key});

  @override
  State<OutboundListPage> createState() => _OutboundListPageState();
}

class _OutboundListPageState extends State<OutboundListPage> {
  final _searchCtrl = TextEditingController();
  bool _searchActive = false;

  String _fromDate = '';
  String _toDate = '';
  String _docTypeFilter = 'All';

  final _dateFmt = DateFormat('dd MMM yyyy');

  static const _docTypeFilters = ['All', 'PICK', 'PACK', 'SHIP'];

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
    const outboundColor = Color(0xFFE65100);

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
            : const Text('Outbound',
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
            tooltip: 'New Outbound',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OutboundFormPage()),
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
                  selectedColor: outboundColor.withValues(alpha: 0.12),
                  checkmarkColor: outboundColor,
                  side: BorderSide(
                      color: selected
                          ? outboundColor
                          : cs.outline.withValues(alpha: 0.35)),
                  backgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ),

          // ── List ─────────────────────────────────────────────────
          Expanded(child: _buildBody(cs)),
        ],
      ),
    );
  }

  Widget _buildBody(ColorScheme cs) {
    // No API yet — empty state
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.outbox_outlined,
                size: 56,
                color: cs.onSurface.withValues(alpha: 0.15)),
            const SizedBox(height: 14),
            Text(
              'No outbound documents',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to create a new outbound document',
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

// ── Outbound tile (ready for when API is wired up) ─────────────────────

class OutboundTile extends StatelessWidget {
  final String docNo;
  final String docDate;
  final String docType;   // 'PICK' | 'PACK' | 'SHIP'
  final String refDocNo;
  final String customerName;
  final String status;
  final VoidCallback onTap;

  const OutboundTile({
    super.key,
    required this.docNo,
    required this.docDate,
    required this.docType,
    required this.refDocNo,
    required this.customerName,
    required this.status,
    required this.onTap,
  });

  static Color _typeColor(String type) {
    switch (type) {
      case 'PICK':
        return const Color(0xFFE65100);
      case 'PACK':
        return const Color(0xFF6A1B9A);
      case 'SHIP':
        return const Color(0xFF00838F);
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
                  if (customerName.isNotEmpty)
                    Text(customerName,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.7)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  if (refDocNo.isNotEmpty)
                    Text(refDocNo,
                        style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.45))),
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
      case 'SHIPPED':
        color = const Color(0xFF00838F);
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
