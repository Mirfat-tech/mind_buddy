import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/theme/mindbuddy_background.dart';
import 'package:mind_buddy/features/auth/device_session_service.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/common/mb_responsive.dart';
import 'package:mind_buddy/features/auth/auth_layout.dart';
import 'package:mind_buddy/features/onboarding/onboarding_experience_session.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/services/oauth_sign_in_coordinator.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  // Inputs
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  // Loading states
  bool _loading = false;
  bool _resetSending = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() => _loading = true);

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (Supabase.instance.client.auth.currentUser == null) {
        throw Exception('Sign-in completed without an active session.');
      }

      final registration = await DeviceSessionService.registerDevice();
      if (registration.shouldBlockForDeviceLimit) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(registration.blockedMessage()),
            action: SnackBarAction(
              label: 'Manage devices',
              onPressed: () => context.go('/settings'),
            ),
          ),
        );
        context.go('/settings');
        return;
      }
      if (registration.entitlementCheckFailed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not verify your subscription right now. Signed in with temporary access.',
            ),
          ),
        );
      }

      final completedFeatureExperience =
          OnboardingExperienceSession.consumeFeatureExperienceCompleted();
      if (completedFeatureExperience) {
        await CompletionGateRepository.markOnboardingCompleted();
      }

      if (!mounted) return;
      await OnboardingController.setAuthStageCompleted(true);
      if (!mounted) return;

      context.go('/bootstrap');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, st) {
      debugPrint('Sign in failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    final res = await OAuthSignInCoordinator.instance.start(provider);
    if (!mounted || res.started) return;
    final message =
        (res.message ?? '').toLowerCase().contains('bad_code_verifier')
        ? 'Login expired - please try again.'
        : (res.message ?? 'OAuth sign in could not be started.');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendPasswordReset() async {
    final email = _email.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email first.')),
      );
      return;
    }

    setState(() => _resetSending = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        // Keep yours if you already set it:
        redirectTo: 'brainbubble://auth/callback',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Reset link sent to $email')));
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send reset email.')),
      );
    } finally {
      if (mounted) setState(() => _resetSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = MbResponsive.of(context);
    final accentColor = Theme.of(context).colorScheme.primary;

    return MindBuddyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text('Sign in'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: context.canPop()
              ? MbGlowBackButton(onPressed: () => context.pop())
              : null,
        ),

        body: SafeArea(
          child: AuthLayout(
            title: ' ',
            subtitle: ' ',
            bottom: TextButton(
              onPressed: () => context.go('/signup'),
              child: const Text('Create an account'),
            ),
            child: Padding(
              padding: EdgeInsets.all(responsive.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  SizedBox(height: responsive.blockGap),
                  TextField(
                    controller: _password,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: responsive.compactGap),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetSending ? null : _sendPasswordReset,
                      child: _resetSending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Forgot password?'),
                    ),
                  ),
                  SizedBox(height: responsive.compactGap),
                  SizedBox(
                    height: responsive.buttonHeight,
                    child: FilledButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continue to MyBrainBubble'),
                    ),
                  ),
                  SizedBox(height: responsive.blockGap),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: responsive.compactGap,
                        ),
                        child: const Text('OR'),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  SizedBox(height: responsive.blockGap),
                  ValueListenableBuilder<bool>(
                    valueListenable:
                        OAuthSignInCoordinator.instance.isSigningInListenable,
                    builder: (context, oauthBusy, _) {
                      final disabled = oauthBusy || _loading;
                      final socialSpacing = responsive.compactGap;
                      final isWide = responsive.isTabletUp;

                      final googleButton = SizedBox(
                        height: responsive.buttonHeight,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.g_mobiledata),
                          label: Text(
                            oauthBusy
                                ? 'Continue in browser...'
                                : 'Continue with Google',
                          ),
                          onPressed: disabled
                              ? null
                              : () => _signInWithOAuth(OAuthProvider.google),
                        ),
                      );
                      final appleButton = SizedBox(
                        height: responsive.buttonHeight,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.apple),
                          label: Text(
                            oauthBusy
                                ? 'Continue in browser...'
                                : 'Continue with Apple',
                          ),
                          onPressed: disabled
                              ? null
                              : () => _signInWithOAuth(OAuthProvider.apple),
                        ),
                      );

                      if (!isWide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            googleButton,
                            SizedBox(height: socialSpacing),
                            appleButton,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: googleButton),
                          SizedBox(width: socialSpacing),
                          Expanded(child: appleButton),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
