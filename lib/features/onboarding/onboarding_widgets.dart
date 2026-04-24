import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class GlowFilledButton extends StatelessWidget {
  const GlowFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.fullWidth = true,
    this.height = 52,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final Widget? icon;
  final bool fullWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(16);

    final button = icon == null
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: fullWidth
                  ? Size(double.infinity, height)
                  : Size(0, height),
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
            ),
            child: child,
          )
        : FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: fullWidth
                  ? Size(double.infinity, height)
                  : Size(0, height),
              shape: RoundedRectangleBorder(borderRadius: borderRadius),
            ),
            icon: icon!,
            label: child,
          );

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.2),
            blurRadius: 18,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: button,
    );
  }
}

class OnboardingDots extends StatelessWidget {
  const OnboardingDots({super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 10 : 6,
          height: isActive ? 10 : 6,
          decoration: BoxDecoration(
            color: isActive
                ? scheme.primary
                : scheme.primary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class BubbleChoice {
  const BubbleChoice({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.emphasized = false,
    this.style,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool emphasized;
  final BubbleChipStyle? style;
  final IconData? icon;
}

class BubbleCloudStyle {
  const BubbleCloudStyle({
    required this.centerFill,
    required this.bubbleFill,
    required this.textColor,
    required this.mutedTextColor,
    required this.glowColor,
    this.borderColor,
  });

  final Color centerFill;
  final Color bubbleFill;
  final Color textColor;
  final Color mutedTextColor;
  final Color glowColor;
  final Color? borderColor;
}

class BubbleChipStyle {
  const BubbleChipStyle({
    required this.fillColor,
    required this.borderColor,
    required this.glowColor,
    this.textColor,
    this.iconColor,
    this.sizeMultiplier,
    this.centerTintColor,
    this.edgeTintColor,
    this.glowOpacity,
    this.glowBlur,
    this.glowSpread,
    this.borderWidth,
  });

  final Color fillColor;
  final Color borderColor;
  final Color glowColor;
  final Color? textColor;
  final Color? iconColor;
  final double? sizeMultiplier;
  final Color? centerTintColor;
  final Color? edgeTintColor;
  final double? glowOpacity;
  final double? glowBlur;
  final double? glowSpread;
  final double? borderWidth;
}

class BubbleCloudBackdropStyle {
  const BubbleCloudBackdropStyle({
    required this.primaryColor,
    required this.secondaryColor,
  });

  final Color primaryColor;
  final Color secondaryColor;
}

class _BubblePlacement {
  _BubblePlacement({
    required this.choice,
    required this.size,
    required this.cx,
    required this.cy,
  });

  final BubbleChoice choice;
  final double size;
  double cx;
  double cy;
}

class OnboardingBubbleCloud extends StatelessWidget {
  const OnboardingBubbleCloud({
    super.key,
    required this.centerText,
    required this.choices,
    this.instructionText = 'Tap bubbles to select',
    this.style,
    this.centerBubbleStyle,
    this.layout = BubbleCloudLayout.orbit,
    this.backdropStyle,
    this.centerGlowColor,
    this.centerEnableBubbleMotion = true,
    this.showInstruction = true,
    this.enableBubbleMotion = true,
    this.enableSplashEffect = true,
  });

  final String centerText;
  final List<BubbleChoice> choices;
  final String? instructionText;
  final BubbleCloudStyle? style;
  final BubbleChipStyle? centerBubbleStyle;
  final BubbleCloudLayout layout;
  final BubbleCloudBackdropStyle? backdropStyle;
  final Color? centerGlowColor;
  final bool centerEnableBubbleMotion;
  final bool showInstruction;
  final bool enableBubbleMotion;
  final bool enableSplashEffect;

  double _estimateOptionSize(String label, double base) {
    final words = label
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final longestWord = words.isEmpty
        ? 0
        : words.map((w) => w.length).reduce(math.max);
    final pressure = label.length + (longestWord * 2);
    final minDiameterForWord = (longestWord * 7.0) + 52.0;
    var size = (base + pressure * 0.9).clamp(112.0, 196.0);
    if (size < minDiameterForWord) {
      size = minDiameterForWord;
    }
    if (label.length > 26) size += 10;
    if (label.length > 36) size += 8;
    return size.clamp(112.0, 220.0);
  }

  double _estimateCenterSize(String text, double base) {
    final lineHints = text.split('\n').where((l) => l.trim().isNotEmpty).length;
    final pressure = text.length + (lineHints * 22);
    return (base * 0.55 + (pressure * 0.42)).clamp(212.0, 360.0);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        const edgePadding = 14.0;
        const reservedBottomSpace = 36.0;
        final safeLeft = edgePadding + media.padding.left;
        final safeRight = width - edgePadding - media.padding.right;
        final safeTop = edgePadding + media.padding.top;
        final safeBottom =
            height - edgePadding - media.padding.bottom - reservedBottomSpace;
        final usableWidth = math.max(0.0, safeRight - safeLeft);
        final usableHeight = math.max(0.0, safeBottom - safeTop);
        final base = math.min(usableWidth, usableHeight);
        final orbitCenter = Offset(width / 2, height / 2);

        var centerSize = _estimateCenterSize(centerText, base);
        final rawOptionSizes = [
          for (final choice in choices)
            _estimateOptionSize(choice.label, base * 0.20 + 72),
        ];
        final safeOptionSizes = rawOptionSizes.isEmpty
            ? <double>[120]
            : rawOptionSizes;
        var optionSizes = [
          for (var i = 0; i < safeOptionSizes.length; i++)
            (safeOptionSizes[i] * (choices[i].style?.sizeMultiplier ?? 1))
                .clamp(112.0, 240.0),
        ];
        final optionCount = math.max(choices.length, 1);
        var ringRadius = 0.0;
        const orbitGap = 116.0;
        const minOptionGap = 14.0;
        for (var i = 0; i < 7; i++) {
          final maxOptionSize = optionSizes.reduce(math.max);
          final avgOptionSize =
              optionSizes.reduce((a, b) => a + b) / optionSizes.length;
          final centerRadius = centerSize / 2;
          final optionRadius = maxOptionSize / 2;

          final minNoOverlapRadius = centerRadius + optionRadius + orbitGap;
          final spacingRadiusNeeded =
              ((avgOptionSize + minOptionGap) * optionCount) / (2 * math.pi);
          final preferredRadius = math.max(
            minNoOverlapRadius,
            spacingRadiusNeeded,
          );
          final maxRadiusLeft = orbitCenter.dx - safeLeft - optionRadius;
          final maxRadiusRight = safeRight - orbitCenter.dx - optionRadius;
          final maxRadiusTop = orbitCenter.dy - safeTop - optionRadius;
          final maxRadiusBottom = safeBottom - orbitCenter.dy - optionRadius;
          final safeMaxRadius = math.max(
            0.0,
            math.min(
              math.min(maxRadiusLeft, maxRadiusRight),
              math.min(maxRadiusTop, maxRadiusBottom),
            ),
          );

          if (preferredRadius <= safeMaxRadius || safeMaxRadius == 0) {
            ringRadius = preferredRadius.clamp(0.0, safeMaxRadius);
            break;
          }

          final shrink = (safeMaxRadius / preferredRadius).clamp(0.84, 0.97);
          centerSize = (centerSize * shrink).clamp(182.0, 360.0);
          optionSizes = [
            for (final size in optionSizes) (size * shrink).clamp(112.0, 220.0),
          ];
          ringRadius = safeMaxRadius;
        }

        final maxOptionSize = optionSizes.reduce(math.max);
        final canUseUpperCenterRow = layout == BubbleCloudLayout.upperCenterRow;
        final center = canUseUpperCenterRow
            ? _resolveUpperCenter(
                width: width,
                safeTop: safeTop,
                safeBottom: safeBottom,
                centerSize: centerSize,
                maxOptionSize: maxOptionSize,
              )
            : orbitCenter;
        final canUseBottomBalanced =
            layout == BubbleCloudLayout.bottomBalanced &&
            _canUseBottomBalancedLayout(
              choiceCount: choices.length,
              usableWidth: usableWidth,
              usableHeight: usableHeight,
              center: center,
              centerSize: centerSize,
              maxOptionSize: maxOptionSize,
              safeLeft: safeLeft,
              safeRight: safeRight,
              safeBottom: safeBottom,
            );
        final placements = canUseUpperCenterRow
            ? _buildUpperCenterRowPlacements(
                choices: choices,
                optionSizes: optionSizes,
                center: center,
                centerSize: centerSize,
                safeLeft: safeLeft,
                safeRight: safeRight,
                safeTop: safeTop,
                safeBottom: safeBottom,
              )
            : canUseBottomBalanced
            ? _buildBottomBalancedPlacements(
                choices: choices,
                optionSizes: optionSizes,
                center: center,
                centerSize: centerSize,
                safeLeft: safeLeft,
                safeRight: safeRight,
                safeTop: safeTop,
                safeBottom: safeBottom,
              )
            : _buildOrbitPlacements(
                choices: choices,
                optionSizes: optionSizes,
                center: center,
                centerSize: centerSize,
                ringRadius: ringRadius,
                safeLeft: safeLeft,
                safeRight: safeRight,
                safeTop: safeTop,
                safeBottom: safeBottom,
              );

        return Stack(
          children: [
            if (backdropStyle != null)
              Positioned.fill(
                child: ExcludeSemantics(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _BubbleCloudBackdropPainter(
                        primaryColor: backdropStyle!.primaryColor,
                        secondaryColor: backdropStyle!.secondaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: center.dx - (centerSize / 2),
              top: center.dy - (centerSize / 2),
              child: Container(
                width: centerSize,
                height: centerSize,
                decoration: centerGlowColor == null
                    ? null
                    : BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: centerGlowColor!.withValues(alpha: 0.18),
                            blurRadius: centerSize * 0.16,
                            spreadRadius: centerSize * 0.01,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                child: _BubbleChip(
                  label: centerText,
                  size: centerSize,
                  isCenter: true,
                  onTap: null,
                  bubbleStyle: style,
                  chipStyle: centerBubbleStyle,
                  icon: null,
                  enableBubbleMotion: centerEnableBubbleMotion,
                  enableSplashEffect: false,
                ),
              ),
            ),
            for (var i = 0; i < placements.length; i++)
              Builder(
                builder: (_) {
                  final placement = placements[i];
                  final r = placement.size / 2;
                  final x = placement.cx - r;
                  final y = placement.cy - r;
                  return Positioned(
                    left: x,
                    top: y,
                    child: _BubbleChip(
                      label: placement.choice.label,
                      size: placement.size,
                      selected: placement.choice.selected,
                      emphasized: placement.choice.emphasized,
                      onTap: placement.choice.onTap,
                      bubbleStyle: style,
                      chipStyle: placement.choice.style,
                      icon: placement.choice.icon,
                      enableBubbleMotion: enableBubbleMotion,
                      enableSplashEffect: enableSplashEffect,
                    ),
                  );
                },
              ),
            if (showInstruction && instructionText != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: Text(
                  instructionText!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:
                        style?.mutedTextColor ??
                        scheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _canUseBottomBalancedLayout({
    required int choiceCount,
    required double usableWidth,
    required double usableHeight,
    required Offset center,
    required double centerSize,
    required double maxOptionSize,
    required double safeLeft,
    required double safeRight,
    required double safeBottom,
  }) {
    if (choiceCount != 2) return false;
    if (!usableWidth.isFinite || !usableHeight.isFinite) return false;
    if (usableWidth <= 0 || usableHeight <= 0) return false;

    final centerBottom = center.dy + (centerSize / 2);
    final bottomSpace = safeBottom - centerBottom;
    final neededBottomSpace = maxOptionSize + 72;
    final neededWidth = (maxOptionSize * 2) + 78;
    final horizontalRoom = safeRight - safeLeft;

    return bottomSpace.isFinite &&
        horizontalRoom.isFinite &&
        bottomSpace > neededBottomSpace &&
        horizontalRoom > neededWidth;
  }

  Offset _resolveUpperCenter({
    required double width,
    required double safeTop,
    required double safeBottom,
    required double centerSize,
    required double maxOptionSize,
  }) {
    final minCenterY = safeTop + (centerSize / 2) + 24;
    final maxCenterY = safeBottom - maxOptionSize - (centerSize / 2) - 48;
    final preferredY = safeTop + (centerSize / 2) + 58;
    final resolvedY = _safeClamp(preferredY, minCenterY, maxCenterY);
    return Offset(width / 2, resolvedY);
  }

  List<_BubblePlacement> _buildOrbitPlacements({
    required List<BubbleChoice> choices,
    required List<double> optionSizes,
    required Offset center,
    required double centerSize,
    required double ringRadius,
    required double safeLeft,
    required double safeRight,
    required double safeTop,
    required double safeBottom,
  }) {
    final placements = <_BubblePlacement>[];
    const optionGap = 10.0;

    for (var i = 0; i < choices.length; i++) {
      final angle = -math.pi / 2 + ((2 * math.pi) / choices.length) * i;
      final sinA = math.sin(angle);
      final bubbleSize = optionSizes[i];

      final isBottom = sinA > 0.45;
      final isTop = sinA < -0.45;
      final sizeBoost = isBottom ? 12.0 : (isTop ? 6.0 : 0.0);
      final adjustedSize = (bubbleSize + sizeBoost).clamp(112.0, 224.0);
      final adjustedR = adjustedSize / 2;

      final radialOffset = isBottom ? 28.0 : (isTop ? 22.0 : 12.0);
      final verticalOffset = isBottom ? 22.0 : (isTop ? -18.0 : 0.0);

      var cx = center.dx + math.cos(angle) * (ringRadius + radialOffset);
      var cy =
          center.dy +
          math.sin(angle) * (ringRadius + radialOffset) +
          verticalOffset;

      cx = cx.clamp(safeLeft + adjustedR, safeRight - adjustedR);
      cy = cy.clamp(safeTop + adjustedR, safeBottom - adjustedR);

      final minCenterDistance = (centerSize / 2) + adjustedR + 20;
      var vec = Offset(cx - center.dx, cy - center.dy);
      var dist = vec.distance;
      if (dist < minCenterDistance) {
        if (dist < 0.001) {
          vec = Offset(math.cos(angle), math.sin(angle));
          dist = 1;
        }
        final unit = vec / dist;
        final push = minCenterDistance - dist;
        cx += unit.dx * push;
        cy += unit.dy * push;
        cx = cx.clamp(safeLeft + adjustedR, safeRight - adjustedR);
        cy = cy.clamp(safeTop + adjustedR, safeBottom - adjustedR);
      }

      placements.add(
        _BubblePlacement(
          choice: choices[i],
          size: adjustedSize,
          cx: cx,
          cy: cy,
        ),
      );
    }

    for (var k = 0; k < 10; k++) {
      for (var i = 0; i < placements.length; i++) {
        for (var j = i + 1; j < placements.length; j++) {
          final a = placements[i];
          final b = placements[j];
          final ra = a.size / 2;
          final rb = b.size / 2;
          final minDist = ra + rb + optionGap;
          var dx = b.cx - a.cx;
          var dy = b.cy - a.cy;
          var dist = math.sqrt((dx * dx) + (dy * dy));
          if (dist < 0.001) {
            dx = 1;
            dy = 0;
            dist = 1;
          }
          if (dist < minDist) {
            final push = (minDist - dist) / 2;
            final ux = dx / dist;
            final uy = dy / dist;
            a.cx -= ux * push;
            a.cy -= uy * push;
            b.cx += ux * push;
            b.cy += uy * push;
          }
        }
      }

      for (final p in placements) {
        final r = p.size / 2;
        p.cx = p.cx.clamp(safeLeft + r, safeRight - r);
        p.cy = p.cy.clamp(safeTop + r, safeBottom - r);
        final minCenterDistance = (centerSize / 2) + r + 20;
        var vec = Offset(p.cx - center.dx, p.cy - center.dy);
        var dist = vec.distance;
        if (dist < minCenterDistance) {
          if (dist < 0.001) {
            vec = const Offset(0, -1);
            dist = 1;
          }
          final unit = vec / dist;
          final push = minCenterDistance - dist;
          p.cx += unit.dx * push;
          p.cy += unit.dy * push;
          p.cx = p.cx.clamp(safeLeft + r, safeRight - r);
          p.cy = p.cy.clamp(safeTop + r, safeBottom - r);
        }
      }
    }
    return placements;
  }

  List<_BubblePlacement> _buildBottomBalancedPlacements({
    required List<BubbleChoice> choices,
    required List<double> optionSizes,
    required Offset center,
    required double centerSize,
    required double safeLeft,
    required double safeRight,
    required double safeTop,
    required double safeBottom,
  }) {
    if (choices.isEmpty) return const <_BubblePlacement>[];

    final placements = <_BubblePlacement>[];
    final bottomY = safeBottom - 20;
    const horizontalInset = 26.0;
    final centerRadius = centerSize / 2;

    for (var i = 0; i < choices.length; i++) {
      final size = (optionSizes[i] + 6).clamp(118.0, 210.0);
      final r = size / 2;
      final isLeft = i.isEven;
      final targetX = isLeft
          ? safeLeft + horizontalInset + r
          : safeRight - horizontalInset - r;
      final targetY = bottomY - r;
      final minCenterY = center.dy + centerRadius + r + 52;
      final minX = safeLeft + r;
      final maxX = safeRight - r;
      final minY = math.min(minCenterY, safeBottom - r);
      final maxY = math.max(minCenterY, safeBottom - r);

      placements.add(
        _BubblePlacement(
          choice: choices[i],
          size: size,
          cx: _safeClamp(targetX, minX, maxX),
          cy: _safeClamp(targetY, minY, maxY),
        ),
      );
    }

    if (placements.length == 2) {
      final left = placements[0];
      final right = placements[1];
      final minGap = (left.size / 2) + (right.size / 2) + 26;
      if ((right.cx - left.cx) < minGap) {
        final midpoint = center.dx;
        left.cx = midpoint - (minGap / 2);
        right.cx = midpoint + (minGap / 2);
      }
    }

    for (final p in placements) {
      final r = p.size / 2;
      p.cx = _safeClamp(p.cx, safeLeft + r, safeRight - r);
      p.cy = _safeClamp(p.cy, safeTop + r, safeBottom - r);
    }

    return placements;
  }

  List<_BubblePlacement> _buildUpperCenterRowPlacements({
    required List<BubbleChoice> choices,
    required List<double> optionSizes,
    required Offset center,
    required double centerSize,
    required double safeLeft,
    required double safeRight,
    required double safeTop,
    required double safeBottom,
  }) {
    if (choices.isEmpty) return const <_BubblePlacement>[];

    final placements = <_BubblePlacement>[];
    const gapBelowCenter = 58.0;
    const minGapBetweenBubbles = 24.0;
    const edgeInset = 18.0;
    final availableWidth = math.max(
      0.0,
      safeRight - safeLeft - (edgeInset * 2),
    );
    final availableHeight = math.max(
      0.0,
      safeBottom - (center.dy + (centerSize / 2) + gapBelowCenter),
    );
    final maxDiameterFromWidth = choices.length == 2
        ? ((availableWidth - minGapBetweenBubbles) / 2).clamp(96.0, 188.0)
        : 188.0;
    final maxDiameterFromHeight = availableHeight.clamp(96.0, 188.0);

    for (var i = 0; i < choices.length; i++) {
      final size = math
          .min(
            optionSizes[i].toDouble(),
            math.min(maxDiameterFromWidth, maxDiameterFromHeight),
          )
          .clamp(96.0, 188.0);
      final r = size / 2;
      final rowY = center.dy + (centerSize / 2) + gapBelowCenter + r;
      final targetX = center.dx;

      placements.add(
        _BubblePlacement(
          choice: choices[i],
          size: size,
          cx: _safeClamp(targetX, safeLeft + r, safeRight - r),
          cy: _safeClamp(rowY, safeTop + r, safeBottom - r),
        ),
      );
    }

    if (placements.length == 2) {
      final left = placements[0];
      final right = placements[1];
      final leftRadius = left.size / 2;
      final rightRadius = right.size / 2;
      final desiredGap = leftRadius + rightRadius + minGapBetweenBubbles;
      left.cx = center.dx - (desiredGap / 2);
      right.cx = center.dx + (desiredGap / 2);

      final rowWidth = desiredGap + leftRadius + rightRadius;
      final availableWidth = safeRight - safeLeft;
      if (rowWidth > availableWidth) {
        final overflow = (rowWidth - availableWidth) / 2;
        left.cx += overflow;
        right.cx -= overflow;
      }
    }

    for (final p in placements) {
      final r = p.size / 2;
      p.cx = _safeClamp(p.cx, safeLeft + r, safeRight - r);
      p.cy = _safeClamp(p.cy, safeTop + r, safeBottom - r);
    }

    return placements;
  }

  double _safeClamp(double value, double min, double max) {
    if (!value.isFinite) return min.isFinite ? min : 0;
    if (!min.isFinite && !max.isFinite) return value;
    if (!min.isFinite) return value > max ? max : value;
    if (!max.isFinite) return value < min ? min : value;
    final lower = math.min(min, max);
    final upper = math.max(min, max);
    return value.clamp(lower, upper).toDouble();
  }
}

enum BubbleCloudLayout { orbit, bottomBalanced, upperCenterRow }

class _BubbleCloudBackdropPainter extends CustomPainter {
  const _BubbleCloudBackdropPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    _paintCloud(
      canvas,
      size,
      anchor: Offset(size.width * 0.1, size.height * 0.12),
      scale: size.width * 0.18,
      color: Colors.white.withValues(alpha: 0.18),
    );
    _paintCloud(
      canvas,
      size,
      anchor: Offset(size.width * 0.93, size.height * 0.38),
      scale: size.width * 0.16,
      color: Color.lerp(
        Colors.white,
        secondaryColor,
        0.22,
      )!.withValues(alpha: 0.16),
    );
    _paintCloud(
      canvas,
      size,
      anchor: Offset(size.width * 0.14, size.height * 0.76),
      scale: size.width * 0.19,
      color: Color.lerp(
        Colors.white,
        primaryColor,
        0.16,
      )!.withValues(alpha: 0.16),
    );
    _paintCloud(
      canvas,
      size,
      anchor: Offset(size.width * 0.88, size.height * 0.8),
      scale: size.width * 0.17,
      color: Color.lerp(
        Colors.white,
        primaryColor,
        0.12,
      )!.withValues(alpha: 0.15),
    );

    final hazeCenter = Offset(size.width * 0.5, size.height * 0.34);
    final hazeRadius = size.width * 0.3;
    final hazePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withValues(alpha: 0.1),
          secondaryColor.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.58, 1.0],
      ).createShader(Rect.fromCircle(center: hazeCenter, radius: hazeRadius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(hazeCenter, hazeRadius, hazePaint);
  }

  void _paintCloud(
    Canvas canvas,
    Size size, {
    required Offset anchor,
    required double scale,
    required Color color,
  }) {
    final paint = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34);
    final ellipses = <Rect>[
      Rect.fromCenter(
        center: anchor.translate(-scale * 0.62, scale * 0.02),
        width: scale * 1.18,
        height: scale * 0.78,
      ),
      Rect.fromCenter(
        center: anchor.translate(-scale * 0.08, -scale * 0.16),
        width: scale * 1.28,
        height: scale * 0.88,
      ),
      Rect.fromCenter(
        center: anchor.translate(scale * 0.58, scale * 0.04),
        width: scale * 1.08,
        height: scale * 0.74,
      ),
      Rect.fromCenter(
        center: anchor.translate(0, scale * 0.26),
        width: scale * 1.96,
        height: scale * 0.76,
      ),
      Rect.fromCenter(
        center: anchor.translate(scale * 0.18, -scale * 0.04),
        width: scale * 0.92,
        height: scale * 0.6,
      ),
    ];

    for (final ellipse in ellipses) {
      canvas.drawOval(ellipse, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubbleCloudBackdropPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

class _BubbleChip extends StatelessWidget {
  const _BubbleChip({
    required this.label,
    required this.size,
    required this.onTap,
    this.selected = false,
    this.emphasized = false,
    this.isCenter = false,
    this.bubbleStyle,
    this.chipStyle,
    this.icon,
    this.enableBubbleMotion = true,
    this.enableSplashEffect = true,
  });

  final String label;
  final double size;
  final VoidCallback? onTap;
  final bool selected;
  final bool emphasized;
  final bool isCenter;
  final BubbleCloudStyle? bubbleStyle;
  final BubbleChipStyle? chipStyle;
  final IconData? icon;
  final bool enableBubbleMotion;
  final bool enableSplashEffect;

  int _longestWordLength(String text) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 0;
    return words.map((w) => w.length).reduce(math.max);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = bubbleStyle;
    final custom = chipStyle;
    final bubbleColor = isCenter
        ? (custom?.fillColor ??
              palette?.centerFill ??
              Colors.white.withValues(alpha: 0.9))
        : (palette != null
              ? (custom?.fillColor ?? palette.bubbleFill).withValues(
                  alpha: 0.85,
                )
              : (selected || emphasized
                    ? Color.alphaBlend(
                        (palette?.glowColor ?? scheme.primary).withValues(
                          alpha: selected ? 0.18 : 0.1,
                        ),
                        Colors.white.withValues(alpha: 0.72),
                      )
                    : Colors.white.withValues(alpha: 0.66)));
    final glowBaseColor =
        custom?.glowColor ?? palette?.glowColor ?? scheme.primary;
    final borderColor =
        custom?.borderColor ??
        (palette != null
            ? palette.borderColor?.withValues(alpha: 0.6) ??
                  palette.glowColor.withValues(alpha: 0.6)
            : (selected || emphasized
                  ? scheme.primary
                  : scheme.primary.withValues(alpha: 0.24)));
    final glowOpacity = isCenter
        ? (custom?.glowOpacity ?? 0.24)
        : (custom?.glowOpacity ??
              (palette != null
                  ? 0.18
                  : (selected ? 0.26 : (emphasized ? 0.2 : 0.14))));
    final glowBlur = isCenter
        ? (custom?.glowBlur ?? 34.0)
        : (custom?.glowBlur ??
              (palette != null
                  ? 22.0
                  : (selected ? 16.0 : (emphasized ? 14.0 : 11.0))));
    final glowSpread = isCenter
        ? (custom?.glowSpread ?? 1.5)
        : (custom?.glowSpread ??
              (palette != null
                  ? 0.8
                  : (selected ? 1.1 : (emphasized ? 0.7 : 0.2))));
    final shadowColor = Color.lerp(glowBaseColor, Colors.black, 0.12)!;
    final hasIcon = icon != null;
    final isSmallOptionBubble = hasIcon && !isCenter;
    final horizontalInset = isCenter
        ? size * 0.14
        : size * (isSmallOptionBubble ? 0.11 : (hasIcon ? 0.15 : 0.165));
    final verticalInset = isCenter
        ? size * 0.14
        : size * (isSmallOptionBubble ? 0.085 : (hasIcon ? 0.12 : 0.15));
    final contentWidth = math.max(0.0, size - (horizontalInset * 2));
    final fontSize = isCenter
        ? (size / 13.0).clamp(13.5, 16.2)
        : (size / (isSmallOptionBubble ? 13.9 : (hasIcon ? 13.8 : 12.6))).clamp(
            10.7,
            isSmallOptionBubble ? 11.4 : 12.4,
          );
    final longestWord = _longestWordLength(label);
    final minFont = isCenter
        ? 11.5
        : (isSmallOptionBubble ? 10.5 : (longestWord >= 10 ? 8.8 : 9.6));
    final textWidget = _BubbleFittedLabel(
      label: label,
      minFont: minFont,
      maxFont: fontSize,
      maxLines: isSmallOptionBubble ? 2 : (isCenter ? 12 : 8),
      overflow: isSmallOptionBubble ? TextOverflow.visible : TextOverflow.clip,
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: custom?.textColor ?? palette?.textColor,
        height: isCenter ? 1.2 : 1.18,
        fontWeight: isCenter
            ? FontWeight.w600
            : (palette != null
                  ? FontWeight.w500
                  : ((selected || emphasized)
                        ? FontWeight.w700
                        : FontWeight.w500)),
      ),
    );
    final content = Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalInset,
          vertical: verticalInset,
        ),
        child: isSmallOptionBubble
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final iconSize = (size * 0.135).clamp(16.0, 18.0);
                  final gap = (size * 0.028).clamp(3.0, 4.0);
                  final compactContent = SizedBox(
                    width: constraints.maxWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: Offset(0, -size * 0.01),
                          child: Icon(
                            icon,
                            size: iconSize,
                            color:
                                custom?.iconColor ??
                                custom?.textColor ??
                                palette?.textColor,
                          ),
                        ),
                        SizedBox(height: gap),
                        textWidget,
                      ],
                    ),
                  );
                  return Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: compactContent,
                    ),
                  );
                },
              )
            : hasIcon
            ? SizedBox(
                width: contentWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(0, -size * 0.015),
                      child: Icon(
                        icon,
                        size: size * 0.14,
                        color:
                            custom?.iconColor ??
                            custom?.textColor ??
                            palette?.textColor,
                      ),
                    ),
                    SizedBox(height: size * 0.045),
                    textWidget,
                  ],
                ),
              )
            : SizedBox(
                width: contentWidth,
                child: Center(child: textWidget),
              ),
      ),
    );
    return _AnimatedBubbleChip(
      label: label,
      size: size,
      selected: selected,
      emphasized: emphasized,
      onTap: onTap,
      splashColor: glowBaseColor,
      enableFloatingMotion: enableBubbleMotion,
      enableSplashEffect: enableSplashEffect,
      child: Semantics(
        button: onTap != null,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            splashFactory: enableSplashEffect ? null : NoSplash.splashFactory,
            overlayColor: enableSplashEffect
                ? null
                : WidgetStateProperty.all(Colors.transparent),
            highlightColor: enableSplashEffect ? null : Colors.transparent,
            splashColor: enableSplashEffect ? null : Colors.transparent,
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: glowBaseColor.withValues(alpha: glowOpacity),
                        blurRadius: glowBlur,
                        spreadRadius: glowSpread,
                      ),
                      BoxShadow(
                        color: shadowColor.withValues(
                          alpha: isCenter ? 0.12 : 0.1,
                        ),
                        blurRadius: isCenter ? 28 : 20,
                        spreadRadius: isCenter ? -3 : -5,
                        offset: Offset(size * 0.04, size * 0.09),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _GlossyBubblePainter(
                      bubbleColor: bubbleColor,
                      glowColor: glowBaseColor,
                      borderColor: borderColor,
                      centerTintColor:
                          custom?.centerTintColor ??
                          Color.lerp(Colors.white, bubbleColor, 0.22)!,
                      edgeTintColor:
                          custom?.edgeTintColor ??
                          Color.lerp(bubbleColor, glowBaseColor, 0.36)!,
                      borderWidth:
                          custom?.borderWidth ??
                          (palette != null
                              ? 1.5
                              : (selected ? 2.2 : (emphasized ? 1.7 : 1.2))),
                      isCenter: isCenter,
                    ),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlossyBubblePainter extends CustomPainter {
  const _GlossyBubblePainter({
    required this.bubbleColor,
    required this.glowColor,
    required this.borderColor,
    required this.centerTintColor,
    required this.edgeTintColor,
    required this.borderWidth,
    required this.isCenter,
  });

  final Color bubbleColor;
  final Color glowColor;
  final Color borderColor;
  final Color centerTintColor;
  final Color edgeTintColor;
  final double borderWidth;
  final bool isCenter;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circlePath = Path()..addOval(rect);
    final shorterSide = math.min(size.width, size.height);
    final center = rect.center;

    final basePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.42, -0.42),
        radius: 1.26,
        colors: [
          Color.lerp(
            Colors.white,
            centerTintColor,
            0.65,
          )!.withValues(alpha: isCenter ? 0.92 : 0.98),
          Color.lerp(
            centerTintColor,
            bubbleColor,
            0.55,
          )!.withValues(alpha: isCenter ? 0.84 : 0.9),
          Color.lerp(bubbleColor, edgeTintColor, 0.44)!.withValues(alpha: 0.98),
          Color.lerp(edgeTintColor, glowColor, 0.28)!.withValues(alpha: 0.94),
        ],
        stops: const [0.0, 0.34, 0.76, 1.0],
      ).createShader(rect);
    canvas.drawPath(circlePath, basePaint);

    canvas.save();
    canvas.clipPath(circlePath);

    final lowerRightRect = Rect.fromCircle(
      center: Offset(
        center.dx + (size.width * 0.24),
        center.dy + (size.height * 0.28),
      ),
      radius: shorterSide * 0.72,
    );
    canvas.drawOval(
      lowerRightRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(edgeTintColor, glowColor, 0.28)!.withValues(alpha: 0.0),
            Color.lerp(
              edgeTintColor,
              glowColor,
              0.58,
            )!.withValues(alpha: isCenter ? 0.22 : 0.28),
            Color.lerp(
              glowColor,
              Colors.black,
              0.08,
            )!.withValues(alpha: isCenter ? 0.3 : 0.36),
          ],
          stops: const [0.0, 0.58, 1.0],
        ).createShader(lowerRightRect),
    );

    final broadHighlightRect = Rect.fromCircle(
      center: Offset(
        center.dx - (size.width * 0.26),
        center.dy - (size.height * 0.28),
      ),
      radius: shorterSide * 0.62,
    );
    canvas.drawOval(
      broadHighlightRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: isCenter ? 0.4 : 0.46),
            Colors.white.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.44, 1.0],
        ).createShader(broadHighlightRect),
    );

    canvas.save();
    canvas.translate(
      center.dx - (size.width * 0.14),
      center.dy - (size.height * 0.3),
    );
    canvas.rotate(-0.45);
    final shineRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * (isCenter ? 0.76 : 0.68),
      height: size.height * 0.22,
    );
    canvas.drawOval(
      shineRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.72),
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.12),
            Colors.transparent,
          ],
          stops: const [0.0, 0.34, 0.72, 1.0],
        ).createShader(shineRect),
    );
    canvas.restore();

    canvas.save();
    canvas.translate(
      center.dx - (size.width * 0.2),
      center.dy - (size.height * 0.04),
    );
    canvas.rotate(-0.56);
    final secondaryShineRect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 0.34,
      height: size.height * 0.1,
    );
    canvas.drawOval(
      secondaryShineRect,
      Paint()..color = Colors.white.withValues(alpha: isCenter ? 0.28 : 0.24),
    );
    canvas.restore();

    canvas.drawPath(
      circlePath,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.3, 0.42),
          radius: 0.98,
          colors: [
            Colors.transparent,
            Colors.transparent,
            Color.lerp(
              glowColor,
              Colors.black,
              0.28,
            )!.withValues(alpha: isCenter ? 0.12 : 0.16),
          ],
          stops: const [0.0, 0.72, 1.0],
        ).createShader(rect),
    );

    final rimRect = rect.deflate(borderWidth * 0.08);
    canvas.drawOval(
      rimRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: (math.pi * 1.5),
          colors: [
            Colors.white.withValues(alpha: 0.55),
            borderColor.withValues(alpha: 0.8),
            Color.lerp(borderColor, glowColor, 0.3)!.withValues(alpha: 0.92),
            borderColor.withValues(alpha: 0.76),
            Colors.white.withValues(alpha: 0.4),
          ],
          stops: const [0.0, 0.22, 0.58, 0.82, 1.0],
        ).createShader(rimRect),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlossyBubblePainter oldDelegate) {
    return oldDelegate.bubbleColor != bubbleColor ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.centerTintColor != centerTintColor ||
        oldDelegate.edgeTintColor != edgeTintColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.isCenter != isCenter;
  }
}

class _AnimatedBubbleChip extends StatefulWidget {
  const _AnimatedBubbleChip({
    required this.label,
    required this.size,
    required this.selected,
    required this.emphasized,
    required this.onTap,
    required this.splashColor,
    required this.enableFloatingMotion,
    required this.enableSplashEffect,
    required this.child,
  });

  final String label;
  final double size;
  final bool selected;
  final bool emphasized;
  final VoidCallback? onTap;
  final Color splashColor;
  final bool enableFloatingMotion;
  final bool enableSplashEffect;
  final Widget child;

  @override
  State<_AnimatedBubbleChip> createState() => _AnimatedBubbleChipState();
}

class _AnimatedBubbleChipState extends State<_AnimatedBubbleChip>
    with TickerProviderStateMixin {
  AnimationController? _controller;
  AnimationController? _splashController;

  Duration _floatingDuration() {
    final millis = 2800 + (widget.label.hashCode.abs() % 801);
    return Duration(milliseconds: millis);
  }

  double _floatingAmplitude() {
    return 4.0 + (widget.label.hashCode.abs() % 5).toDouble();
  }

  double _floatingPhase() {
    return (widget.label.hashCode.abs() % 360) / 360;
  }

  @override
  void initState() {
    super.initState();
    if (widget.enableFloatingMotion) {
      _controller = AnimationController(
        vsync: this,
        duration: _floatingDuration(),
      )..repeat(reverse: true);
    }
    if (widget.enableSplashEffect) {
      _splashController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 640),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _splashController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _AnimatedBubbleChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableFloatingMotion != widget.enableFloatingMotion) {
      _controller?.dispose();
      _controller = null;
      if (widget.enableFloatingMotion) {
        _controller = AnimationController(
          vsync: this,
          duration: _floatingDuration(),
        )..repeat(reverse: true);
      }
    }
    if (oldWidget.enableSplashEffect != widget.enableSplashEffect) {
      _splashController?.dispose();
      _splashController = null;
      if (widget.enableSplashEffect) {
        _splashController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 640),
        );
      }
    }
    if (!oldWidget.selected && widget.selected) {
      _triggerSplash();
    }
  }

  void _triggerSplash() {
    if (!mounted || _splashController == null) return;
    _splashController!.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final finiteSplashSize = math.max(widget.size + 72, 1).toDouble();
    final stackedContent = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (widget.enableSplashEffect && _splashController != null)
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _splashController!,
                  builder: (context, _) {
                    debugPrint(
                      'ONBOARDING_SPLASH_FINITE_SIZE size=$finiteSplashSize',
                    );
                    return OverflowBox(
                      minWidth: finiteSplashSize,
                      minHeight: finiteSplashSize,
                      maxWidth: finiteSplashSize,
                      maxHeight: finiteSplashSize,
                      child: SizedBox(
                        width: finiteSplashSize,
                        height: finiteSplashSize,
                        child: CustomPaint(
                          size: Size(finiteSplashSize, finiteSplashSize),
                          painter: _BubbleSplashPainter(
                            progress: _splashController!.value,
                            color: widget.splashColor,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
    Widget content = stackedContent;
    if (widget.enableFloatingMotion && _controller != null) {
      final amplitude = _floatingAmplitude();
      final phase = _floatingPhase();
      content = AnimatedBuilder(
        animation: _controller!,
        child: stackedContent,
        builder: (context, child) {
          final wave = math.sin((_controller!.value + phase) * math.pi * 2);
          return Transform.translate(
            offset: Offset(0, wave * amplitude),
            child: child,
          );
        },
      );
    }
    if (widget.onTap == null) {
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _triggerSplash(),
      child: content,
    );
  }
}

class _BubbleSplashPainter extends CustomPainter {
  const _BubbleSplashPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 ||
        size.isEmpty ||
        !size.width.isFinite ||
        !size.height.isFinite) {
      return;
    }

    final eased = Curves.easeOutCubic.transform(progress);
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.shortestSide * 0.52;
    final ringRadius = baseRadius + (size.shortestSide * 0.28 * eased);
    if (!_isFiniteDouble(eased) ||
        !_isFiniteOffset(center) ||
        !_isFiniteDouble(baseRadius) ||
        !_isFiniteDouble(ringRadius) ||
        baseRadius <= 0 ||
        ringRadius <= 0) {
      return;
    }
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(6.0, 1.6, eased)!
      ..color = color.withValues(alpha: (1 - eased) * 0.85);
    if (!_isFiniteDouble(ringPaint.strokeWidth) || ringPaint.strokeWidth <= 0) {
      return;
    }
    canvas.drawCircle(center, ringRadius, ringPaint);

    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(14, 3, eased)!
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14)
      ..color = color.withValues(alpha: (1 - eased) * 0.34);
    final glowRadius = ringRadius * 1.02;
    if (_isFiniteDouble(glowPaint.strokeWidth) &&
        glowPaint.strokeWidth > 0 &&
        _isFiniteDouble(glowRadius) &&
        glowRadius > 0) {
      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final splashOffsets = <Offset>[
      Offset(0, -baseRadius * 1.06),
      Offset(baseRadius * 0.86, -baseRadius * 0.26),
      Offset(baseRadius * 0.72, baseRadius * 0.54),
      Offset(-baseRadius * 0.78, baseRadius * 0.44),
      Offset(-baseRadius * 0.9, -baseRadius * 0.18),
      Offset(baseRadius * 0.18, baseRadius * 0.92),
    ];
    for (final offset in splashOffsets) {
      final scaledOffset = center + (offset * (0.82 + (eased * 0.28)));
      final dotRadius = lerpDouble(6.0, 3.0, eased)!;
      if (!_isFiniteOffset(scaledOffset) ||
          !_isFiniteDouble(dotRadius) ||
          dotRadius <= 0) {
        continue;
      }
      dotPaint.color = color.withValues(alpha: (1 - eased) * 0.82);
      canvas.drawCircle(scaledOffset, dotRadius, dotPaint);
    }
  }

  bool _isFiniteDouble(double value) => value.isFinite && !value.isNaN;

  bool _isFiniteOffset(Offset value) =>
      _isFiniteDouble(value.dx) && _isFiniteDouble(value.dy);

  @override
  bool shouldRepaint(covariant _BubbleSplashPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _BubbleFittedLabel extends StatelessWidget {
  const _BubbleFittedLabel({
    required this.label,
    required this.minFont,
    required this.maxFont,
    required this.maxLines,
    this.textStyle,
    this.overflow = TextOverflow.clip,
  });

  final String label;
  final double minFont;
  final double maxFont;
  final int maxLines;
  final TextStyle? textStyle;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        var font = maxFont;
        while (font >= minFont) {
          final style =
              textStyle?.copyWith(fontSize: font) ??
              TextStyle(fontSize: font, height: 1.2);
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textAlign: TextAlign.center,
            textDirection: direction,
            maxLines: maxLines,
          )..layout(maxWidth: maxWidth);

          if (!painter.didExceedMaxLines && painter.height <= maxHeight) {
            return Text(
              label,
              textAlign: TextAlign.center,
              maxLines: maxLines,
              softWrap: true,
              overflow: overflow,
              style: style,
            );
          }
          font -= 0.5;
        }

        final fallbackStyle =
            textStyle?.copyWith(fontSize: minFont) ??
            TextStyle(fontSize: minFont, height: 1.2);
        return Text(
          label,
          textAlign: TextAlign.center,
          maxLines: maxLines,
          softWrap: true,
          overflow: overflow,
          style: fallbackStyle,
        );
      },
    );
  }
}
