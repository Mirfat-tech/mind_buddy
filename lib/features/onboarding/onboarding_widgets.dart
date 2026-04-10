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
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool emphasized;
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
  });

  final String centerText;
  final List<BubbleChoice> choices;
  final String? instructionText;
  final BubbleCloudStyle? style;

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

        var centerSize = _estimateCenterSize(centerText, base);
        final rawOptionSizes = [
          for (final choice in choices)
            _estimateOptionSize(choice.label, base * 0.20 + 72),
        ];
        final safeOptionSizes = rawOptionSizes.isEmpty
            ? <double>[120]
            : rawOptionSizes;
        var optionSizes = List<double>.from(safeOptionSizes);
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
          final center = Offset(width / 2, height / 2);
          final maxRadiusLeft = center.dx - safeLeft - optionRadius;
          final maxRadiusRight = safeRight - center.dx - optionRadius;
          final maxRadiusTop = center.dy - safeTop - optionRadius;
          final maxRadiusBottom = safeBottom - center.dy - optionRadius;
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

        final center = Offset(width / 2, height / 2);
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

        return Stack(
          children: [
            Positioned(
              left: center.dx - (centerSize / 2),
              top: center.dy - (centerSize / 2),
              child: _BubbleChip(
                label: centerText,
                size: centerSize,
                isCenter: true,
                onTap: null,
                bubbleStyle: style,
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
                    ),
                  );
                },
              ),
            if (instructionText != null)
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
  });

  final String label;
  final double size;
  final VoidCallback? onTap;
  final bool selected;
  final bool emphasized;
  final bool isCenter;
  final BubbleCloudStyle? bubbleStyle;

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
    final bubbleColor = isCenter
        ? (palette?.centerFill ?? Colors.white.withValues(alpha: 0.9))
        : (palette != null
              ? palette.bubbleFill.withValues(alpha: 0.85)
              : (selected || emphasized
                    ? Color.alphaBlend(
                        (palette?.glowColor ?? scheme.primary).withValues(
                          alpha: selected ? 0.18 : 0.1,
                        ),
                        Colors.white.withValues(alpha: 0.72),
                      )
                    : Colors.white.withValues(alpha: 0.66)));
    final glowOpacity = isCenter
        ? 0.6
        : (palette != null ? 0.45 : (selected ? 0.26 : (emphasized ? 0.2 : 0.14)));
    final glowBlur = isCenter
        ? 40.0
        : (palette != null ? 25.0 : (selected ? 16.0 : (emphasized ? 14.0 : 11.0)));
    final glowSpread = isCenter
        ? 5.0
        : (palette != null ? 2.0 : (selected ? 1.1 : (emphasized ? 0.7 : 0.2)));
    final fontSize = isCenter
        ? (size / 12.2).clamp(14.0, 17.0)
        : (size / 11.8).clamp(11.0, 13.2);
    final longestWord = _longestWordLength(label);
    final minFont = isCenter ? 11.5 : (longestWord >= 10 ? 9.2 : 10.0);
    final padding = isCenter ? 22.0 : 16.0;
    final textWidget = _BubbleFittedLabel(
      label: label,
      minFont: minFont,
      maxFont: fontSize,
      maxLines: isCenter ? 12 : 8,
      textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: palette?.textColor,
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

    return _AnimatedBubbleChip(
      label: label,
      selected: selected,
      emphasized: emphasized,
      onTap: onTap,
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
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: size,
                  height: size,
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bubbleColor,
                    border: isCenter
                        ? null
                        : Border.all(
                            color: palette != null
                                ? palette.borderColor?.withValues(alpha: 0.6) ??
                                    (palette.glowColor.withValues(alpha: 0.6))
                                : (selected || emphasized
                                      ? scheme.primary
                                      : scheme.primary.withValues(alpha: 0.24)),
                            width: palette != null
                                ? 1.5
                                : (selected ? 2.2 : (emphasized ? 1.7 : 1.2)),
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: (palette?.glowColor ?? scheme.primary).withValues(
                          alpha: glowOpacity,
                        ),
                        blurRadius: glowBlur,
                        spreadRadius: glowSpread,
                      ),
                    ],
                  ),
                  child: Center(child: textWidget),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedBubbleChip extends StatefulWidget {
  const _AnimatedBubbleChip({
    required this.label,
    required this.selected,
    required this.emphasized,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final bool emphasized;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_AnimatedBubbleChip> createState() => _AnimatedBubbleChipState();
}

class _AnimatedBubbleChipState extends State<_AnimatedBubbleChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final baseScale = widget.selected ? 1.03 : (widget.emphasized ? 1.02 : 1.0);
    final pressedScale = _pressed ? 0.97 : 1.0;
    final animatedChild = AnimatedScale(
      scale: baseScale * pressedScale,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: widget.child,
    );
    if (widget.onTap == null) {
      return animatedChild;
    }

    final phase = (widget.label.hashCode % 7) / 7;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedBuilder(
        animation: _controller,
        child: animatedChild,
        builder: (context, child) {
          final wave = math.sin((_controller.value + phase) * math.pi * 2);
          return Transform.translate(offset: Offset(0, wave * 4), child: child);
        },
      ),
    );
  }
}

class _BubbleFittedLabel extends StatelessWidget {
  const _BubbleFittedLabel({
    required this.label,
    required this.minFont,
    required this.maxFont,
    required this.maxLines,
    this.textStyle,
  });

  final String label;
  final double minFont;
  final double maxFont;
  final int maxLines;
  final TextStyle? textStyle;

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
              overflow: TextOverflow.clip,
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
          overflow: TextOverflow.clip,
          style: fallbackStyle,
        );
      },
    );
  }
}
