import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/onboarding/onboarding_apply.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/onboarding/onboarding_widgets.dart';

class OnboardingLookbackScreen extends ConsumerStatefulWidget {
  const OnboardingLookbackScreen({super.key});

  @override
  ConsumerState<OnboardingLookbackScreen> createState() =>
      _OnboardingLookbackScreenState();
}

class _OnboardingLookbackScreenState
    extends ConsumerState<OnboardingLookbackScreen> {
  late Set<String> _selected;

  static const _options = <(String, String)>[
    ('patterns', 'A clear picture of patterns and progress'),
    ('scrapbook', 'A colourful, lived-in scrapbook'),
    ('reflection', 'Moments of reflection and emotional growth'),
    ('mix', 'Honestly? A mix of everything'),
    ('unsure', "I'm not sure yet"),
  ];

  @override
  void initState() {
    super.initState();
    _selected = {...ref.read(onboardingControllerProvider).lookingBack};
  }

  void _toggle(String value) {
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });
  }

  Future<void> _continue() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.setLookingBack(_selected);
    controller.setSkippedPersonalization(false);
    await applyOnboardingAnswers(ref, ref.read(onboardingControllerProvider));
    await OnboardingController.setSetupCompleted(true);
    if (!mounted) return;
    context.go('/onboarding/plan');
  }

  Future<void> _skipQuestion() async {
    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.clearLookingBack();
    controller.setSkippedPersonalization(true);
    await OnboardingController.setSetupCompleted(true);
    if (!mounted) return;
    context.go('/onboarding/plan');
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        leading: MbGlowBackButton(onPressed: () => context.pop()),
        title: const Text(''),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Expanded(
              child: OnboardingBubbleCloud(
                centerText:
                    'When you look back on this year, what do you hope you see?',
                choices: [
                  for (final (value, label) in _options)
                    BubbleChoice(
                      label: label,
                      selected: _selected.contains(value),
                      onTap: () => _toggle(value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty ? null : _continue,
                child: const Text('Continue'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _skipQuestion,
              child: const Text('Skip for now'),
            ),
            const SizedBox(height: 8),
            const OnboardingDots(current: 2, total: 3),
          ],
        ),
      ),
    );
  }
}
