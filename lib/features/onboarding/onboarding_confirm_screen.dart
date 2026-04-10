import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/features/onboarding/onboarding_apply.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/onboarding/onboarding_widgets.dart';

class OnboardingConfirmScreen extends ConsumerWidget {
  const OnboardingConfirmScreen({super.key});

  Future<void> _finishOnboarding(BuildContext context, WidgetRef ref) async {
    final answers = ref.read(onboardingControllerProvider);
    await applyOnboardingAnswers(ref, answers);
    await OnboardingController.markCompleted();
    await CompletionGateRepository.markOnboardingCompleted();

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('subscription_tier')
          .eq('id', user.id)
          .maybeSingle();
      final tier = (profile?['subscription_tier'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final pending = profile != null && (tier.isEmpty || tier == 'pending');
      if (pending) {
        if (context.mounted) {
          context.go('/onboarding/plan');
        }
        return;
      }
    }

    if (context.mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        leading: MbGlowBackButton(onPressed: () => context.pop()),
        title: const Text(''),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "We've set things up gently.",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                shadows: [
                  Shadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _Bullet(
              text: "You'll only see reminders if you turn them on",
            ),
            const _Bullet(text: 'Many days can stay quiet'),
            const _Bullet(
              text: 'Nothing breaks if you stop using the app for a while',
            ),
            const Spacer(),
            GlowFilledButton(
              onPressed: () => _finishOnboarding(context, ref),
              child: const Text('Enter MyBrainBubble'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () async {
                final answers = ref.read(onboardingControllerProvider);
                await applyOnboardingAnswers(ref, answers);
                await OnboardingController.markCompleted();
                await CompletionGateRepository.markOnboardingCompleted();
                if (context.mounted) {
                  context.go('/settings');
                }
              },
              child: const Text('Adjust settings now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
