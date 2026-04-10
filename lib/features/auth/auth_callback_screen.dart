import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mind_buddy/common/mb_scaffold.dart';
import 'package:mind_buddy/services/auth_redirect_targets.dart';

enum _AuthCallbackState { loading, success, error }

class AuthCallbackScreen extends StatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  State<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends State<AuthCallbackScreen> {
  _AuthCallbackState _state = _AuthCallbackState.loading;
  String _message = 'Confirming your email...';
  bool _launchAttempted = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_resolveCallback);
  }

  Future<void> _resolveCallback() async {
    final uri = Uri.base;
    final fragment = uri.fragment.replaceFirst('#', '');
    final fragmentParams = fragment.isEmpty
        ? const <String, String>{}
        : Uri.splitQueryString(fragment);
    final mergedParams = <String, String>{
      ...uri.queryParameters,
      ...fragmentParams,
    };
    final tokenHash = mergedParams['token_hash'];
    final error = mergedParams['error_description'] ?? mergedParams['error'];
    final type = (mergedParams['type'] ?? '').toLowerCase();
    final looksLikeVerification =
        type == 'signup' ||
        type == 'invite' ||
        type == 'email_change' ||
        mergedParams.containsKey('code') ||
        mergedParams.containsKey('token_hash');

    if (!mounted) return;

    if (error != null && error.trim().isNotEmpty) {
      setState(() {
        _state = _AuthCallbackState.error;
        _message = error.trim();
      });
      return;
    }

    if (tokenHash != null && tokenHash.isNotEmpty) {
      try {
        await Supabase.instance.client.auth.verifyOTP(
          tokenHash: tokenHash,
          type: _mapOtpType(type),
        );
      } on AuthException catch (e) {
        if (!mounted) return;
        setState(() {
          _state = _AuthCallbackState.error;
          _message = e.message;
        });
        return;
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _state = _AuthCallbackState.error;
          _message = 'Could not complete email confirmation: $e';
        });
        return;
      }
    }

    setState(() {
      _state = _AuthCallbackState.success;
      _message = looksLikeVerification
          ? 'Your email has been verified. You can return to the app and continue.'
          : 'This confirmation link has been processed.';
    });
  }

  OtpType _mapOtpType(String rawType) {
    switch (rawType) {
      case 'invite':
        return OtpType.invite;
      case 'magiclink':
        return OtpType.magiclink;
      case 'recovery':
        return OtpType.recovery;
      case 'email_change':
        return OtpType.emailChange;
      case 'email':
        return OtpType.email;
      case 'signup':
      default:
        return OtpType.signup;
    }
  }

  Uri _buildAppCallbackUri() {
    final uri = Uri.base;
    final target = Uri.parse(AuthRedirectTargets.appCallback);
    final query = uri.hasQuery ? uri.query : null;
    final fragment = uri.fragment.isEmpty ? null : uri.fragment;
    return Uri(
      scheme: target.scheme,
      host: target.host,
      path: target.path,
      query: query,
      fragment: fragment,
    );
  }

  Future<void> _openApp() async {
    if (_launchAttempted) return;
    _launchAttempted = true;
    try {
      await launchUrl(
        _buildAppCallbackUri(),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Leave the confirmation UI visible as the fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isError = _state == _AuthCallbackState.error;

    return MbScaffold(
      applyBackground: true,
      appBar: AppBar(title: const Text('Email Confirmation')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _state == _AuthCallbackState.loading
                        ? Icons.mark_email_read_outlined
                        : isError
                        ? Icons.error_outline
                        : Icons.verified_outlined,
                    size: 64,
                    color: isError
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _state == _AuthCallbackState.loading
                        ? 'Finishing verification'
                        : isError
                        ? 'Verification could not be completed'
                        : 'Email verified',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (_state == _AuthCallbackState.loading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    FilledButton(
                      onPressed: _openApp,
                      child: const Text('Open MyBrainBubble'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => context.go('/signin'),
                      child: const Text('Go To Sign In'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'If you are on the same device as the app, use the button above. Otherwise, return to the app and sign in there.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
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
