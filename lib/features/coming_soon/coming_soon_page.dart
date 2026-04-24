import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/paper/paper_styles.dart';

class ComingSoonPage extends StatefulWidget {
  const ComingSoonPage({
    super.key,
    required this.title,
    required this.bodyText,
    required this.bottomCardText,
    required this.appBarTitle,
    this.featureKey,
  });

  final String title;
  final String bodyText;
  final String bottomCardText;
  final String appBarTitle;
  final String? featureKey;

  @override
  State<ComingSoonPage> createState() => _ComingSoonPageState();
}

class _ComingSoonPageState extends State<ComingSoonPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    if (widget.featureKey != null && widget.featureKey!.trim().isNotEmpty) {
      debugPrint('COMING_SOON_PAGE_OPENED feature=${widget.featureKey}');
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final babyBlue = styleById('baby_blue');
    final hotPink = styleById('lilac_and_pink');
    final blush = styleById('paper_blush');
    final sky = Color.lerp(babyBlue.paper, scheme.primary, 0.18)!;
    final lilac = Color.lerp(hotPink.paper, scheme.surface, 0.28)!;
    final pinkGlow = Color.lerp(hotPink.accent, blush.accent, 0.45)!;
    final textColor = Color.lerp(scheme.onSurface, babyBlue.text, 0.38)!;
    final mutedColor = Color.lerp(scheme.onSurface, babyBlue.mutedText, 0.5)!;

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: Text(widget.appBarTitle),
        leading: MbGlowBackButton(
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Color.lerp(sky, Colors.white, 0.1)!,
                      Color.lerp(lilac, Colors.white, 0.04)!,
                      Color.lerp(pinkGlow, lilac, 0.75)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: pinkGlow.withValues(alpha: 0.22)),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: pinkGlow.withValues(alpha: 0.12),
                      blurRadius: 32,
                      spreadRadius: 2,
                      offset: const Offset(0, 14),
                    ),
                    BoxShadow(
                      color: sky.withValues(alpha: 0.14),
                      blurRadius: 42,
                      spreadRadius: 2,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(34),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      IgnorePointer(
                        child: CustomPaint(
                          painter: _ComingSoonBackdropPainter(
                            progress: _controller.value,
                            bubbleColor: Colors.white.withValues(alpha: 0.44),
                            sparkleColor: pinkGlow.withValues(alpha: 0.52),
                            accentColor: sky.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                        child: Column(
                          children: <Widget>[
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                    height: 1.05,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxWidth: 420,
                                minHeight: 280,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  Container(
                                    width: 250,
                                    height: 250,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: <Color>[
                                          Colors.white.withValues(alpha: 0.9),
                                          pinkGlow.withValues(alpha: 0.3),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: const Offset(0, 6),
                                    child: Container(
                                      width: 300,
                                      height: 160,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          120,
                                        ),
                                        gradient: RadialGradient(
                                          colors: <Color>[
                                            pinkGlow.withValues(alpha: 0.22),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Image.asset(
                                    'assets/images/bubble_pool/items/bathtub_pastel.png',
                                    width: 210,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.bodyText,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: mutedColor,
                                    height: 1.45,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 22),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                18,
                                18,
                                18,
                                18,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: sky.withValues(alpha: 0.08),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Text(
                                widget.bottomCardText,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: textColor.withValues(alpha: 0.92),
                                      height: 1.45,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ComingSoonBackdropPainter extends CustomPainter {
  const _ComingSoonBackdropPainter({
    required this.progress,
    required this.bubbleColor,
    required this.sparkleColor,
    required this.accentColor,
  });

  final double progress;
  final Color bubbleColor;
  final Color sparkleColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          accentColor.withValues(alpha: 0.18),
          Colors.transparent,
          sparkleColor.withValues(alpha: 0.14),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glowPaint);

    final bubblePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = bubbleColor;
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: 0.1);
    final sparklePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = sparkleColor;

    final bubbles = <({double x, double y, double r, double drift})>[
      (x: 0.16, y: 0.18, r: 24, drift: 0.7),
      (x: 0.84, y: 0.16, r: 18, drift: 0.5),
      (x: 0.1, y: 0.46, r: 13, drift: 0.9),
      (x: 0.88, y: 0.52, r: 20, drift: 0.8),
      (x: 0.2, y: 0.82, r: 16, drift: 0.65),
      (x: 0.78, y: 0.84, r: 28, drift: 0.55),
      (x: 0.53, y: 0.11, r: 10, drift: 0.72),
    ];

    for (final bubble in bubbles) {
      final dx = math.sin((progress * math.pi * 2) + bubble.drift) * 10;
      final dy = math.cos((progress * math.pi * 2) + bubble.drift) * 8;
      final center = Offset(
        size.width * bubble.x + dx,
        size.height * bubble.y + dy,
      );
      canvas.drawCircle(center, bubble.r, fillPaint);
      canvas.drawCircle(center, bubble.r, bubblePaint);
      canvas.drawCircle(
        center.translate(-bubble.r * 0.28, -bubble.r * 0.32),
        bubble.r * 0.15,
        Paint()..color = Colors.white.withValues(alpha: 0.5),
      );
    }

    final sparkles = <Offset>[
      Offset(size.width * 0.23, size.height * 0.34),
      Offset(size.width * 0.74, size.height * 0.29),
      Offset(size.width * 0.68, size.height * 0.67),
      Offset(size.width * 0.34, size.height * 0.72),
      Offset(size.width * 0.5, size.height * 0.2),
    ];
    for (var index = 0; index < sparkles.length; index++) {
      final sparkle = sparkles[index];
      final pulse =
          0.7 + 0.3 * math.sin((progress * math.pi * 2) + (index * 0.9)).abs();
      _drawSparkle(canvas, sparkle, 7.5 * pulse, sparklePaint);
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.24, center.dy - radius * 0.24)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx + radius * 0.24, center.dy + radius * 0.24)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.24, center.dy + radius * 0.24)
      ..lineTo(center.dx - radius, center.dy)
      ..lineTo(center.dx - radius * 0.24, center.dy - radius * 0.24)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ComingSoonBackdropPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.bubbleColor != bubbleColor ||
        oldDelegate.sparkleColor != sparkleColor ||
        oldDelegate.accentColor != accentColor;
  }
}
