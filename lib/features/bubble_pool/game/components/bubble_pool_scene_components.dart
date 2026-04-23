import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class SceneRectComponent extends PositionComponent {
  SceneRectComponent({
    required this.componentPriority,
    required this.gradientBuilder,
    this.borderColorBuilder,
    this.margin = EdgeInsets.zero,
    this.radius = 0,
  }) : super(priority: componentPriority);

  final Gradient Function() gradientBuilder;
  final Color Function()? borderColorBuilder;
  final EdgeInsets margin;
  final double radius;
  final int componentPriority;

  Paint _fillPaint = Paint();
  Paint? _strokePaint;
  Rect _rect = Rect.zero;
  RRect _rrect = RRect.fromRectAndRadius(Rect.zero, Radius.zero);

  void syncLayout(Vector2 gameSize) {
    position = Vector2(margin.left, margin.top);
    size = Vector2(
      gameSize.x - margin.left - margin.right,
      gameSize.y - margin.top - margin.bottom,
    );
    _rect = Offset.zero & Size(size.x, size.y);
    _rrect = RRect.fromRectAndRadius(_rect, Radius.circular(radius));
    refresh();
  }

  void refresh() {
    _fillPaint = Paint()..shader = gradientBuilder().createShader(_rect);
    final strokeColor = borderColorBuilder?.call();
    _strokePaint = strokeColor == null
        ? null
        : (Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = strokeColor);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(_rrect, _fillPaint);
    final strokePaint = _strokePaint;
    if (strokePaint != null) {
      canvas.drawRRect(_rrect, strokePaint);
    }
  }
}

class GlowOrbComponent extends PositionComponent {
  GlowOrbComponent({
    required this.componentPriority,
    required this.alignment,
    required this.diameterFactor,
    required this.colorBuilder,
  }) : super(priority: componentPriority);

  final int componentPriority;
  final Alignment alignment;
  final double diameterFactor;
  final Color Function() colorBuilder;

  Paint _paint = Paint();
  Offset _center = Offset.zero;
  double _radius = 0;
  double _elapsed = 0;

  void syncLayout(Vector2 gameSize) {
    final width = gameSize.x;
    final height = gameSize.y;
    _radius = width * diameterFactor * 0.5;
    _center = Offset(
      ((alignment.x + 1) / 2) * width,
      ((alignment.y + 1) / 2) * height,
    );
    size = gameSize;
    refresh();
  }

  void refresh() {
    final color = colorBuilder();
    _paint = _buildPaint(color);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    _paint = _buildPaint(colorBuilder());
  }

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(_center, _radius, _paint);
  }

  Paint _buildPaint(Color color) {
    final pulse = 0.92 + (math.sin(_elapsed * 0.65) * 0.08);
    final rect = Rect.fromCircle(center: _center, radius: _radius * pulse);
    return Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: color.a * (0.92 + (pulse - 0.92))),
          color.withValues(alpha: color.a * 0.34),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
      ).createShader(rect);
  }
}

class WaterShimmerComponent extends PositionComponent {
  WaterShimmerComponent({
    required this.componentPriority,
    required this.colorBuilder,
    this.margin = EdgeInsets.zero,
    this.radius = 0,
  }) : super(priority: componentPriority);

  final int componentPriority;
  final Color Function() colorBuilder;
  final EdgeInsets margin;
  final double radius;

  Rect _rect = Rect.zero;
  RRect _rrect = RRect.fromRectAndRadius(Rect.zero, Radius.zero);
  double _elapsed = 0;

  void syncLayout(Vector2 gameSize) {
    position = Vector2(margin.left, margin.top);
    size = Vector2(
      gameSize.x - margin.left - margin.right,
      gameSize.y - margin.top - margin.bottom,
    );
    _rect = Offset.zero & Size(size.x, size.y);
    _rrect = RRect.fromRectAndRadius(_rect, Radius.circular(radius));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.clipRRect(_rrect);
    final shimmerBase = colorBuilder();
    final drift = math.sin(_elapsed * 0.12);
    final surfaceLineY = _rect.top + (_rect.height * (0.12 + (drift * 0.006)));
    final causticPhase = _elapsed * 0.1;
    canvas.drawRRect(
      _rrect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.18),
          radius: 1.0,
          colors: [
            Colors.white.withValues(alpha: 0.06),
            Colors.transparent,
            shimmerBase.withValues(alpha: 0.035),
            shimmerBase.withValues(alpha: 0.08),
          ],
          stops: const [0.0, 0.42, 0.78, 1.0],
        ).createShader(_rect.inflate(_rect.width * 0.04)),
    );
    final sheenRect = Rect.fromCenter(
      center: Offset(
        _rect.width * (0.52 + (drift * 0.03)),
        _rect.height * 0.15,
      ),
      width: _rect.width * 0.42,
      height: _rect.height * 0.14,
    );
    canvas.drawOval(
      sheenRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.36, 1.0],
        ).createShader(sheenRect),
    );
    canvas.drawLine(
      Offset(_rect.left + 14, surfaceLineY),
      Offset(_rect.right - 14, surfaceLineY),
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white.withValues(alpha: 0.18),
                shimmerBase.withValues(alpha: 0.14),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromLTWH(_rect.left, surfaceLineY - 1, _rect.width, 2),
            )
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    for (final band in const [
      (0.22, 0.24, 0.09, 0.055),
      (0.52, 0.18, 0.08, 0.045),
      (0.74, 0.21, 0.07, 0.04),
    ]) {
      final bandCenter = Offset(
        _rect.width * (band.$1 + (math.sin(causticPhase + band.$1) * 0.04)),
        _rect.height * band.$2,
      );
      final bandRect = Rect.fromCenter(
        center: bandCenter,
        width: _rect.width * 0.42,
        height: _rect.height * band.$3,
      );
      canvas.drawOval(
        bandRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.transparent,
              Colors.white.withValues(alpha: band.$4),
              Colors.transparent,
            ],
          ).createShader(bandRect),
      );
    }
    final rippleCenter = Offset(
      _rect.width * 0.4,
      _rect.height * 0.62 + (math.sin(_elapsed * 0.24) * 2.5),
    );
    for (final spec in const [(0.12, 0.035), (0.18, 0.022)]) {
      final radius = _rect.width * spec.$1;
      canvas.drawOval(
        Rect.fromCenter(
          center: rippleCenter,
          width: radius * 2.1,
          height: radius * 0.74,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: spec.$2),
      );
    }
    final innerShadowRect = _rect.deflate(_rect.width * 0.024);
    canvas.drawRRect(
      _rrect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.0, -0.06),
          radius: 1.04,
          colors: [
            Colors.transparent,
            shimmerBase.withValues(alpha: 0.02),
            shimmerBase.withValues(alpha: 0.08),
            shimmerBase.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.46, 0.76, 1.0],
        ).createShader(_rect.inflate(_rect.width * 0.06)),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        innerShadowRect,
        Radius.circular(math.max(radius - (_rect.width * 0.024), 8)),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            Colors.transparent,
            shimmerBase.withValues(alpha: 0.12),
          ],
          stops: const [0.0, 0.32, 1.0],
        ).createShader(innerShadowRect),
    );
    final edgeShadeRect = _rect.inflate(_rect.width * 0.02);
    canvas.drawRRect(
      _rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.transparent,
            shimmerBase.withValues(alpha: 0.03),
            shimmerBase.withValues(alpha: 0.08),
          ],
          stops: const [0.0, 0.44, 0.76, 1.0],
        ).createShader(edgeShadeRect),
    );
    canvas.restore();
  }
}

class BubbleDriftComponent extends PositionComponent {
  BubbleDriftComponent({
    required this.componentPriority,
    required this.colorBuilder,
    this.margin = EdgeInsets.zero,
  }) : super(priority: componentPriority);

  final int componentPriority;
  final Color Function() colorBuilder;
  final EdgeInsets margin;

  final List<({double x, double y, double size, double speed, double sway})>
  _bubbles = const [
    (x: 0.18, y: 0.88, size: 5.5, speed: 0.14, sway: 0.7),
    (x: 0.34, y: 0.74, size: 4.2, speed: 0.12, sway: 1.1),
    (x: 0.61, y: 0.82, size: 6.2, speed: 0.16, sway: 0.9),
    (x: 0.78, y: 0.68, size: 3.8, speed: 0.1, sway: 1.3),
  ];
  Rect _rect = Rect.zero;
  double _elapsed = 0;

  void syncLayout(Vector2 gameSize) {
    position = Vector2(margin.left, margin.top);
    size = Vector2(
      gameSize.x - margin.left - margin.right,
      gameSize.y - margin.top - margin.bottom,
    );
    _rect = Offset.zero & Size(size.x, size.y);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    final tint = colorBuilder();
    for (final bubble in _bubbles) {
      final rise = ((_elapsed * bubble.speed) + (1 - bubble.y)) % 1;
      final y = _rect.height * (1 - rise);
      final x =
          (_rect.width * bubble.x) +
          (math.sin((_elapsed * bubble.sway) + bubble.x) * 6);
      final radius =
          bubble.size + (math.sin((_elapsed * 1.4) + bubble.y) * 0.4);
      canvas.drawCircle(
        Offset(x, y),
        radius * 1.9,
        Paint()
          ..color = tint.withValues(alpha: 0.035)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = Colors.white.withValues(alpha: 0.16),
      );
    }
  }
}

class PoolStructureComponent extends PositionComponent {
  PoolStructureComponent({
    required this.componentPriority,
    required this.frameColorBuilder,
    required this.rimColorBuilder,
    required this.shadowColorBuilder,
    required this.waterHighlightBuilder,
    this.outerMargin = EdgeInsets.zero,
    this.waterMargin = EdgeInsets.zero,
    this.outerRadius = 0,
    this.waterRadius = 0,
  }) : super(priority: componentPriority);

  final int componentPriority;
  final Color Function() frameColorBuilder;
  final Color Function() rimColorBuilder;
  final Color Function() shadowColorBuilder;
  final Color Function() waterHighlightBuilder;
  final EdgeInsets outerMargin;
  final EdgeInsets waterMargin;
  final double outerRadius;
  final double waterRadius;

  Rect _outerRect = Rect.zero;
  Rect _waterRect = Rect.zero;
  RRect _outerRRect = RRect.fromRectAndRadius(Rect.zero, Radius.zero);
  RRect _waterRRect = RRect.fromRectAndRadius(Rect.zero, Radius.zero);

  void syncLayout(Vector2 gameSize) {
    size = gameSize;
    _outerRect = Rect.fromLTWH(
      outerMargin.left,
      outerMargin.top,
      gameSize.x - outerMargin.left - outerMargin.right,
      gameSize.y - outerMargin.top - outerMargin.bottom,
    );
    _waterRect = Rect.fromLTWH(
      waterMargin.left,
      waterMargin.top,
      gameSize.x - waterMargin.left - waterMargin.right,
      gameSize.y - waterMargin.top - waterMargin.bottom,
    );
    _outerRRect = RRect.fromRectAndRadius(
      _outerRect,
      Radius.circular(outerRadius),
    );
    _waterRRect = RRect.fromRectAndRadius(
      _waterRect,
      Radius.circular(waterRadius),
    );
  }

  @override
  void render(Canvas canvas) {
    final frameColor = frameColorBuilder();
    final rimColor = rimColorBuilder();
    final shadowColor = shadowColorBuilder();
    final highlightColor = waterHighlightBuilder();
    final rimThickness = (_outerRect.width * 0.058).clamp(16.0, 24.0);
    const wallInset = 12.0;
    final openingRect = _waterRect.inflate(wallInset);
    final openingRRect = RRect.fromRectAndRadius(
      openingRect,
      Radius.circular(waterRadius + (rimThickness * 0.7)),
    );
    final rimPath = Path.combine(
      PathOperation.difference,
      Path()..addRRect(_outerRRect),
      Path()..addRRect(openingRRect),
    );
    final wallFacePath = Path.combine(
      PathOperation.difference,
      Path()..addRRect(openingRRect),
      Path()..addRRect(_waterRRect),
    );
    final shellRect = _outerRect.inflate(6);
    final openingShadowRect = openingRect.inflate(12);
    final topRimRect = Rect.fromLTWH(
      openingRect.left + 4,
      openingRect.top - 2,
      openingRect.width - 8,
      rimThickness + 8,
    );
    final waterCastRect = _waterRect.inflate(10);
    final rimInnerShadowRect = openingRect.inflate(10);
    final waterInnerShadowRect = _waterRect.inflate(12);

    canvas.drawRRect(
      _outerRRect.inflate(5),
      Paint()
        ..color = shadowColor.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    canvas.drawRRect(
      _outerRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(frameColor, Colors.white, 0.16)!.withValues(alpha: 0.99),
            frameColor.withValues(alpha: 0.9),
            Color.lerp(frameColor, shadowColor, 0.2)!.withValues(alpha: 0.96),
          ],
          stops: const [0.0, 0.46, 1.0],
        ).createShader(_outerRect),
    );

    canvas.drawPath(
      rimPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.42),
            Color.lerp(rimColor, Colors.white, 0.22)!.withValues(alpha: 0.34),
            Color.lerp(rimColor, shadowColor, 0.24)!.withValues(alpha: 0.28),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(shellRect),
    );

    canvas.drawPath(
      rimPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.24),
            Colors.transparent,
            shadowColor.withValues(alpha: 0.12),
          ],
          stops: const [0.0, 0.24, 1.0],
        ).createShader(shellRect),
    );

    canvas.drawRRect(
      openingRRect,
      Paint()
        ..color = shadowColor.withValues(alpha: 0.1)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    canvas.drawRRect(
      _outerRRect.deflate(3.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.24),
            Colors.white.withValues(alpha: 0.1),
            shadowColor.withValues(alpha: 0.08),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(_outerRect),
    );

    canvas.drawRRect(
      openingRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(rimColor, shadowColor, 0.34)!.withValues(alpha: 0.28),
            Color.lerp(rimColor, shadowColor, 0.26)!.withValues(alpha: 0.16),
            Colors.transparent,
          ],
          stops: const [0.0, 0.28, 1.0],
        ).createShader(rimInnerShadowRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    canvas.drawPath(
      wallFacePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(
              highlightColor,
              Colors.white,
              0.14,
            )!.withValues(alpha: 0.1),
            Color.lerp(rimColor, shadowColor, 0.08)!.withValues(alpha: 0.12),
            Color.lerp(rimColor, shadowColor, 0.26)!.withValues(alpha: 0.22),
          ],
          stops: const [0.0, 0.32, 1.0],
        ).createShader(openingRect),
    );

    canvas.drawPath(
      wallFacePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.14),
            Colors.transparent,
            shadowColor.withValues(alpha: 0.2),
          ],
          stops: const [0.0, 0.28, 1.0],
        ).createShader(openingRect),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(topRimRect, Radius.circular(topRimRect.height)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.54),
            Colors.white.withValues(alpha: 0.24),
            Colors.transparent,
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(topRimRect),
    );

    canvas.drawRRect(
      openingRRect.deflate(2.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.24),
            Colors.transparent,
            shadowColor.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.38, 1.0],
        ).createShader(openingRect),
    );

    canvas.drawRRect(
      _waterRRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.1),
          radius: 1.0,
          colors: [
            Colors.white.withValues(alpha: 0.07),
            Colors.transparent,
            Color.lerp(
              highlightColor,
              shadowColor,
              0.3,
            )!.withValues(alpha: 0.1),
            Color.lerp(
              highlightColor,
              shadowColor,
              0.42,
            )!.withValues(alpha: 0.18),
          ],
          stops: const [0.0, 0.42, 0.76, 1.0],
        ).createShader(waterCastRect),
    );

    canvas.drawRRect(
      _waterRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(rimColor, shadowColor, 0.42)!.withValues(alpha: 0.32),
            Color.lerp(rimColor, shadowColor, 0.28)!.withValues(alpha: 0.2),
            Colors.transparent,
          ],
          stops: const [0.0, 0.36, 1.0],
        ).createShader(waterInnerShadowRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    canvas.drawRRect(
      _waterRRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = rimColor.withValues(alpha: 0.18),
    );
    canvas.drawRRect(
      _waterRRect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.16),
            highlightColor.withValues(alpha: 0.08),
            shadowColor.withValues(alpha: 0.12),
          ],
          stops: const [0.0, 0.38, 1.0],
        ).createShader(_waterRect),
    );

    _drawLadder(canvas, rimColor, highlightColor);

    canvas.drawRRect(
      _waterRRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.16),
          radius: 1.06,
          colors: [
            Colors.transparent,
            Colors.transparent,
            shadowColor.withValues(alpha: 0.08),
            shadowColor.withValues(alpha: 0.16),
          ],
          stops: const [0.0, 0.54, 0.82, 1.0],
        ).createShader(waterCastRect),
    );

    canvas.drawRRect(
      openingRRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.78, 0.9),
          radius: 1.02,
          colors: [
            Colors.transparent,
            Colors.transparent,
            shadowColor.withValues(alpha: 0.08),
          ],
          stops: const [0.0, 0.72, 1.0],
        ).createShader(openingShadowRect),
    );
  }

  void _drawLadder(Canvas canvas, Color rimColor, Color highlightColor) {
    final ladderX = _waterRect.right - (_waterRect.width * 0.16);
    final topY = _waterRect.top - 6;
    final bottomY = _waterRect.top + (_waterRect.height * 0.3);
    final railGap = _waterRect.width * 0.045;

    final railPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: 0.6),
              rimColor.withValues(alpha: 0.72),
              rimColor.withValues(alpha: 0.18),
              Colors.transparent,
            ],
            stops: const [0.0, 0.18, 0.66, 1.0],
          ).createShader(
            Rect.fromLTWH(ladderX - railGap, topY, railGap * 2, bottomY - topY),
          )
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    for (final dx in [-railGap, railGap]) {
      final path = Path()
        ..moveTo(ladderX + dx, topY)
        ..quadraticBezierTo(
          ladderX + (dx * 1.25),
          _waterRect.top + 8,
          ladderX + (dx * 0.72),
          bottomY,
        );
      canvas.drawPath(path, railPaint);
    }

    for (final rungT in const [0.14, 0.32, 0.5, 0.68]) {
      final y = topY + ((bottomY - topY) * rungT);
      final alpha = 0.44 - (rungT * 0.24);
      canvas.drawLine(
        Offset(ladderX - railGap * 0.8, y),
        Offset(ladderX + railGap * 0.8, y),
        Paint()
          ..color = highlightColor.withValues(alpha: alpha)
          ..strokeWidth = 2.1
          ..strokeCap = StrokeCap.round,
      );
    }

    final waterFadeRect = Rect.fromLTWH(
      ladderX - (_waterRect.width * 0.11),
      _waterRect.top + 4,
      _waterRect.width * 0.22,
      _waterRect.height * 0.34,
    );
    canvas.drawRect(
      waterFadeRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            highlightColor.withValues(alpha: 0.07),
            highlightColor.withValues(alpha: 0.16),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(waterFadeRect),
    );
  }
}
