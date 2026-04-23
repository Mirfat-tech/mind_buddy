import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:mind_buddy/features/bubble_coins/widgets/bubble_coin_icon.dart';

class BubbleCoinRewardBurst extends StatefulWidget {
  const BubbleCoinRewardBurst({
    super.key,
    required this.playCount,
    this.alignment = Alignment.topCenter,
    this.padding = const EdgeInsets.only(top: 8),
    this.showPlusOne = true,
  });

  final int playCount;
  final Alignment alignment;
  final EdgeInsets padding;
  final bool showPlusOne;

  @override
  State<BubbleCoinRewardBurst> createState() => _BubbleCoinRewardBurstState();
}

class _BubbleCoinRewardBurstState extends State<BubbleCoinRewardBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1180),
  );

  @override
  void didUpdateWidget(covariant BubbleCoinRewardBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playCount != oldWidget.playCount && widget.playCount > 0) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: widget.alignment,
        child: Padding(
          padding: widget.padding,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.value <= 0 || _controller.status.isDismissed) {
                return const SizedBox.shrink();
              }
              final curve = Curves.easeOutCubic.transform(_controller.value);
              final fadeOut = (1 - Curves.easeIn.transform(_controller.value))
                  .clamp(0.0, 1.0);
              final pop = _coinScale(_controller.value);
              final rise = 34 * curve;
              final glowOpacity = (1 - _controller.value).clamp(0.0, 1.0);
              final shimmerOpacity = (0.22 * glowOpacity).clamp(0.0, 1.0);

              return Opacity(
                opacity: fadeOut,
                child: Transform.translate(
                  offset: Offset(0, -rise),
                  child: SizedBox(
                    width: 132,
                    height: 132,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(
                                  alpha: shimmerOpacity * 0.65,
                                ),
                                Theme.of(context).colorScheme.primary
                                    .withValues(alpha: 0.06 * glowOpacity),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).colorScheme.primary
                                    .withValues(alpha: 0.16 * glowOpacity),
                                blurRadius: 32,
                                spreadRadius: 6,
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(
                                  alpha: 0.1 * glowOpacity,
                                ),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        ..._buildParticles(context, _controller.value),
                        Transform.scale(
                          scale: pop,
                          child: const BubbleCoinIcon(size: 54),
                        ),
                        if (widget.showPlusOne)
                          Positioned(
                            top: 14,
                            child: Opacity(
                              opacity: (0.96 - (_controller.value * 0.75))
                                  .clamp(0.0, 1.0),
                              child: Transform.translate(
                                offset: Offset(0, -12 * curve),
                                child: Text(
                                  '+1',
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  double _coinScale(double t) {
    if (t < 0.22) {
      return lerpDouble(0.74, 1.12, Curves.easeOutBack.transform(t / 0.22)) ??
          1;
    }
    final settle = ((t - 0.22) / 0.78).clamp(0.0, 1.0);
    return lerpDouble(1.12, 1.0, Curves.easeOut.transform(settle)) ?? 1;
  }

  List<Widget> _buildParticles(BuildContext context, double t) {
    final scheme = Theme.of(context).colorScheme;
    const specs =
        <
          ({
            double angle,
            double distance,
            double size,
            double delay,
            bool soft,
          })
        >[
          (angle: -1.9, distance: 32, size: 9, delay: 0.00, soft: false),
          (angle: -1.3, distance: 40, size: 6, delay: 0.03, soft: true),
          (angle: -0.65, distance: 35, size: 7, delay: 0.05, soft: false),
          (angle: -0.1, distance: 30, size: 5, delay: 0.01, soft: true),
          (angle: 0.55, distance: 36, size: 7, delay: 0.08, soft: false),
          (angle: 1.15, distance: 31, size: 8, delay: 0.04, soft: false),
          (angle: 1.7, distance: 27, size: 5, delay: 0.06, soft: true),
        ];

    return [
      for (final spec in specs)
        _BubbleParticle(
          progress: ((t - spec.delay) / (1 - spec.delay)).clamp(0.0, 1.0),
          angle: spec.angle,
          distance: spec.distance,
          size: spec.size,
          soft: spec.soft,
          color:
              Color.lerp(
                scheme.primary.withValues(alpha: 0.3),
                scheme.surface,
                0.45,
              ) ??
              scheme.primary,
        ),
    ];
  }
}

class _BubbleParticle extends StatelessWidget {
  const _BubbleParticle({
    required this.progress,
    required this.angle,
    required this.distance,
    required this.size,
    required this.soft,
    required this.color,
  });

  final double progress;
  final double angle;
  final double distance;
  final double size;
  final bool soft;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();
    final eased = Curves.easeOut.transform(progress);
    final dx = math.cos(angle) * distance * eased;
    final dy = math.sin(angle) * distance * eased - (10 * eased);
    final opacity = (1 - Curves.easeIn.transform(progress)).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: soft ? 0.22 : 0.14),
                color.withValues(alpha: soft ? 0.18 : 0.24),
              ],
            ),
            border: Border.all(
              color: color.withValues(alpha: soft ? 0.26 : 0.38),
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: soft ? 0.12 : 0.18),
                blurRadius: soft ? 8 : 10,
                spreadRadius: soft ? 1 : 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
