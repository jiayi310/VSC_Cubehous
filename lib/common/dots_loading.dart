import 'package:flutter/material.dart';

/// Animated three-dot loading indicator.
/// Self-contained — no external [AnimationController] needed.
class DotsLoading extends StatefulWidget {
  final Color? color;
  final double dotSize;

  const DotsLoading({super.key, this.color, this.dotSize = 10.0});

  @override
  State<DotsLoading> createState() => _DotsLoadingState();
}

class _DotsLoadingState extends State<DotsLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor =
        widget.color ?? Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (t - i / 3.0) % 1.0;
            final scale =
                0.5 + 0.5 * (1 - (phase * 2 - 1).abs().clamp(0.0, 1.0));
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.dotSize * 0.35),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: widget.dotSize,
                  height: widget.dotSize,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
