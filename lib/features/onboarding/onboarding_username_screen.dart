import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/common/mb_glow_back_button.dart';
import 'package:mind_buddy/features/onboarding/onboarding_state.dart';
import 'package:mind_buddy/features/onboarding/onboarding_widgets.dart';

class OnboardingUsernameScreen extends StatefulWidget {
  const OnboardingUsernameScreen({super.key});

  @override
  State<OnboardingUsernameScreen> createState() =>
      _OnboardingUsernameScreenState();
}

class _OnboardingUsernameScreenState extends State<OnboardingUsernameScreen> {
  final TextEditingController _username = TextEditingController();
  String? _usernameHint;
  String? _usernameError;
  bool _saving = false;
  bool _checking = false;
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
    return base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
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

    if (!taken.contains(safe)) return safe;
    for (var i = 1; i < 1000; i++) {
      final candidate = '$safe$i';
      if (!taken.contains(candidate)) return candidate;
    }
    return null;
  }

  Future<void> _generateSuggestion() async {
    final seed = _seedFromUser();
    if (seed.isEmpty) return;
    final suggestion = await _suggestUsername(seed);
    if (!mounted) return;
    if (suggestion == null) {
      setState(() {
        _usernameError = 'Try a different name.';
        _usernameHint = null;
      });
      return;
    }
    _username.text = suggestion;
    _username.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    await _checkUsernameNow();
  }

  Future<void> _checkUsernameNow() async {
    final v = _username.text.trim().toLowerCase();
    if (v.isEmpty || _checking) return;
    setState(() => _checking = true);
    try {
      final ok = await _checkUsername(v);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _usernameError = null;
          _usernameHint = 'Username available';
          _checking = false;
        });
      } else {
        final suggestion = await _suggestUsername(v);
        if (!mounted) return;
        setState(() {
          _usernameError = 'Username taken';
          _usernameHint = suggestion == null
              ? null
              : 'Try "$suggestion" instead';
          _checking = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _usernameHint = null;
        _usernameError = 'Could not check username right now';
        _checking = false;
      });
    }
  }

  void _onUsernameChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final v = value.trim().toLowerCase();
      if (v.isEmpty) {
        if (!mounted) return;
        setState(() {
          _usernameHint = null;
          _usernameError = null;
          _checking = false;
        });
        return;
      }
      if (mounted) setState(() => _checking = true);
      try {
        final ok = await _checkUsername(v);
        if (!mounted) return;
        if (ok) {
          setState(() {
            _usernameError = null;
            _usernameHint = 'Username available';
            _checking = false;
          });
        } else {
          final suggestion = await _suggestUsername(v);
          if (!mounted) return;
          setState(() {
            _usernameError = 'Username taken';
            _usernameHint = suggestion == null
                ? null
                : 'Try "$suggestion" instead';
            _checking = false;
          });
        }
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _usernameHint = null;
          _usernameError = 'Could not check username right now';
          _checking = false;
        });
      }
    });
  }

  void _handleBack() {
    final router = GoRouter.of(context);
    try {
      if (router.canPop()) {
        router.pop();
        return;
      }
    } catch (_) {
      // Fall through to deterministic route when pop is not possible.
    }
    router.go('/home');
  }

  Future<void> _saveUsername() async {
    if (_saving) return;
    final username = _username.text.trim().toLowerCase();
    if (username.isEmpty) return;
    setState(() => _saving = true);
    try {
      final ok = await _checkUsername(username);
      if (!ok) {
        setState(() {
          _usernameError = 'Username taken';
        });
        return;
      }
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

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
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'username': username,
        });
      }

      final completed = await OnboardingController.isCompleted();
      if (!mounted) return;
      context.go(completed ? '/home' : '/onboarding/expression');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final isProfileRlsBlocked = e.code == '42501';
      if (isProfileRlsBlocked) {
        final completed = await OnboardingController.isCompleted();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username will be synced later. Continuing for now.'),
          ),
        );
        context.go(completed ? '/home' : '/onboarding/expression');
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
              decoration: InputDecoration(
                labelText: 'Username',
                prefixText: '@',
                helperText: _usernameHint,
                errorText: _usernameError,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _checking ? null : _checkUsernameNow,
                    child: Text(_checking ? 'Checking...' : 'Check username'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _generateSuggestion,
                    child: const Text('Suggest one'),
                  ),
                ),
              ],
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
