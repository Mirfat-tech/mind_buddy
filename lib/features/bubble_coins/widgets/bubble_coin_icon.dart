import 'dart:ui';

import 'package:flutter/material.dart';

class BubbleCoinIcon extends StatelessWidget {
  const BubbleCoinIcon({super.key, this.size = 52, this.glow = true});

  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primary = scheme.primary;
    final base = Color.lerp(scheme.surface, primary, 0.18) ?? scheme.surface;
    final highlight =
        Color.lerp(scheme.surface, Colors.white, 0.7) ?? scheme.surface;
    final shadow = Color.lerp(primary, Colors.white, 0.15) ?? primary;
    final stampColor =
        Color.lerp(scheme.onSurface, primary, 0.7) ?? scheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.24, -0.3),
          radius: 0.95,
          colors: [
            highlight.withValues(alpha: 0.98),
            base.withValues(alpha: 0.96),
            shadow.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.58, 1.0],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.24)),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: primary.withValues(alpha: 0.16),
                  blurRadius: size * 0.34,
                  spreadRadius: size * 0.03,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.68,
            height: size * 0.68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(color: primary.withValues(alpha: 0.12)),
            ),
          ),
          Icon(
            Icons.bubble_chart_rounded,
            size: size * 0.34,
            color: stampColor.withValues(alpha: 0.92),
          ),
          Positioned(
            top: size * 0.16,
            left: size * 0.18,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                child: Container(
                  width: size * 0.18,
                  height: size * 0.18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
