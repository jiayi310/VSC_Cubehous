import 'package:flutter/material.dart';
import '../../../models/suppplier.dart';

class SupplierDetailPage extends StatelessWidget {
  final Supplier supplier;

  const SupplierDetailPage({super.key, required this.supplier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Supplier',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _buildDetail(context),
    );
  }

  Widget _buildDetail(BuildContext context) {
    final s = supplier;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(context, s),
          const SizedBox(height: 16),

          // General
          _buildSection(context, 'General', [
            _buildRow(context, 'Supplier Code', s.supplierCode ?? '-'),
            _buildRow(context, 'Name', s.name ?? '-'),
            if ((s.name2 ?? '').isNotEmpty)
              _buildRow(context, 'Name 2', s.name2!),
            _buildRow(
              context,
              'Supplier Type',
              (s.supplierType?.description ?? '').isNotEmpty
                  ? s.supplierType!.description!
                  : '-',
            ),
          ]),
          const SizedBox(height: 16),

          // Contact
          _buildSection(context, 'Contact', [
            _buildRow(context, 'Phone 1', s.phone1 ?? '-'),
            _buildRow(context, 'Phone 2', s.phone2 ?? '-'),
            _buildRow(context, 'Fax 1', s.fax1 ?? '-'),
            _buildRow(context, 'Fax 2', s.fax2 ?? '-'),
            _buildRow(context, 'Email', s.email ?? '-'),
            _buildRow(context, 'Attention', s.attention ?? '-'),
          ]),
          const SizedBox(height: 16),

          // Address
          _buildSection(context, 'Address', [
            _buildRow(context, 'Address 1', s.address1 ?? '-'),
            _buildRow(context, 'Address 2', s.address2 ?? '-'),
            _buildRow(context, 'Address 3', s.address3 ?? '-'),
            _buildRow(context, 'Address 4', s.address4 ?? '-'),
            _buildRow(context, 'Post Code', s.postCode ?? '-'),
          ]),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Supplier s) {
    final primary = Theme.of(context).colorScheme.primary;
    const palette = [
      Color(0xFF5C6BC0), Color(0xFF26A69A), Color(0xFFEF5350),
      Color(0xFFAB47BC), Color(0xFF29B6F6), Color(0xFFFF7043),
      Color(0xFF66BB6A), Color(0xFFEC407A),
    ];
    final name = s.name ?? '';
    final color = name.isNotEmpty
        ? palette[name.codeUnitAt(0) % palette.length]
        : primary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: color),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if ((s.supplierCode ?? '').isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          s.supplierCode!,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  name.isNotEmpty ? name : '-',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                if ((s.name2 ?? '').isNotEmpty) ...[
              ],
              ]
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, String label, String value) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(alpha: 0.08),
        ),
      ],
    );
  }
}
