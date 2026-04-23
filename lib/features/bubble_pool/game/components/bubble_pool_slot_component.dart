import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import 'package:mind_buddy/features/bubble_pool/game/models/bubble_pool_slot_definition.dart';

class BubblePoolSlotComponent extends PositionComponent with TapCallbacks {
  BubblePoolSlotComponent({
    required this.definition,
    required this.onTapSlot,
    required Color color,
  }) : _glowColor = color;

  final BubblePoolSlotDefinition definition;
  final void Function(String slotId) onTapSlot;

  Color _glowColor;
  bool _isPlacementActive = false;
  bool _isOccupied = false;
  bool _isDragCandidate = false;
  double _elapsed = 0;

  void syncLayout(Rect itemBounds) {
    final x = itemBounds.left + (itemBounds.width * definition.normalizedX);
    final y = itemBounds.top + (itemBounds.height * definition.normalizedY);
    position = Vector2(x, y);
    size = Vector2.all(definition.itemBaseSize * itemBounds.width * 1.1);
    anchor = Anchor.center;
    priority = 80 + (definition.normalizedY * itemBounds.height).round();
  }

  void updateVisualState({
    required bool isPlacementActive,
    required bool isOccupied,
    required bool isDragCandidate,
    required Color glowColor,
  }) {
    _isPlacementActive = isPlacementActive;
    _isOccupied = isOccupied;
    _isDragCandidate = isDragCandidate;
    _glowColor = glowColor;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    final radius = size.x * 0.5;
    return point.distanceTo(Vector2(size.x * 0.5, size.y * 0.5)) <= radius;
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!_isPlacementActive || _isOccupied) return;
    onTapSlot(definition.id);
  }

  @override
  void render(Canvas canvas) {
    if ((!_isPlacementActive && !_isDragCandidate) || _isOccupied) return;

    final center = Offset(size.x / 2, size.y / 2);
    final pulse =
        0.92 +
        ((1 + math.sin(_elapsed * (_isDragCandidate ? 3.4 : 2.4))) * 0.04);
    final emphasis = (_isDragCandidate ? 1.48 : 1.0) * pulse;
    final outerRadius = size.x * 0.5 * emphasis;
    final innerRadius = size.x * (_isDragCandidate ? 0.33 : 0.28) * emphasis;
    final haloRadius = outerRadius * (_isDragCandidate ? 1.7 : 1.42);
    final glowRect = Rect.fromCircle(center: center, radius: haloRadius);

    canvas.drawCircle(
      center,
      haloRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: _isDragCandidate ? 0.2 : 0.04),
            _glowColor.withValues(alpha: _isDragCandidate ? 0.5 : 0.18),
            _glowColor.withValues(alpha: _isDragCandidate ? 0.24 : 0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 0.62, 1.0],
        ).createShader(glowRect),
    );
    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _isDragCandidate ? 2.1 : 1.4
        ..color = _glowColor.withValues(alpha: _isDragCandidate ? 0.98 : 0.55),
    );
    canvas.drawCircle(
      center,
      outerRadius * 0.72,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _isDragCandidate ? 1.1 : 0.8
        ..color = Colors.white.withValues(
          alpha: _isDragCandidate ? 0.62 : 0.24,
        ),
    );
    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.14),
            _glowColor.withValues(alpha: 0.18),
            _glowColor.withValues(alpha: 0.04),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: innerRadius)),
    );
  }
}
