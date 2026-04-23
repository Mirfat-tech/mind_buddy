import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/onboarding/onboarding_widgets.dart';
import 'package:mind_buddy/services/startup_user_data_service.dart';

class OnboardingUsernameScreen extends StatefulWidget {
  const OnboardingUsernameScreen({super.key});

  @override
  State<OnboardingUsernameScreen> createState() =>
      _OnboardingUsernameScreenState();
}

class _OnboardingUsernameScreenState extends State<OnboardingUsernameScreen> {
  static const String _usernameFormatMessage =
      '3-20 characters. Use lowercase letters and numbers. You can use "_" or "." in the middle (not at the start/end).';
  static const String _usernameCheckingMessage = 'Checking availability...';
  static const String _usernameAutoNetworkMessage = "Couldn't check right now.";
  static const String _usernameNetworkMessage =
      "Couldn't check right now. Try again.";
  static const List<String> _adjectives = <String>[
    'calm',
    'soft',
    'quiet',
    'bright',
    'cozy',
    'gentle',
    'sunny',
    'dreamy',
    'midnight',
    'neon',
    'kind',
    'mindful',
    'happy',
    'brave',
    'steady',
    'warm',
    'lunar',
    'daily',
    'clear',
    'fresh',
    'swift',
    'pearl',
    'golden',
    'silver',
    'velvet',
    'tiny',
    'mellow',
    'breezy',
    'bold',
    'true',
  ];
  static const List<String> _nouns = <String>[
    'bubble',
    'journal',
    'planner',
    'notes',
    'mood',
    'glow',
    'vibe',
    'bloom',
    'cloud',
    'star',
    'moon',
    'zen',
    'focus',
    'spark',
    'wave',
    'ink',
    'page',
    'diary',
    'mind',
    'path',
    'track',
    'flow',
    'story',
    'dream',
    'groove',
    'pulse',
    'moment',
    'habit',
    'atlas',
    'orbit',
  ];

  final TextEditingController _username = TextEditingController();
  final Random _rng = Random();
  String? _usernameHint;
  String? _usernameError;
  bool _saving = false;
  bool _checking = false;
  // ignore: unused_field
  bool _usernameAvailable = false;
  int _checkRequestId = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _username.dispose();
    super.dispose();
  }

  String _seedFromUser() {
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? {};
    final name = (meta['full_name'] ?? meta['name'] ?? '').toString();
    final email = (user?.email ?? '').toString();
    final base = name.isNotEmpty ? name : email.split('@').first;
    return _seedFromText(base);
  }

  String _canonicalUsername(String value) {
    return value.trim().replaceFirst(RegExp(r'^@+'), '').toLowerCase();
  }

  String _seedFromText(String value) {
    return _canonicalUsername(value)
        .replaceAll(RegExp(r'[\s-]+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9._]'), '')
        .replaceAll(RegExp(r'[._]{2,}'), '_')
        .replaceAll(RegExp(r'^[._]+'), '')
        .replaceAll(RegExp(r'[._]+$'), '');
  }

  String _baseFromInput(String value) {
    final normalized = _canonicalUsername(value);
    if (normalized.isEmpty) return '';
    final token = normalized.split(RegExp(r'[._]+')).first;
    var base = token.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (base.endsWith('bb') && base.length > 4) {
      base = base.substring(0, base.length - 2);
    }
    return base;
  }

  String _deriveSuggestionBase() {
    final fromInput = _baseFromInput(_username.text);
    if (fromInput.isNotEmpty) return fromInput;

    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? const <String, dynamic>{};
    final name = (meta['full_name'] ?? meta['name'] ?? '').toString();
    final fromName = _baseFromInput(name);
    if (fromName.isNotEmpty) return fromName;

    final email = (user?.email ?? '').toString();
    final fromEmail = _baseFromInput(email.split('@').first);
    if (fromEmail.isNotEmpty) return fromEmail;

    return 'bbuser';
  }

  bool _isValidUsername(String username) {
    return RegExp(r'^[a-z0-9](?:[a-z0-9._]{1,18})[a-z0-9]$').hasMatch(username);
  }

  Future<bool?> _checkUsername(String username) async {
    final canonical = _canonicalUsername(username);
    if (!_isValidUsername(canonical)) return false;

    Future<bool?> callRpc(String fn) async {
      final rpc = await Supabase.instance.client.rpc(
        fn,
        params: {'candidate': canonical},
      );
      if (rpc is bool) return rpc;
      if (rpc is String) {
        final lowered = rpc.toLowerCase().trim();
        if (lowered == 'true' || lowered == 't' || lowered == '1') return true;
        if (lowered == 'false' || lowered == 'f' || lowered == '0') {
          return false;
        }
      }
      if (rpc is num) return rpc != 0;
      if (rpc is Map) {
        final value =
            rpc['is_username_available_exact'] ??
            rpc['is_username_available'] ??
            rpc['available'];
        if (value is bool) return value;
        if (value is String) {
          final lowered = value.toLowerCase().trim();
          if (lowered == 'true' || lowered == 't' || lowered == '1') {
            return true;
          }
          if (lowered == 'false' || lowered == 'f' || lowered == '0') {
            return false;
          }
        }
      }
      if (rpc is List && rpc.isNotEmpty) {
        final first = rpc.first;
        if (first is bool) return first;
        if (first is Map) {
          final value =
              first['is_username_available_exact'] ??
              first['is_username_available'] ??
              first['available'];
          if (value is bool) return value;
          if (value is String) {
            final lowered = value.toLowerCase().trim();
            if (lowered == 'true' || lowered == 't' || lowered == '1') {
              return true;
            }
            if (lowered == 'false' || lowered == 'f' || lowered == '0') {
              return false;
            }
          }
        }
      }
      return null;
    }

    try {
      final exact = await callRpc('is_username_available_exact');
      if (exact != null) return exact;
      final legacy = await callRpc('is_username_available');
      if (legacy != null) return legacy;
    } catch (_) {
      // Unknown availability (e.g., missing RPC / temporary backend issue).
      return null;
    }
    // Unknown response shape.
    return null;
  }

  Future<String?> _suggestUsername(String base) async {
    final seed = _baseFromInput(base).isNotEmpty
        ? _baseFromInput(base)
        : _deriveSuggestionBase();
    if (seed.isEmpty) return null;

    const maxBatches = 3;
    const batchSize = 20;
    for (var batch = 0; batch < maxBatches; batch++) {
      final generated = <String>{};
      for (var i = 0; i < batchSize; i++) {
        final candidate = _buildRandomCandidate(seed);
        if (_isValidUsername(candidate)) {
          generated.add(candidate);
        }
      }
      for (final candidate in generated) {
        if (await _checkUsername(candidate) == true) {
          return candidate;
        }
      }
    }
    return null;
  }

  String _fitLength(String candidate) {
    var v = _seedFromText(candidate);
    if (v.length > 20) {
      v = v.substring(0, 20);
      v = v.replaceAll(RegExp(r'^[._]+|[._]+$'), '');
    }
    if (v.length < 3) {
      final pad = (_rng.nextInt(90) + 10).toString();
      v = '$v$pad';
    }
    if (!_isValidUsername(v) && v.length > 20) {
      v = v.substring(0, 20);
    }
    return v;
  }

  String _buildRandomCandidate(String base) {
    final b = base.length > 10 ? base.substring(0, 10) : base;
    final adj = _adjectives[_rng.nextInt(_adjectives.length)];
    final noun = _nouns[_rng.nextInt(_nouns.length)];
    final n2 = _rng.nextInt(100).toString().padLeft(2, '0');
    final template = _rng.nextInt(12);

    String raw;
    switch (template) {
      case 0:
        raw = '$b$n2';
        break;
      case 1:
        raw = '$adj$b';
        break;
      case 2:
        raw = '$b$noun';
        break;
      case 3:
        raw = '${b}_$noun';
        break;
      case 4:
        raw = '${adj}_$b';
        break;
      case 5:
        raw = '${b}_$n2';
        break;
      case 6:
        raw = '$b.$noun';
        break;
      case 7:
        raw = '$adj.$b';
        break;
      case 8:
        raw = '$b.$n2';
        break;
      case 9:
        raw = '${b}_brain';
        break;
      case 10:
        raw = '${b}_bubble';
        break;
      default:
        raw = _rng.nextBool() ? '${b}_bb_$n2' : '${b}_$n2';
    }
    return _fitLength(raw);
  }

  Future<void> _generateSuggestion() async {
    final seed = _username.text.trim().isEmpty
        ? _seedFromUser()
        : _username.text;
    if (seed.isEmpty) return;
    setState(() {
      _checking = true;
      _usernameHint = null;
      _usernameError = null;
      _usernameAvailable = false;
    });
    final suggestion = await _suggestUsername(seed);
    if (!mounted) return;
    if (suggestion == null) {
      setState(() {
        _usernameError =
            "Couldn't find an available suggestion. Try adding numbers.";
        _usernameHint = null;
        _usernameAvailable = false;
        _checking = false;
      });
      return;
    }
    _username.text = suggestion;
    _username.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    setState(() {
      _usernameError = null;
      _usernameHint = '✅ @$suggestion is available';
      _usernameAvailable = true;
      _checking = false;
    });
  }

  Future<void> _checkUsernameNow({bool showNetworkError = true}) async {
    final v = _canonicalUsername(_username.text);
    if (v.isEmpty) return;
    if (!_isValidUsername(v)) {
      setState(() {
        _usernameHint = null;
        _usernameError = _usernameFormatMessage;
        _usernameAvailable = false;
        _checking = false;
      });
      return;
    }
    final requestId = ++_checkRequestId;
    setState(() {
      _checking = true;
      _usernameAvailable = false;
      _usernameHint = null;
      _usernameError = null;
    });
    try {
      final ok = await _checkUsername(v);
      if (!mounted || requestId != _checkRequestId) return;
      if (ok == true) {
        setState(() {
          _usernameError = null;
          _usernameHint = '✅ @$v is available';
          _usernameAvailable = true;
          _checking = false;
        });
      } else if (ok == false) {
        setState(() {
          _usernameError = '❌ @$v is taken';
          _usernameHint = null;
          _usernameAvailable = false;
          _checking = false;
        });
      } else {
        setState(() {
          _usernameError = showNetworkError ? _usernameNetworkMessage : null;
          _usernameHint = showNetworkError ? null : _usernameAutoNetworkMessage;
          _usernameAvailable = false;
          _checking = false;
        });
      }
    } catch (_) {
      if (!mounted || requestId != _checkRequestId) return;
      setState(() {
        _usernameHint = showNetworkError ? null : _usernameAutoNetworkMessage;
        _usernameError = showNetworkError ? _usernameNetworkMessage : null;
        _usernameAvailable = false;
        _checking = false;
      });
    }
  }

  void _onUsernameChanged(String value) {
    _checkRequestId++;
    final v = _canonicalUsername(value);
    setState(() {
      _usernameAvailable = false;
      _usernameHint = null;
      _usernameError = null;
      _checking = v.isNotEmpty && _isValidUsername(v);
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (v.isEmpty) {
        if (!mounted) return;
        setState(() {
          _usernameHint = null;
          _usernameError = null;
          _usernameAvailable = false;
          _checking = false;
        });
        return;
      }
      if (!_isValidUsername(v)) {
        if (!mounted) return;
        setState(() {
          _usernameHint = null;
          _usernameError = _usernameFormatMessage;
          _usernameAvailable = false;
          _checking = false;
        });
        return;
      }
      await _checkUsernameNow(showNetworkError: false);
    });
  }

  void _handleBack() {
    context.go('/onboarding/plan');
  }

  Future<void> _saveUsername() async {
    if (_saving) return;
    final username = _canonicalUsername(_username.text);
    if (username.isEmpty) {
      setState(() {
        _usernameError = 'Enter a username to continue.';
      });
      return;
    }
    if (!_isValidUsername(username)) {
      setState(() {
        _usernameError = _usernameFormatMessage;
        _usernameAvailable = false;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      final ok = await _checkUsername(username);
      if (ok == false) {
        setState(() {
          _usernameError = '❌ @$username is taken';
          _usernameAvailable = false;
        });
        return;
      }
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
        return;
      }

      // Preferred: RLS-safe bootstrap via SECURITY DEFINER RPC.
      try {
        await Supabase.instance.client.rpc('ensure_my_profile');
      } catch (_) {
        // Fallback for environments where RPC is not deployed yet.
      }

      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .limit(1);

      if (rows.isNotEmpty) {
        await Supabase.instance.client
            .from('profiles')
            .update({'username': username})
            .eq('id', user.id);
      } else {
        // Username onboarding should not decide subscription tier; that is
        // resolved by the plan step.
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'email': user.email,
          'username': username,
        });
      }
      StartupUserDataService.instance.invalidateUser(user.id);
      final refreshed = await StartupUserDataService.instance
          .fetchCombinedForUser(user.id);
      final persisted = (refreshed.profileRow?['username'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (persisted != username) {
        setState(() {
          _usernameError = 'Could not save username. Please try again.';
        });
        return;
      }

      await CompletionGateRepository.markUsernameCompleted();
      if (!mounted) return;
      context.go('/');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final isProfileRlsBlocked = e.code == '42501';
      if (isProfileRlsBlocked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username will be synced later. Continuing for now.'),
          ),
        );
        context.go('/');
        return;
      }
      final uniqueConflict = e.code == '23505';
      if (uniqueConflict) {
        final suggestion = await _suggestUsername(username);
        if (!mounted) return;
        if (suggestion != null) {
          _username.text = suggestion;
          _username.selection = TextSelection.fromPosition(
            TextPosition(offset: suggestion.length),
          );
          setState(() {
            _usernameError = 'That username was just taken. Try this one.';
            _usernameHint = '✅ @$suggestion is available';
            _usernameAvailable = true;
          });
          return;
        }
      }
      if (e.code == '23514') {
        final lowered = e.message.toLowerCase();
        final usernameConstraint = lowered.contains('username');
        setState(() {
          _usernameError = usernameConstraint
              ? _usernameFormatMessage
              : 'Profile constraint prevented saving username. Please complete plan selection first.';
          _usernameAvailable = false;
        });
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save username (${e.code ?? 'db_error'}). Please retry in a moment.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save username right now. Please retry.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canonical = _canonicalUsername(_username.text);
    final isValidNow = _isValidUsername(canonical);
    final effectiveError =
        isValidNow && _usernameError == _usernameFormatMessage
        ? null
        : _usernameError;
    String? statusText;
    Color? statusColor;
    if (_checking) {
      statusText = _usernameCheckingMessage;
      statusColor = scheme.onSurface.withValues(alpha: 0.65);
    } else if (effectiveError != null) {
      statusText = effectiveError;
      statusColor = scheme.error;
    } else if (_usernameHint != null) {
      statusText = _usernameHint;
      statusColor = Colors.green.shade700;
    }
    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(
        leading: MbGlowBackButton(onPressed: _handleBack),
        title: const Text(''),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick your MyBrainBubble username',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: scheme.primary,
                shadows: [
                  Shadow(
                    color: scheme.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This is how trusted people find you for shared pages.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              onChanged: _onUsernameChanged,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixText: '@',
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 24),
              child: statusText == null
                  ? const SizedBox.shrink()
                  : Text(
                      statusText,
                      maxLines: 3,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: statusColor),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              _usernameFormatMessage,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _generateSuggestion,
                child: const Text('Suggest one'),
              ),
            ),
            const Spacer(),
            GlowFilledButton(
              onPressed: _saving ? null : _saveUsername,
              child: Text(_saving ? 'Saving...' : 'Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
