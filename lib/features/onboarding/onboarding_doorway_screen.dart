import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/onboarding/onboarding_widgets.dart';

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
    debugPrint(
      '[OnboardingDoorway] option_tapped value=$value selected=true current_page=0',
    );
    _continue();
  }

  void _continue() {
    final selected = _selected;
    if (selected == null) return;
    final nextRoute = switch (selected) {
      'gratitude' => '/onboarding/experience/gratitude',
      'brain_fog' => '/onboarding/experience/brain-fog',
      _ => '/onboarding/doorway',
    };
    debugPrint(
      '[OnboardingDoorway] continue_tapped selected=$selected current_page=0 next=$nextRoute',
    );
    ref.read(onboardingControllerProvider.notifier).setSlipFirst({selected});
    context.go(nextRoute);
  }

  Future<void> _skipQuestion() async {
    debugPrint('[OnboardingDoorway] skip_tapped current_page=0');
    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.clearSlipFirst();
    controller.clearExpressionStyle();
    controller.clearLookingBack();
    debugPrint('[OnboardingDoorway] skip_saved next=/auth');
    if (!mounted) return;
    context.go('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(title: const Text(''), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Expanded(
              child: OnboardingBubbleCloud(
                centerText: 'What would your mind like to focus on today?',
                choices: [
                  for (final (value, label) in _options)
                    BubbleChoice(
                      label: label,
                      selected: _selected == value,
                      onTap: () => _toggle(value),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected == null ? null : _continue,
                child: const Text('Continue'),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: _skipQuestion,
              child: const Text('Skip for now'),
            ),
            const SizedBox(height: 8),
            const OnboardingDots(current: 0, total: 3),
          ],
        ),
      ),
    );
  }
}
