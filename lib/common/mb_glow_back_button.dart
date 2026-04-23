import 'package:flutter/material.dart';

class MbGlowBackButton extends StatelessWidget {
  const MbGlowBackButton({
    super.key,
    required this.onPressed,
    this.margin = const EdgeInsets.all(8),
  });

  final VoidCallback onPressed;
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
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: CircleAvatar(
        backgroundColor: scheme.surface,
        child: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.primary, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
