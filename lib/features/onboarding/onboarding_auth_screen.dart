import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/onboarding/onboarding_widgets.dart';
import 'package:mind_buddy/services/oauth_sign_in_coordinator.dart';

class OnboardingAuthScreen extends ConsumerWidget {
  const OnboardingAuthScreen({super.key});

  Future<void> _signInWithOAuth(
    BuildContext context,
    OAuthProvider provider,
  ) async {
    final res = await OAuthSignInCoordinator.instance.start(provider);
    if (!context.mounted || res.started) return;
    final message =
        (res.message ?? '').toLowerCase().contains('bad_code_verifier')
        ? 'Login expired - please try again.'
        : (res.message ?? 'OAuth sign in could not be started.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(onboardingControllerProvider.notifier);

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        leading: MbGlowBackButton(onPressed: () => context.pop()),
        title: const Text(''),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height * 0.72,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Want us to save your space?',
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
                const SizedBox(height: 12),
                Text(
                  'Creating an account lets us remember your pages, logs, and settings — so you can come back whenever you need.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                ValueListenableBuilder<bool>(
                  valueListenable:
                      OAuthSignInCoordinator.instance.isSigningInListenable,
                  builder: (context, oauthBusy, _) {
                    return Column(
                      children: [
                        GlowFilledButton(
                          onPressed: oauthBusy
                              ? null
                              : () => _signInWithOAuth(
                                  context,
                                  OAuthProvider.apple,
                                ),
                          icon: const Icon(Icons.apple),
                          child: Text(
                            oauthBusy
                                ? 'Continue in browser...'
                                : 'Continue with Apple',
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlowFilledButton(
                          onPressed: oauthBusy
                              ? null
                              : () => _signInWithOAuth(
                                  context,
                                  OAuthProvider.google,
                                ),
                          icon: const Icon(Icons.g_mobiledata_rounded),
                          child: Text(
                            oauthBusy
                                ? 'Continue in browser...'
                                : 'Continue with Google',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                GlowFilledButton(
                  onPressed: () => context.push('/signin'),
                  child: const Text('Continue with email'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push('/signup'),
                  child: const Text('Create an account'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    controller.setSkippedSignUp(true);
                    await OnboardingController.markCompleted();
                    await OnboardingController.setAuthSkipped(true);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "That's okay. We'll keep things simple for now.",
                        ),
                      ),
                    );
                    context.go('/home');
                  },
                  child: const Text("I'll decide later"),
                ),
                const SizedBox(height: 12),
                Text(
                  'You can use MyBrainBubble without signing up.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
