import 'package:flutter/material.dart';

class HoboCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final BorderRadius borderRadius;
  final Border? border;

  const HoboCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface.withOpacity(0.92),
        borderRadius: borderRadius,
        border:
            border ??
            Border.all(color: theme.colorScheme.outline.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.08),
          ),
        ],
      ),
      child: child,
    );
  }
}
