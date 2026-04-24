import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/onboarding/onboarding_widgets.dart';
import 'package:mind_buddy/paper/paper_styles.dart';

class OnboardingDoorwayScreen extends ConsumerStatefulWidget {
  const OnboardingDoorwayScreen({super.key});

  @override
  ConsumerState<OnboardingDoorwayScreen> createState() =>
      _OnboardingDoorwayScreenState();
}

class _OnboardingDoorwayScreenState
    extends ConsumerState<OnboardingDoorwayScreen> {
  String? _selected;

  static const _options = <(String, String)>[
    ('gratitude', 'My Gratitude'),
    ('brain_fog', 'My Brain Fog'),
  ];

  @override
  void initState() {
    super.initState();
    final previous = ref.read(onboardingControllerProvider).slipFirst;
    _selected = previous.isEmpty ? null : previous.first;
  }

  void _toggle(String value) {
    setState(() {
      _selected = value;
    });
    ref.read(onboardingControllerProvider.notifier).setSlipFirst({value});
    debugPrint('ONBOARDING_DOORWAY_OPTION_TAPPED value=$value');
    final route = switch (value) {
      'brain_fog' => '/onboarding/experience/brain-fog',
      'gratitude' => '/onboarding/experience/gratitude',
      _ => '/auth',
    };
    debugPrint('ONBOARDING_DOORWAY_NAVIGATE_EXPERIENCE route=$route');
    context.go(route);
  }

  Future<void> _continue() async {
    debugPrint('ONBOARDING_DOORWAY_CONTINUE_TAPPED');
    debugPrint('ONBOARDING_DOORWAY_NAVIGATE_AUTH route=/auth');
    await OnboardingController.setSeenLocally(true);
    if (!mounted) return;
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    final style = styleById('baby_blue');
    final babyBlueStyle = styleById('baby_blue');
    const gratitudeAccent = Color(0xFFFF4FB7);
    const brainFogStrongBlue = Color(0xFF1F5FCC);
    final centerBubbleStyle = BubbleChipStyle(
      fillColor: Colors.white.withValues(alpha: 0.22),
      borderColor: style.accent.withValues(alpha: 0.7),
      glowColor: style.accent,
      textColor: style.text,
      iconColor: style.text,
      centerTintColor: const Color(0xFFF4F5F9),
      edgeTintColor: Colors.white,
      glowOpacity: 0.2,
      glowBlur: 34,
      glowSpread: 3.2,
      borderWidth: 1.5,
    );
    final gratitudeBubbleStyle = BubbleChipStyle(
      fillColor: Color.lerp(
        Colors.white,
        gratitudeAccent,
        0.06,
      )!.withValues(alpha: 0.28),
      borderColor: gratitudeAccent.withValues(alpha: 0.72),
      glowColor: gratitudeAccent,
      textColor: gratitudeAccent.withValues(alpha: 0.9),
      iconColor: gratitudeAccent.withValues(alpha: 0.9),
      sizeMultiplier: 1.14,
      centerTintColor: Color.lerp(Colors.white, gratitudeAccent, 0.18),
      edgeTintColor: Color.lerp(Colors.white, gratitudeAccent, 0.04),
      glowOpacity: 0.26,
      glowBlur: 42,
      glowSpread: 4.2,
      borderWidth: 1.5,
    );
    final brainFogBubbleStyle = BubbleChipStyle(
      fillColor: Color.lerp(
        Colors.white,
        babyBlueStyle.border,
        0.08,
      )!.withValues(alpha: 0.28),
      borderColor: babyBlueStyle.border.withValues(alpha: 0.92),
      glowColor: babyBlueStyle.border,
      textColor: brainFogStrongBlue,
      iconColor: brainFogStrongBlue,
      sizeMultiplier: 1.14,
      centerTintColor: Color.lerp(Colors.white, babyBlueStyle.border, 0.18),
      edgeTintColor: Color.lerp(Colors.white, babyBlueStyle.border, 0.05),
      glowOpacity: 0.26,
      glowBlur: 42,
      glowSpread: 4.2,
      borderWidth: 1.5,
    );
    final backdropStyle = BubbleCloudBackdropStyle(
      primaryColor: style.accent,
      secondaryColor: babyBlueStyle.border,
    );

    return MbScaffold(
      applyBackground: true,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(''),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ColoredBox(
        color: babyBlueStyle.paper,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              final width = constraints.maxWidth;
              final horizontalPadding = width < 360 ? 14.0 : 16.0;
              final topPadding = height < 760 ? 4.0 : 8.0;
              final bottomPadding = height < 760 ? 12.0 : 16.0;
              final buttonGap = height < 760 ? 12.0 : 14.0;
              final bottomGap = height < 760 ? 16.0 : 24.0;

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  topPadding,
                  horizontalPadding,
                  bottomPadding,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: OnboardingBubbleCloud(
                        centerText:
                            'What would your\nmind like to focus\non today?',
                        layout: BubbleCloudLayout.upperCenterRow,
                        centerBubbleStyle: centerBubbleStyle,
                        backdropStyle: backdropStyle,
                        centerGlowColor: style.accent,
                        centerEnableBubbleMotion: false,
                        showInstruction: false,
                        enableBubbleMotion: true,
                        enableSplashEffect: false,
                        choices: [
                          for (final (value, label) in _options)
                            BubbleChoice(
                              label: label,
                              selected: _selected == value,
                              onTap: () => _toggle(value),
                              icon: switch (value) {
                                'gratitude' => Icons.favorite_border_rounded,
                                'brain_fog' => Icons.cloud_outlined,
                                _ => null,
                              },
                              style: switch (value) {
                                'gratitude' => gratitudeBubbleStyle,
                                'brain_fog' => brainFogBubbleStyle,
                                _ => null,
                              },
                            ),
                        ],
                      ),
                    ),
                    Text(
                      'Tap bubbles to select',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: style.mutedText.withValues(alpha: 0.78),
                      ),
                    ),
                    SizedBox(height: buttonGap),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _continue,
                        child: const Text('Continue'),
                      ),
                    ),
                    SizedBox(height: bottomGap),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
