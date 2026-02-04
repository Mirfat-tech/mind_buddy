import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/theme/mindbuddy_background.dart';
import 'package:mind_buddy/features/auth/device_session_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _loading = false;
  bool _checkingUsername = false;
  String? _usernameHint;
  String? _usernameError;
  Timer? _debounce;

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final email = _email.text.trim();
      final password = _password.text;
      final fullName = _fullName.text.trim();
      final username = _username.text.trim().toLowerCase();

      final availability = await _checkUsername(username);
      if (!availability) {
        setState(() {
          _usernameError = 'Username is taken';
        });
        return;
      }

      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'username': username,
          'subscription_tier': 'pending',
        },
      );

      final user = res.user;
      if (user != null) {
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'email': email,
          'full_name': fullName,
          'username': username,
          'subscription_tier': 'pending',
        });

        final ok = await DeviceSessionService.recordSession();
        if (!ok) {
          await Supabase.instance.client.auth.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This plan allows only 1 device. Upgrade to use more devices.',
              ),
            ),
          );
          return;
        }
      }

      if (!mounted) return;
      context.go('/onboarding/plan');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: 'mindbuddy://login-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OAuth failed: $e')),
      );
    }
  }

  Future<void> _checkUsernameNow() async {
    final v = _username.text.trim().toLowerCase();
    if (v.isEmpty) return;
    if (_checkingUsername) return;
    setState(() => _checkingUsername = true);
    final ok = await _checkUsername(v);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _usernameError = null;
        _usernameHint = 'Username available';
        _checkingUsername = false;
      });
    } else {
      final suggestion = await _suggestUsername(v);
      if (!mounted) return;
      setState(() {
        _usernameError = 'Username taken';
        _usernameHint =
            suggestion == null ? null : 'Try "$suggestion" instead';
        _checkingUsername = false;
      });
    }
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final v = value.trim().toLowerCase();
      if (v.isEmpty) {
        setState(() {
          _usernameHint = null;
          _usernameError = null;
          _checkingUsername = false;
        });
        return;
      }
      if (mounted) {
        setState(() => _checkingUsername = true);
      }
      final ok = await _checkUsername(v);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _usernameError = null;
          _usernameHint = 'Username available';
          _checkingUsername = false;
        });
      } else {
        final suggestion = await _suggestUsername(v);
        if (!mounted) return;
        setState(() {
          _usernameError = 'Username taken';
          _usernameHint =
              suggestion == null ? null : 'Try "$suggestion" instead';
          _checkingUsername = false;
        });
      }
    });
  }

  Future<bool> _checkUsername(String username) async {
    final res = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    return res == null;
  }

  Future<String?> _suggestUsername(String base) async {
    final safe = base.replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (safe.isEmpty) return null;

    final rows = await Supabase.instance.client
        .from('profiles')
        .select('username')
        .ilike('username', '$safe%');
    final taken = (rows as List)
        .map((r) => (r['username'] ?? '').toString())
        .toSet();

    for (var i = 1; i < 1000; i++) {
      final candidate = '$safe$i';
      if (!taken.contains(candidate)) return candidate;
    }
    return null;
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    if (!value.contains('@')) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Use at least 8 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if ((v ?? '').trim() != _password.text.trim()) {
      return 'Passwords do not match';
    }
    return null;
  }

  String? _validateUsername(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Username is required';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Only letters, numbers, underscore';
    }
    if (value.length < 3) return 'Minimum 3 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MindBuddyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Sign up'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _fullName,
                    decoration: const InputDecoration(labelText: 'Full name'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _username,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            helperText: _usernameHint,
                            errorText: _usernameError,
                          ),
                          onChanged: _onUsernameChanged,
                          validator: _validateUsername,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _checkingUsername ? null : _checkUsernameNow,
                        child: _checkingUsername
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Check'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                    ),
                    validator: _validateConfirm,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _signUp,
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create account'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('OR'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.g_mobiledata),
                      label: const Text('Continue with Google'),
                      onPressed: () => _signInWithOAuth(OAuthProvider.google),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.apple),
                      label: const Text('Continue with Apple'),
                      onPressed: () => _signInWithOAuth(OAuthProvider.apple),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/signin'),
                    child: const Text('Already have an account? Sign in'),
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
