import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/onboarding/onboarding_widgets.dart';

class OnboardingExpressionScreen extends ConsumerStatefulWidget {
  const OnboardingExpressionScreen({super.key});

  @override
  ConsumerState<OnboardingExpressionScreen> createState() =>
      _OnboardingExpressionScreenState();
}

class _OnboardingExpressionScreenState
    extends ConsumerState<OnboardingExpressionScreen> {
  late Set<String> _selected;

  static const _options = <(String, String)>[
    ('colors', 'By journaling'),
    ('photos', 'By talking about it'),
    ('videos', 'Through photos & videos'),
    ('all', 'All of the above'),
    ('none', 'None of the above'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = {...ref.read(onboardingControllerProvider).expressionStyle};
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

  void _continue() {
    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.setExpressionStyle(_selected);
    controller.setSkippedPersonalization(false);
    context.go('/onboarding/lookback');
  }

  void _skipQuestion() {
    final controller = ref.read(onboardingControllerProvider.notifier);
    controller.clearExpressionStyle();
    controller.setSkippedPersonalization(true);
    context.go('/onboarding/lookback');
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
                centerText: 'How do you like to express or remember things?',
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
            const OnboardingDots(current: 1, total: 3),
          ],
        ),
      ),
    );
  }
}
