import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/theme/mindbuddy_background.dart';
import 'package:mind_buddy/features/auth/device_session_service.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
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
      if (!registration.allowed) {
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

      if (!mounted) return;

      // Preserve the intended route if present
      final from = GoRouterState.of(context).uri.queryParameters['from'];
      context.go(from ?? '/home');
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Email
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),

                      const SizedBox(height: 12),

                      // Password
                      TextField(
                        controller: _password,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Forgot password link
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

                      const SizedBox(height: 8),

                      // Continue button
                      SizedBox(
                        width: double.infinity,
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
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('OR'),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<bool>(
                        valueListenable: OAuthSignInCoordinator
                            .instance
                            .isSigningInListenable,
                        builder: (context, oauthBusy, _) {
                          final disabled = oauthBusy || _loading;
                          return Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.g_mobiledata),
                                  label: Text(
                                    oauthBusy
                                        ? 'Continue in browser...'
                                        : 'Continue with Google',
                                  ),
                                  onPressed: disabled
                                      ? null
                                      : () => _signInWithOAuth(
                                          OAuthProvider.google,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.apple),
                                  label: Text(
                                    oauthBusy
                                        ? 'Continue in browser...'
                                        : 'Continue with Apple',
                                  ),
                                  onPressed: disabled
                                      ? null
                                      : () => _signInWithOAuth(
                                          OAuthProvider.apple,
                                        ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => context.go('/signup'),
                        child: const Text('Create an account'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
