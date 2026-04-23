import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BubblePoolRippleEffectComponent extends PositionComponent {
  BubblePoolRippleEffectComponent({
    required Vector2 center,
    required Color color,
  }) : _color = color {
    position = center;
    anchor = Anchor.center;
    priority = 999;
  }

  final Color _color;
  double _elapsed = 0;
  static const double _duration = 0.8;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed >= _duration) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);
    final eased = Curves.easeOutCubic.transform(progress);
    final radius = lerpDouble(8, 34, eased) ?? 20;
    final opacity = (1 - Curves.easeIn.transform(progress)).clamp(0.0, 1.0);
    final glowRect = Rect.fromCircle(
      center: Offset.zero,
      radius: radius * 1.35,
    );

    canvas.drawCircle(
      Offset.zero,
      radius * 1.35,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.04 * opacity),
            _color.withValues(alpha: 0.1 * opacity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(glowRect),
    );

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = _color.withValues(alpha: 0.34 * opacity);
    final fillPaint = Paint()..color = _color.withValues(alpha: 0.08 * opacity);

    canvas.drawCircle(Offset.zero, radius, fillPaint);
    canvas.drawCircle(Offset.zero, radius, strokePaint);
    canvas.drawCircle(
      Offset.zero,
      radius * 0.58,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _color.withValues(alpha: 0.22 * opacity),
    );
    for (final spec in const [
      (-0.9, 0.58, 2.6),
      (0.2, 0.78, 2.0),
      (1.15, 0.64, 2.2),
    ]) {
      final particleRadius = lerpDouble(spec.$3, 0.7, progress) ?? 1.2;
      final particleDistance = radius * spec.$2;
      final dx = math.cos(spec.$1) * particleDistance;
      final dy = math.sin(spec.$1) * particleDistance - (8 * eased);
      canvas.drawCircle(
        Offset(dx, dy),
        particleRadius,
        Paint()..color = Colors.white.withValues(alpha: 0.44 * opacity),
      );
    }
  }
}
