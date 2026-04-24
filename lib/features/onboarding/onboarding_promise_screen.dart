import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/onboarding/onboarding_widgets.dart';

class OnboardingPromiseScreen extends StatelessWidget {
  const OnboardingPromiseScreen({super.key});

  Future<void> _continueToAuth(BuildContext context) async {
    debugPrint('ONBOARDING_CONTINUE_TAPPED');
    debugPrint('ONBOARDING_CONTINUE_NAVIGATE_SIGN_IN');
    await OnboardingController.setSeenLocally(true);
    if (!context.mounted) return;
    context.go('/auth');
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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MyBrainBubble adapts to you.\nNothing here is daily unless you want it to be.\n\nYou can change everything later.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              GlowFilledButton(
                onPressed: () async => _continueToAuth(context),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
