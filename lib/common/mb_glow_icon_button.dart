import 'package:flutter/material.dart';

class MbGlowIconButton extends StatelessWidget {
  const MbGlowIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 20,
    this.tooltip,
    this.iconColor,
    this.margin = const EdgeInsets.all(8),
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;
  final Color? iconColor;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.25),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: scheme.surface,
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: iconColor ?? scheme.primary, size: size),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
