import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class BubblePoolCollectEffectComponent extends PositionComponent {
  BubblePoolCollectEffectComponent({
    required Vector2 center,
    required Color color,
  }) : _color = color {
    position = center;
    anchor = Anchor.center;
    priority = 1600;
  }

  final Color _color;
  double _elapsed = 0;
  static const double _duration = 0.7;

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
    final t = (_elapsed / _duration).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(t);
    final fade = 1 - Curves.easeIn.transform(t);
    final ringRadius = lerpDouble(10, 34, eased) ?? 20;
    final burstGlow = Rect.fromCircle(
      center: Offset.zero,
      radius: ringRadius * 1.55,
    );

    canvas.drawCircle(
      Offset.zero,
      ringRadius * 1.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.08 * fade),
            _color.withValues(alpha: 0.16 * fade),
            Colors.transparent,
          ],
          stops: const [0.0, 0.36, 1.0],
        ).createShader(burstGlow),
    );

    canvas.drawCircle(
      Offset.zero,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2 - (t * 1.1)
        ..color = _color.withValues(alpha: 0.32 * fade),
    );
    canvas.drawCircle(
      Offset.zero,
      ringRadius * 0.54,
      Paint()..color = Colors.white.withValues(alpha: 0.12 * fade),
    );

    for (var index = 0; index < 7; index++) {
      final angle = (-math.pi / 2) + (index * ((math.pi * 2) / 7));
      final distance = lerpDouble(6, index.isEven ? 28 : 22, eased) ?? 14;
      final dx = math.cos(angle) * distance;
      final dy = math.sin(angle) * distance;
      final particleRadius = lerpDouble(4.8, 1.2, t) ?? 2.2;
      canvas.drawCircle(
        Offset(dx, dy),
        particleRadius,
        Paint()..color = _color.withValues(alpha: 0.24 * fade),
      );
      canvas.drawCircle(
        Offset(dx, dy),
        particleRadius * 0.58,
        Paint()..color = Colors.white.withValues(alpha: 0.65 * fade),
      );
      if (index.isEven) {
        canvas.drawCircle(
          Offset(dx * 0.72, dy * 0.72),
          particleRadius * 0.42,
          Paint()..color = _color.withValues(alpha: 0.3 * fade),
        );
      }
    }
  }
}
