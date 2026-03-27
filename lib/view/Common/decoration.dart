import 'package:flutter/material.dart';

/// Standard filled input decoration used across all form pages.
///
/// Pass [hint] for placeholder text (hintText) or [label] for a floating
/// label (labelText). Both are optional — omit for a plain filled field.
///
/// Use [fillColor] to override the default theme fill (e.g. for forms that
/// specify a custom surface color). Use [contentPadding] to override the
/// default padding.

class FormSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final String? badge;

  const FormSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12),
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
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Divider(
                  color: primary.withValues(alpha: 0.2), thickness: 1),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: expanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: primary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FormTotalPriceSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color muted;
  final Color? valueColor;
  const FormTotalPriceSummaryRow({required this.label, required this.value, required this.muted, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            label, 
            style: TextStyle(
              fontSize: 12, 
              color: valueColor ?? muted)),
          const Spacer(),
          Text(
            value, 
            style: TextStyle(
              fontSize: 12, 
              fontWeight: FontWeight.w600, 
              color: valueColor ?? muted)),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String label;
  const FieldLabel({required this.label});
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

class FieldBox extends StatelessWidget {
  final Widget child;
  const FieldBox({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class SheetSection extends StatelessWidget {
  final String label;
  const SheetSection({required this.label});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final TextInputType inputType;
  const SheetField({
    required this.ctrl,
    required this.hint,
    this.inputType = TextInputType.text,
  });
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hint,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: ctrl,
            keyboardType: inputType,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

class DetailSectionHeader extends StatelessWidget {
  final String title;
  const DetailSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class DetailDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const DetailDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outline
                .withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class DetailTotalPriceSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color muted;
  final Color? valueColor;
  const DetailTotalPriceSummaryRow({required this.label, required this.value, required this.muted, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: valueColor ?? muted)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}

class ItemBreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color muted;
  final Color? valueColor;
  const ItemBreakdownRow({required this.label, required this.value, required this.muted, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
        children: [
          Text(
            label, 
            style: TextStyle(
              fontSize: 11, 
              color: valueColor ?? muted)),
          const Spacer(),
          Text(
            value, 
            style: TextStyle(
              fontSize: 11, 
              fontWeight: FontWeight.w600, 
              color: valueColor ?? muted)),
        ],
      );
  }
}

class DetailAddressRow extends StatelessWidget {
  final String label;
  final List<String> lines;
  const DetailAddressRow({required this.label, required this.lines});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    final borderColor = Theme.of(context).colorScheme.outline.withValues(alpha: 0.08);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(fontSize: 13, color: muted)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: lines
                  .map((l) => Text(l,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration formInputDeco(
  BuildContext context, {
  String? hint,
  String? label,
  String? prefixText,
  Color? fillColor,
  EdgeInsetsGeometry? contentPadding,
}) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    hintText: hint,
    hintStyle: hint != null
        ? TextStyle(
            fontSize: 14,
            color: cs.onSurface.withValues(alpha: 0.35),
          )
        : null,
    labelText: label,
    labelStyle: label != null
        ? TextStyle(color: cs.onSurface.withValues(alpha: 0.4))
        : null,
    prefixText: prefixText,
    filled: true,
    fillColor: fillColor,
    contentPadding: contentPadding,
    isDense: true,
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.primary, width: 1.5),
    ),
  );
}

// ── Sheet input decoration (radius 10, used inside bottom-sheet edit panels) ──

InputDecoration sheetInputDeco(BuildContext context, {String? label}) {
  final cs = Theme.of(context).colorScheme;
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 12),
    filled: true,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: cs.primary, width: 1.5),
    ),
  );
}

// ── UOM chip (horizontal scrollable selector in edit sheet) ───────────────────

Widget uomChip(
  BuildContext context,
  String label, {
  required bool selected,
  VoidCallback? onTap,
}) {
  final primary = Theme.of(context).colorScheme.primary;
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? primary : primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: selected ? primary : primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : primary,
        ),
      ),
    ),
  );
}

// ── Qty step button (+/−) ─────────────────────────────────────────────────────

Widget stepBtn(BuildContext context, IconData icon, VoidCallback onTap) {
  final primary = Theme.of(context).colorScheme.primary;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: primary),
    ),
  );
}

Widget BreakdownRow(String label, String value, ColorScheme cs,
      {Color? valueColor}) =>
      Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.5))),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: valueColor ??
                      cs.onSurface.withValues(alpha: 0.65))),
        ],
      );
