import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'package:mind_buddy/theme/mindbuddy_background.dart';
import 'package:mind_buddy/features/auth/device_session_service.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/services/auth_redirect_targets.dart';
import 'package:mind_buddy/services/oauth_sign_in_coordinator.dart';
import 'package:mind_buddy/services/startup_user_data_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  static const String _underAgeMessage =
      'You must be at least 13 years old to use this app.';
  static const Duration _emailRateLimitCooldown = Duration(minutes: 1);
  static const String _emailRedirectTo =
      AuthRedirectTargets.emailVerificationCallback;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _dateOfBirth = TextEditingController();

  bool _loading = false;
  bool _checkingEmailAvailability = false;
  bool _confirmAge13Plus = false;
  bool _ageConfirmationError = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _dobError;
  String? _emailAvailabilityError;
  DateTime? _selectedDateOfBirth;
  Timer? _emailAvailabilityTimer;
  int _emailCheckRequestId = 0;

  Future<void> _upsertAndRefreshProfile({
    required String userId,
    required String email,
    required String fullName,
    required String dobIso,
  }) async {
    final payload = <String, dynamic>{
      'id': userId,
      'email': email,
      'full_name': fullName,
      'date_of_birth': dobIso,
      'subscription_tier': 'pending',
    };

    debugPrint('SignupProfileWrite attempt user_id=$userId payload=$payload');
    await Supabase.instance.client.from('profiles').upsert(payload);

    StartupUserDataService.instance.invalidateUser(userId);
    await StartupUserDataService.instance.fetchCombinedForUser(userId);
  }

  DateTime? _nextAllowedSignUpAt;
  Timer? _rateLimitTimer;
  int _cooldownSecondsRemaining = 0;

  bool get _isRateLimited => _cooldownSecondsRemaining > 0;

  @override
  void dispose() {
    _rateLimitTimer?.cancel();
    _emailAvailabilityTimer?.cancel();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _dateOfBirth.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final now = DateTime.now();
    final blockedUntil = _nextAllowedSignUpAt;
    if (blockedUntil != null && now.isBefore(blockedUntil)) {
      final remaining = blockedUntil.difference(now).inSeconds;
      final wait = remaining > 0 ? remaining : 1;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Too many email attempts. Please wait $wait seconds, or use Google/Apple sign-in.',
          ),
        ),
      );
      return;
    }

    final isValid = _formKey.currentState!.validate();
    final dobError = _validateDateOfBirth(_selectedDateOfBirth);
    final ageConfirmationError = !_confirmAge13Plus;
    if (!isValid || dobError != null || ageConfirmationError) {
      setState(() {
        _dobError = dobError;
        _ageConfirmationError = ageConfirmationError;
      });
      return;
    }
    setState(() => _loading = true);

    try {
      final email = _normalizedEmail(_email.text);
      final password = _password.text;
      final fullName = _fullName.text.trim();
      final dateOfBirth = _selectedDateOfBirth!;
      final dobIso = _formatDate(dateOfBirth);
      final emailAvailable = await _ensureEmailIsAvailable(email);
      if (!emailAvailable) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: _emailRedirectTo,
        data: {
          'full_name': fullName,
          'date_of_birth': dobIso,
          'is_13_or_over': _confirmAge13Plus,
          'subscription_tier': 'pending',
        },
      );

      final user = res.user;
      final hasSession = res.session != null;
      if (user != null && hasSession) {
        await _upsertAndRefreshProfile(
          userId: user.id,
          email: email,
          fullName: fullName,
          dobIso: dobIso,
        );

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
      }

      if (!mounted) return;
      if (hasSession) {
        await OnboardingController.setAuthStageCompleted(true);
        if (!mounted) return;
        context.go('/bootstrap');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created. Check your email to confirm your account, then sign in.',
            ),
          ),
        );
        context.go('/signin');
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final lowered = e.message.toLowerCase();
      final isEmailRateLimited =
          lowered.contains('email rate limit exceeded') ||
          lowered.contains('rate limit') && lowered.contains('email');
      if (isEmailRateLimited) {
        final cooldown = _parseRateLimitCooldown(e.message);
        _startRateLimitCooldown(cooldown);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many email attempts. Please wait ${cooldown.inSeconds} seconds, or use Google/Apple sign-in.',
            ),
          ),
        );
        return;
      }
      final message = e.message.contains(_underAgeMessage)
          ? _underAgeMessage
          : e.message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign up failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Duration _parseRateLimitCooldown(String message) {
    final lowered = message.toLowerCase();
    final minuteMatch = RegExp(
      r'(\d+)\s*(minute|minutes|min)\b',
    ).firstMatch(lowered);
    if (minuteMatch != null) {
      final minutes = int.tryParse(minuteMatch.group(1) ?? '');
      if (minutes != null && minutes > 0) return Duration(minutes: minutes);
    }

    final secondMatch = RegExp(
      r'(\d+)\s*(second|seconds|sec|s)\b',
    ).firstMatch(lowered);
    if (secondMatch != null) {
      final seconds = int.tryParse(secondMatch.group(1) ?? '');
      if (seconds != null && seconds > 0) return Duration(seconds: seconds);
    }

    return _emailRateLimitCooldown;
  }

  void _startRateLimitCooldown(Duration duration) {
    _rateLimitTimer?.cancel();
    final end = DateTime.now().add(duration);
    setState(() {
      _nextAllowedSignUpAt = end;
      _cooldownSecondsRemaining = duration.inSeconds;
    });
    _rateLimitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = end.difference(DateTime.now()).inSeconds;
      if (!mounted || remaining <= 0) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          _cooldownSecondsRemaining = 0;
          _nextAllowedSignUpAt = null;
        });
        return;
      }
      setState(() => _cooldownSecondsRemaining = remaining);
    });
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

  String? _validateEmail(String? v) {
    final value = _normalizedEmail(v);
    if (value.isEmpty) return 'Email is required';
    if (!_looksLikeEmail(value)) return 'Enter a valid email';
    if (_emailAvailabilityError != null) return _emailAvailabilityError;
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

  String? _validateFullName(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Full name is required';
    return null;
  }

  String? _validateDateOfBirth(DateTime? dob) {
    if (dob == null) return 'Date of birth is required';
    if (!_isAtLeast13(dob)) return _underAgeMessage;
    return null;
  }

  bool _isAtLeast13(DateTime dob) {
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 13;
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _normalizedEmail(String? value) {
    return (value ?? '').trim().toLowerCase();
  }

  bool _looksLikeEmail(String value) {
    if (value.isEmpty || value.length > 254 || value.contains(' ')) {
      return false;
    }

    final parts = value.split('@');
    if (parts.length != 2) return false;

    final local = parts.first;
    final domain = parts.last;
    if (local.isEmpty || domain.isEmpty) return false;
    if (local.length > 64) return false;
    if (local.startsWith('.') || local.endsWith('.') || local.contains('..')) {
      return false;
    }
    if (!RegExp(r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+$").hasMatch(local)) {
      return false;
    }

    final labels = domain.split('.');
    if (labels.length < 2) return false;
    final tld = labels.last;
    if (tld.length < 2 || tld.length > 24) return false;
    if (!RegExp(r'^[a-z]{2,24}$').hasMatch(tld)) return false;
    if (_invalidEmailTlds.contains(tld)) return false;

    for (final label in labels) {
      if (label.isEmpty || label.length > 63) return false;
      if (label.startsWith('-') || label.endsWith('-')) return false;
      if (!RegExp(r'^[a-z0-9-]+$').hasMatch(label)) return false;
    }

    return true;
  }

  static const Set<String> _invalidEmailTlds = <String>{
    'cim',
    'cmm',
    'cmo',
    'comm',
    'con',
    'coom',
    'ne',
    'ner',
    'ogr',
    'omc',
    'orgg',
    'vom',
    'xom',
  };

  void _onEmailChanged(String raw) {
    _emailAvailabilityTimer?.cancel();
    final email = _normalizedEmail(raw);
    if (email != raw) {
      _email.value = _email.value.copyWith(
        text: email,
        selection: TextSelection.collapsed(offset: email.length),
        composing: TextRange.empty,
      );
      return;
    }

    if (email.isEmpty || !_looksLikeEmail(email)) {
      if (_emailAvailabilityError != null || _checkingEmailAvailability) {
        setState(() {
          _emailAvailabilityError = null;
          _checkingEmailAvailability = false;
        });
      }
      return;
    }

    final requestId = ++_emailCheckRequestId;
    setState(() {
      _checkingEmailAvailability = true;
      _emailAvailabilityError = null;
    });
    _emailAvailabilityTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_checkEmailAvailability(email, requestId));
    });
  }

  Future<void> _checkEmailAvailability(String email, int requestId) async {
    final available = await _fetchEmailAvailability(email);
    if (!mounted || requestId != _emailCheckRequestId) return;
    setState(() {
      _checkingEmailAvailability = false;
      _emailAvailabilityError = available == false
          ? 'This email has already been used. Use a different email.'
          : null;
    });
    _formKey.currentState?.validate();
  }

  Future<bool?> _fetchEmailAvailability(String email) async {
    try {
      final response = await Supabase.instance.client.rpc(
        'is_email_available_exact',
        params: {'candidate': email},
      );
      if (response is bool) return response;
      if (response is num) return response != 0;
      if (response is String) {
        final lowered = response.toLowerCase().trim();
        if (lowered == 'true' || lowered == 't' || lowered == '1') return true;
        if (lowered == 'false' || lowered == 'f' || lowered == '0') {
          return false;
        }
      }
    } catch (_) {
      // Keep sign-up usable if the RPC is not deployed yet.
    }
    return null;
  }

  Future<bool> _ensureEmailIsAvailable(String email) async {
    if (!_looksLikeEmail(email)) return false;
    final available = await _fetchEmailAvailability(email);
    if (available == false) {
      setState(() {
        _emailAvailabilityError =
            'This email has already been used. Use a different email.';
        _checkingEmailAvailability = false;
      });
      _formKey.currentState?.validate();
      return false;
    }
    return true;
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final maxDate = DateTime(now.year - 13, now.month, now.day);
    final minDate = DateTime(1900, 1, 1);
    final initial = _selectedDateOfBirth ?? maxDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(maxDate) ? maxDate : initial,
      firstDate: minDate,
      lastDate: maxDate,
      helpText: 'Select date of birth',
    );
    if (picked == null) return;
    setState(() {
      _selectedDateOfBirth = DateTime(picked.year, picked.month, picked.day);
      _dateOfBirth.text = _formatDate(_selectedDateOfBirth!);
      _dobError = _validateDateOfBirth(_selectedDateOfBirth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = Theme.of(context).colorScheme.primary;
    return MindBuddyBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Sign up'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: context.canPop()
              ? MbGlowBackButton(onPressed: () => context.pop())
              : null,
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
                    validator: _validateFullName,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _dateOfBirth,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Date of birth',
                      hintText: 'YYYY-MM-DD',
                      errorText: _dobError,
                      suffixIcon: IconButton(
                        onPressed: _pickDateOfBirth,
                        icon: const Icon(Icons.calendar_today),
                      ),
                    ),
                    onTap: _pickDateOfBirth,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    onChanged: _onEmailChanged,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      helperText: _checkingEmailAvailability
                          ? 'Checking email...'
                          : null,
                      suffixIcon: _checkingEmailAvailability
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
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
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirm,
                    obscureText: !_isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible;
                          });
                        },
                        icon: Icon(
                          _isConfirmPasswordVisible
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: accentColor,
                        ),
                      ),
                    ),
                    validator: _validateConfirm,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _confirmAge13Plus,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I confirm that I am 13 years old or older.',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _confirmAge13Plus = value ?? false;
                        _ageConfirmationError = false;
                      });
                    },
                  ),
                  if (_ageConfirmationError)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'You must confirm that you are 13 or older.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_loading || _isRateLimited) ? null : _signUp,
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isRateLimited
                                  ? 'Try again in ${_cooldownSecondsRemaining}s'
                                  : 'Create account',
                            ),
                    ),
                  ),
                  if (_isRateLimited)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Email sign-up is temporarily limited. You can continue with Google/Apple meanwhile.',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
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
                    valueListenable:
                        OAuthSignInCoordinator.instance.isSigningInListenable,
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
                                  : () =>
                                        _signInWithOAuth(OAuthProvider.google),
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
                                  : () => _signInWithOAuth(OAuthProvider.apple),
                            ),
                          ),
                        ],
                      );
                    },
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
