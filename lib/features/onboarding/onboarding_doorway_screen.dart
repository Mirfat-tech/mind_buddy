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
  late Set<String> _selected;

  static const _options = <(String, String)>[
    ('mental', 'My mental headspace'),
    ('admin', 'My admin, money, or "adulting"'),
    ('body', 'My body and routines'),
    ('everything', 'Honestly? Everything'),
    ('nothing', 'Nothing right now'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = {...ref.read(onboardingControllerProvider).slipFirst};
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
    ref.read(onboardingControllerProvider.notifier).setSlipFirst(_selected);
    context.go('/onboarding/expression');
  }

  void _skipQuestion() {
    ref.read(onboardingControllerProvider.notifier).clearSlipFirst();
    context.go('/onboarding/expression');
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
                centerText:
                    'Life is a lot to hold.\nWhen things get busy, what\'s usually the first thing to slip through the cracks?',
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
            const OnboardingDots(current: 0, total: 3),
          ],
        ),
      ),
    );
  }
}
