import 'package:flutter/material.dart';
import 'package:cubehous/common/dots_loading.dart';

class PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final Color primary;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.isLoading,
    required this.primary,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: isLoading ? null : onPrev,
            style: IconButton.styleFrom(
              foregroundColor: onPrev != null ? primary : null,
            ),
          ),
          const SizedBox(width: 8),
          if (isLoading)
            const DotsLoading(dotSize: 6)
          else
            Text(
              'Page ${currentPage + 1} of $totalPages',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isLoading ? null : onNext,
            style: IconButton.styleFrom(
              foregroundColor: onNext != null ? primary : null,
            ),
          ),
        ],
      ),
    );
  }
}
