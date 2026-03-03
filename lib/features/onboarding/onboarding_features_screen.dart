import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';

class OnboardingFeaturesScreen extends StatefulWidget {
  const OnboardingFeaturesScreen({super.key});

  @override
  State<OnboardingFeaturesScreen> createState() =>
      _OnboardingFeaturesScreenState();
}

class _OnboardingFeaturesScreenState extends State<OnboardingFeaturesScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _slides = <_FeatureSlide>[
    _FeatureSlide(
      icon: Icons.auto_awesome,
      title: 'Your calm command center',
      subtitle: 'Track mood, routines, and thoughts without noisy pressure.',
    ),
    _FeatureSlide(
      icon: Icons.insights_outlined,
      title: 'See patterns clearly',
      subtitle: 'Insights help you notice what is working and what needs care.',
    ),
    _FeatureSlide(
      icon: Icons.favorite_outline,
      title: 'Built for real life',
      subtitle:
          'Quiet defaults, flexible reminders, and room for imperfect days.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeAndContinue() async {
    await OnboardingController.markFeaturesSeen();
    if (!mounted) return;
    context.go('/onboarding/plan');
  }

  Future<void> _next() async {
    if (_index == _slides.length - 1) {
      await _completeAndContinue();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        title: const Text('Welcome'),
        actions: [
          TextButton(
            onPressed: _completeAndContinue,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (v) => setState(() => _index = v),
                  itemBuilder: (context, index) {
                    final item = _slides[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(item.icon, size: 84),
                        const SizedBox(height: 20),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 8,
                    width: _index == i ? 20 : 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      color: _index == i
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _next,
                child: Text(
                  _index == _slides.length - 1 ? 'Get Started' : 'Next',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                slide.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureSlide {
  const _FeatureSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
