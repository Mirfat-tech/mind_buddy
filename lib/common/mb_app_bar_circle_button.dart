import 'package:flutter/material.dart';

class MbAppBarCircleButton extends StatelessWidget {
  const MbAppBarCircleButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.iconColor,
    this.size = 44,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? iconColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = iconColor ?? scheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
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
        child: Material(
          color: scheme.surface,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Center(
              child: tooltip == null
                  ? Icon(icon, size: iconSize, color: fg)
                  : Tooltip(
                      message: tooltip!,
                      child: Icon(icon, size: iconSize, color: fg),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
