import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mind_buddy/features/settings/settings_provider.dart';
import 'package:mind_buddy/paper/paper_styles.dart';

class TestPage extends ConsumerWidget {
  const TestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider).settings;
    final rawThemeId = settings.themeId;
    final resolvedThemeId = rawThemeId == null || rawThemeId.trim().isEmpty
        ? kDefaultThemeId
        : rawThemeId;
    final style = styleById(resolvedThemeId);

    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: style.text,
      fontWeight: FontWeight.w700,
      height: 1.2,
    );
    final captionStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: style.mutedText, height: 1.35);

    return Scaffold(
      backgroundColor: style.paper,
      body: Stack(
        children: [
          Positioned.fill(child: _BubbleBackdrop(style: style)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            _GlassIconButton(
                              icon: Icons.arrow_back_rounded,
                              style: style,
                              onTap: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/settings'),
                            ),
                            const Spacer(),
                            Text(
                              'Test Page',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: style.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 44),
                          ],
                        ),
                        const SizedBox(height: 38),
                        _PromptSphere(
                          style: style,
                          titleStyle: titleStyle,
                          captionStyle: captionStyle,
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 18,
                          runSpacing: 18,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -4),
                              child: _ChoiceBubble(
                                label: "It's feeling grateful",
                                style: style,
                                size: 148,
                                onTap: () => context.go('/gratitude-bubble'),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, 6),
                              child: _ChoiceBubble(
                                label: "It's feeling full",
                                style: style,
                                size: 138,
                                onTap: () => context.go('/brain-fog'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptSphere extends StatelessWidget {
  const _PromptSphere({
    required this.style,
    required this.titleStyle,
    required this.captionStyle,
  });

  final PaperStyle style;
  final TextStyle? titleStyle;
  final TextStyle? captionStyle;

  @override
  Widget build(BuildContext context) {
    final promptFill = Color.lerp(style.boxFill, Colors.white, 0.34)!;
    final innerFill = Color.lerp(style.paper, Colors.white, 0.58)!;
    final glow = style.accent.withValues(alpha: 0.22);
    final sphereSize = math.min(
      MediaQuery.of(context).size.width * 0.72,
      300.0,
    );

    return Container(
      width: sphereSize,
      height: sphereSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.98),
            innerFill,
            promptFill,
            Color.lerp(style.paper, style.boxFill, 0.42)!,
          ],
          stops: const [0.06, 0.32, 0.7, 1],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.74),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(color: glow, blurRadius: 42, spreadRadius: 10),
          BoxShadow(
            color: style.border.withValues(alpha: 0.16),
            blurRadius: 22,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: style.text.withValues(alpha: 0.06),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(sphereSize * 0.04),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: style.border.withValues(alpha: 0.2),
                  ),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                    stops: const [0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: sphereSize * 0.17,
            top: sphereSize * 0.14,
            child: Container(
              width: sphereSize * 0.18,
              height: sphereSize * 0.18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.52),
              ),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: sphereSize * 0.14),
              child: Center(
                child: Text(
                  'How is your mind feeling today, genuinely?',
                  textAlign: TextAlign.center,
                  style: titleStyle,
                ),
              ),
            ),
          ),
          Positioned(
            right: sphereSize * 0.16,
            bottom: sphereSize * 0.15,
            child: Text(
              'Choose a bubble below',
              style: captionStyle?.copyWith(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceBubble extends StatelessWidget {
  const _ChoiceBubble({
    required this.label,
    required this.style,
    required this.size,
    required this.onTap,
  });

  final String label;
  final PaperStyle style;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = Color.lerp(style.boxFill, Colors.white, 0.28)!;
    final innerFill = Color.lerp(style.paper, Colors.white, 0.52)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.96),
                innerFill,
                fill,
                Color.lerp(style.paper, style.boxFill, 0.46)!,
              ],
              stops: const [0.08, 0.34, 0.72, 1],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.72),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: style.accent.withValues(alpha: 0.14),
                blurRadius: 28,
                spreadRadius: 3,
              ),
              BoxShadow(
                color: style.border.withValues(alpha: 0.16),
                blurRadius: 14,
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.all(size * 0.04),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: style.border.withValues(alpha: 0.16),
                      ),
                      gradient: RadialGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.18),
                          Colors.transparent,
                        ],
                        stops: const [0.4, 1],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: size * 0.18,
                top: size * 0.14,
                child: Container(
                  width: size * 0.14,
                  height: size * 0.14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: size * 0.14),
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: style.text,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      fontSize: size < 144 ? 14 : 14.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({
    required this.icon,
    required this.style,
    required this.onTap,
  });

  final IconData icon;
  final PaperStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Color.lerp(
            style.boxFill,
            Colors.white,
            0.24,
          )!.withValues(alpha: 0.86),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: style.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleBackdrop extends StatelessWidget {
  const _BubbleBackdrop({required this.style});

  final PaperStyle style;

  @override
  Widget build(BuildContext context) {
    final mist = Color.lerp(style.paper, style.boxFill, 0.44)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(style.paper, Colors.white, 0.05)!,
            Color.lerp(style.paper, mist, 0.52)!,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 1.05,
                    colors: [
                      style.accent.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: -40,
            top: 100,
            child: _BackdropOrb(
              size: 160,
              color: style.accent.withValues(alpha: 0.07),
            ),
          ),
          Positioned(
            right: -30,
            top: 180,
            child: _BackdropOrb(
              size: 130,
              color: style.border.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            right: 30,
            bottom: 120,
            child: _BackdropOrb(
              size: 94,
              color: style.accent.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  const _BackdropOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.22),
            color,
            color.withValues(alpha: 0.08),
          ],
          stops: const [0.0, 0.52, 1.0],
        ),
      ),
    );
  }
}
