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
  bool _submitting = false;

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
    if (_submitting) return;
    setState(() {
      if (_selected.contains(value)) {
        _selected.remove(value);
      } else {
        _selected.add(value);
      }
    });
    debugPrint(
      '[OnboardingLookback] option_tapped value=$value selected=${_selected.contains(value)} current_page=2',
    );
  }

  Future<void> _continue() async {
    if (_submitting || _selected.isEmpty) return;
    debugPrint(
      '[OnboardingLookback] continue_tapped selected=$_selected current_page=2',
    );
    setState(() => _submitting = true);
    final controller = ref.read(onboardingControllerProvider.notifier);
    try {
      controller.setLookingBack(_selected);
      controller.setSkippedPersonalization(false);
      try {
        await applyOnboardingAnswers(
          ref,
          ref.read(onboardingControllerProvider),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {
        // Personalization should not block finishing onboarding.
      }
      await OnboardingController.setSetupCompleted(true);
      await CompletionGateRepository.markOnboardingCompleted();
      debugPrint(
        '[OnboardingLookback] completion_saved onboarding_completed=true next=/bootstrap',
      );
      if (!mounted) return;
      context.go('/bootstrap');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _skipQuestion() async {
    if (_submitting) return;
    debugPrint('[OnboardingLookback] skip_tapped current_page=2');
    setState(() => _submitting = true);
    final controller = ref.read(onboardingControllerProvider.notifier);
    try {
      controller.clearLookingBack();
      controller.setSkippedPersonalization(true);
      await OnboardingController.setSetupCompleted(true);
      await CompletionGateRepository.markOnboardingCompleted();
      debugPrint(
        '[OnboardingLookback] skip_saved onboarding_completed=true next=/bootstrap',
      );
      if (!mounted) return;
      context.go('/bootstrap');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
                onPressed: _selected.isEmpty || _submitting ? null : _continue,
                child: Text(_submitting ? 'Saving...' : 'Continue'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _submitting ? null : _skipQuestion,
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
