import 'package:flutter/material.dart';

class HoboButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expanded;

  const HoboButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final btn = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
        foregroundColor: theme.colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );

    if (!expanded) return btn;
    return SizedBox(width: double.infinity, child: btn);
  }
}
