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
import 'package:mind_buddy/services/native_apple_sign_in_service.dart';
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
  bool _isCreateAccountPressed = false;
  bool _appleLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _goBackToOnboarding() {
    context.go('/onboarding/doorway');
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
        if (DeviceSessionService.shouldSuppressSubscriptionWarning('/signin')) {
          // Keep auth flow quiet; main app surfaces can handle real issues later.
        } else {
          debugPrint(
            'SUBSCRIPTION_WARNING_SHOWN route=/signin reason=entitlement_check_failed_without_cached_tier',
          );
        }
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

  Future<void> _signInWithApple() async {
    if (_loading || _appleLoading) return;
    setState(() => _appleLoading = true);

    try {
      await NativeAppleSignInService.instance.signIn();
      if (Supabase.instance.client.auth.currentUser == null) {
        throw Exception('Apple sign-in completed without an active session.');
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
        if (DeviceSessionService.shouldSuppressSubscriptionWarning('/signin')) {
          // Keep auth flow quiet; main app surfaces can handle real issues later.
        } else {
          debugPrint(
            'SUBSCRIPTION_WARNING_SHOWN route=/signin reason=entitlement_check_failed_without_cached_tier',
          );
        }
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
      debugPrint('Apple sign in failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign in failed: $e')));
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _goBackToOnboarding();
      },
      child: MindBuddyBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: true,
          appBar: AppBar(
            title: const Text('Sign in'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: MbGlowBackButton(onPressed: _goBackToOnboarding),
          ),

          body: SafeArea(
            child: AuthLayout(
              title: '',
              subtitle: '',
              headerAction: _CreateAccountHeaderAction(
                accentColor: accentColor,
                pressed: _isCreateAccountPressed,
                onTap: () => context.go('/signup'),
                onPressedChanged: (value) {
                  if (_isCreateAccountPressed == value) return;
                  setState(() => _isCreateAccountPressed = value);
                },
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                        final googleDisabled =
                            oauthBusy || _loading || _appleLoading;
                        final appleDisabled =
                            _loading || _appleLoading || oauthBusy;
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
                            onPressed: googleDisabled
                                ? null
                                : () => _signInWithOAuth(OAuthProvider.google),
                          ),
                        );
                        final appleButton = SizedBox(
                          height: responsive.buttonHeight,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.apple),
                            label: Text(
                              _appleLoading
                                  ? 'Opening Apple...'
                                  : 'Continue with Apple',
                            ),
                            onPressed: appleDisabled ? null : _signInWithApple,
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
      ),
    );
  }
}

class _CreateAccountHeaderAction extends StatelessWidget {
  const _CreateAccountHeaderAction({
    required this.accentColor,
    required this.pressed,
    required this.onTap,
    required this.onPressedChanged,
  });

  final Color accentColor;
  final bool pressed;
  final VoidCallback onTap;
  final ValueChanged<bool> onPressedChanged;

  @override
  Widget build(BuildContext context) {
    final responsive = MbResponsive.of(context);
    final baseStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: accentColor.withValues(alpha: 0.9),
      fontSize: responsive.titleSize * 0.46,
      fontWeight: FontWeight.w600,
      height: 1.25,
    );

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onTapDown: (_) => onPressedChanged(true),
        onTapUp: (_) => onPressedChanged(false),
        onTapCancel: () => onPressedChanged(false),
        child: AnimatedScale(
          scale: pressed ? 0.985 : 1,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: pressed ? 0.72 : 1,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.compactGap,
                vertical: responsive.compactGap * 0.4,
              ),
              child: Text(
                'New here? Let’s create your bubble 🫧',
                textAlign: TextAlign.center,
                style: baseStyle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
