import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool showDot;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.showDot = false,
  });

  factory StatusBadge.active(bool active) => StatusBadge(
        label: active ? 'Active' : 'Inactive',
        color: active ? Colors.green : Colors.red,
        showDot: true,
      );

  factory StatusBadge.voidBadge() =>
      const StatusBadge(label: 'VOID', color: Colors.red);

  factory StatusBadge.merged() =>
      const StatusBadge(label: 'MERGED', color: Colors.blueAccent);

  factory StatusBadge.adjusted() =>
      const StatusBadge(label: 'ADJUSTED', color: Colors.orange);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
