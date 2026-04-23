import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';

import 'package:mind_buddy/features/bubble_pool/game/models/bubble_pool_item_definition.dart';
import 'package:mind_buddy/features/bubble_pool/game/models/bubble_pool_slot_definition.dart';

class BubblePoolDecorItemComponent extends SpriteComponent
    with DragCallbacks, TapCallbacks {
  BubblePoolDecorItemComponent({
    required this.definition,
    required Sprite sprite,
    required BubblePoolItemPalette palette,
    this.dragEnabled,
    this.collectEnabled,
    this.onDragStartItem,
    this.onDragUpdateItem,
    this.onDragEndItem,
    this.onTapCollectItem,
  }) : _palette = palette,
       super(sprite: sprite, anchor: Anchor.center);

  final BubblePoolItemDefinition definition;
  final bool Function()? dragEnabled;
  final bool Function()? collectEnabled;
  final void Function(BubblePoolDecorItemComponent item)? onDragStartItem;
  final void Function(BubblePoolDecorItemComponent item)? onDragUpdateItem;
  final void Function(BubblePoolDecorItemComponent item)? onDragEndItem;
  final void Function(BubblePoolDecorItemComponent item)? onTapCollectItem;

  BubblePoolItemPalette _palette;
  double _elapsed = 0;
  double _baseY = 0;
  double _baseAngle = 0;
  double _currentNormalizedX = 0;
  double _currentNormalizedY = 0;
  double _currentBaseSize = 0;
  bool _dragArmed = false;
  bool _isDragging = false;
  bool _isCollecting = false;
  bool _isSettling = false;
  String? _slotId;
  DateTime? _cooldownEndsAt;
  Vector2? _settleFrom;
  Vector2? _settleTo;
  Vector2? _dragPointerOffset;
  double _settleElapsed = 0;

  static const double _settleDuration = 0.18;

  String? get slotId => _slotId;
  bool get isDragging => _isDragging;
  bool get isDragArmed => _dragArmed;
  bool get isCollectibleReady =>
      definition.isCollectible &&
      !_isCollecting &&
      (_cooldownEndsAt == null ||
          !DateTime.now().toUtc().isBefore(_cooldownEndsAt!));

  void syncLayout(Rect itemBounds) {
    if (_currentBaseSize == 0) {
      _currentNormalizedX = definition.normalizedX;
      _currentNormalizedY = definition.normalizedY;
      _currentBaseSize = definition.baseSize;
    }
    final x = itemBounds.left + (itemBounds.width * _currentNormalizedX);
    final y = itemBounds.top + (itemBounds.height * _currentNormalizedY);
    position = Vector2(x, y);
    size = Vector2.all(_currentBaseSize * itemBounds.width);
    _baseY = y;
    _baseAngle = _angleForKind();
    priority = _priorityFor(itemBounds.height);
  }

  void updatePalette(BubblePoolItemPalette palette) {
    _palette = palette;
  }

  void attachToSlot(BubblePoolSlotDefinition slot) {
    _slotId = slot.id;
    _currentNormalizedX = slot.normalizedX;
    _currentNormalizedY = slot.normalizedY;
    _currentBaseSize = slot.itemBaseSize;
    _dragArmed = false;
    _isDragging = false;
  }

  void setDraggingVisual(bool value) {
    _isDragging = value;
    if (value) {
      _dragArmed = false;
      _isSettling = false;
      _settleFrom = null;
      _settleTo = null;
      _settleElapsed = 0;
    } else {
      _dragArmed = false;
      _dragPointerOffset = null;
    }
  }

  void syncCollectibleState({
    required DateTime? cooldownEndsAt,
    required bool isCollecting,
  }) {
    _cooldownEndsAt = cooldownEndsAt;
    _isCollecting = isCollecting;
  }

  void beginSettle(Vector2 from, Vector2 to) {
    _isSettling = true;
    _settleFrom = from.clone();
    _settleTo = to.clone();
    _settleElapsed = 0;
    position = from.clone();
  }

  @override
  bool containsLocalPoint(Vector2 point) {
    final center = Vector2(size.x * 0.5, size.y * 0.5);
    final radius = math.max(size.x * 0.9, 38);
    return point.distanceTo(center) <= radius;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_cooldownEndsAt != null &&
        !DateTime.now().toUtc().isBefore(_cooldownEndsAt!)) {
      _cooldownEndsAt = null;
    }
    if (_isDragging) return;
    if (_isSettling) {
      _settleElapsed += dt;
      final t = (_settleElapsed / _settleDuration).clamp(0.0, 1.0);
      final eased = Curves.easeOutCubic.transform(t);
      final from = _settleFrom;
      final to = _settleTo;
      if (from != null && to != null) {
        position = from + ((to - from) * eased);
      }
      if (t >= 1) {
        _isSettling = false;
        _settleFrom = null;
        _settleTo = null;
      }
      return;
    }
    _elapsed += dt;
    final bob =
        math.sin(_elapsed * math.pi * definition.floatSpeed) *
        definition.floatAmplitude;
    final sway =
        math.sin(
          (_elapsed * math.pi * definition.swaySpeed) + definition.normalizedX,
        ) *
        definition.swayAmplitude;
    position.y = _baseY + bob;
    angle = _baseAngle + sway;
  }

  @override
  void render(Canvas canvas) {
    final scale = _isDragging
        ? 1.07
        : _dragArmed
        ? 1.04
        : _isSettling
        ? 1.05
        : (definition.isCollectible && isCollectibleReady ? 1.03 : 1.0);
    final shadowOffsetY = size.y * (_isDragging ? 0.19 : 0.17);
    final shadowRect = Rect.fromCenter(
      center: Offset(0, shadowOffsetY),
      width: size.x * (_isDragging ? 0.88 : 0.78),
      height: size.y * (_isDragging ? 0.24 : 0.18),
    );
    canvas.drawOval(
      shadowRect,
      Paint()
        ..color = _palette.shadow.withValues(alpha: _isDragging ? 0.18 : 0.13)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _isDragging ? 16 : 12),
    );
    canvas.drawOval(
      shadowRect.inflate(size.x * 0.06),
      Paint()
        ..shader = RadialGradient(
          colors: [
            _palette.shadow.withValues(alpha: _isDragging ? 0.07 : 0.04),
            _palette.water.withValues(
              alpha: _isDragging
                  ? 0.12
                  : _dragArmed
                  ? 0.1
                  : 0.08,
            ),
            Colors.transparent,
          ],
          stops: const [0.0, 0.46, 1.0],
        ).createShader(shadowRect.inflate(size.x * 0.12)),
    );
    final contactRippleRect = Rect.fromCenter(
      center: Offset(0, size.y * 0.17),
      width: size.x * (_isDragging ? 0.94 : 0.8),
      height: size.y * (_isDragging ? 0.18 : 0.13),
    );
    canvas.drawOval(
      contactRippleRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: _isDragging ? 0.08 : 0.04),
            _palette.water.withValues(alpha: _isDragging ? 0.12 : 0.08),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(contactRippleRect),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, size.y * 0.11),
        width: size.x * 0.68,
        height: size.y * 0.1,
      ),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.04),
                _palette.water.withValues(alpha: 0.08),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset(0, size.y * 0.11),
                width: size.x * 0.72,
                height: size.y * 0.14,
              ),
            ),
    );
    final itemGlowStrength = _itemGlowStrength();
    if (itemGlowStrength > 0) {
      final auraRect = Rect.fromCircle(
        center: Offset.zero,
        radius: size.x * (_isDragging ? 0.98 : 0.84),
      );
      canvas.drawCircle(
        Offset.zero,
        size.x * (_isDragging ? 0.98 : 0.84),
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(
                alpha: (_isDragging ? 0.16 : 0.08) * itemGlowStrength,
              ),
              _palette.water.withValues(
                alpha: (_isDragging ? 0.18 : 0.12) * itemGlowStrength,
              ),
              _palette.lilyGlow.withValues(
                alpha: (_isDragging ? 0.24 : 0.15) * itemGlowStrength,
              ),
              Colors.transparent,
            ],
            stops: const [0.0, 0.22, 0.48, 1.0],
          ).createShader(auraRect),
      );
    }
    if (definition.isCollectible) {
      final glowStrength = _collectGlowStrength();
      if (glowStrength > 0) {
        final glowRect = Rect.fromCircle(
          center: Offset.zero,
          radius: size.x * 0.74,
        );
        canvas.drawCircle(
          Offset.zero,
          size.x * 0.74,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.1 * glowStrength),
                _palette.lilyGlow.withValues(alpha: 0.26 * glowStrength),
                _palette.water.withValues(alpha: 0.16 * glowStrength),
                Colors.transparent,
              ],
              stops: const [0.0, 0.2, 0.5, 1.0],
            ).createShader(glowRect),
        );
      }
    }
    canvas.save();
    canvas.scale(scale, scale);
    super.render(canvas);
    canvas.restore();
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!definition.isCollectible ||
        _isDragging ||
        _isCollecting ||
        collectEnabled?.call() != true ||
        !isCollectibleReady) {
      return;
    }
    onTapCollectItem?.call(this);
  }

  @override
  void onLongTapDown(TapDownEvent event) {
    if (dragEnabled?.call() != true) return;
    _dragArmed = true;
    angle = 0;
    priority = 1200;
  }

  @override
  void onDragStart(DragStartEvent event) {
    if (dragEnabled?.call() != true || !_dragArmed) return;
    super.onDragStart(event);
    _dragPointerOffset = position - event.canvasPosition;
    _isDragging = true;
    _dragArmed = false;
    angle = 0;
    priority = 1400;
    onDragStartItem?.call(this);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (!_isDragging) return;
    position = event.canvasEndPosition + (_dragPointerOffset ?? Vector2.zero());
    onDragUpdateItem?.call(this);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (!_isDragging) return;
    super.onDragEnd(event);
    _dragArmed = false;
    _dragPointerOffset = null;
    onDragEndItem?.call(this);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    _dragArmed = false;
    if (!_isDragging) return;
    _dragPointerOffset = null;
    super.onDragCancel(event);
  }

  @override
  void onTapUp(TapUpEvent event) {
    if (!_isDragging) {
      _dragArmed = false;
    }
    super.onTapUp(event);
  }

  @override
  void onTapCancel(TapCancelEvent event) {
    if (!_isDragging && !_dragArmed) {
      _dragArmed = false;
    }
    super.onTapCancel(event);
  }

  double _collectGlowStrength() {
    if (_isCollecting) return 0.65;
    if (!isCollectibleReady) return 0;
    final pulse =
        (math.sin((_elapsed * math.pi * 1.55) - definition.normalizedX) + 1) /
        2;
    return 0.72 + (pulse * 0.4);
  }

  double _itemGlowStrength() {
    if (_isDragging) return 1;
    if (_dragArmed) return 0.82;
    if (_isSettling) return 0.82;
    final basePulse =
        (math.sin((_elapsed * math.pi * 0.92) + definition.normalizedY) + 1) /
        2;
    return 0.5 + (basePulse * 0.34);
  }

  int _priorityFor(double layerHeight) {
    final yDepth = (_currentNormalizedY * layerHeight).round();
    return 100 + yDepth;
  }

  double _angleForKind() {
    return switch (definition.kind) {
      BubblePoolItemKind.bathtub => -0.02,
      BubblePoolItemKind.bubblyLilyPad => 0.01,
      BubblePoolItemKind.flower => -0.015,
    };
  }
}
