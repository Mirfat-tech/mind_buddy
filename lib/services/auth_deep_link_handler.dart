import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mind_buddy/services/oauth_sign_in_coordinator.dart';

class AuthDeepLinkHandler {
  AuthDeepLinkHandler._();

  static final AuthDeepLinkHandler instance = AuthDeepLinkHandler._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  VoidCallback? _onSessionEstablished;
  void Function(String message)? _onAuthError;
  String? _lastAuthError;
  String? _lastHandledCallbackKey;
  DateTime? _lastHandledCallbackAt;
  String? _inFlightCallbackKey;

  String? get lastAuthError => _lastAuthError;

  Future<void> init({
    VoidCallback? onSessionEstablished,
    void Function(String message)? onAuthError,
  }) async {
    _onSessionEstablished = onSessionEstablished;
    _onAuthError = onAuthError;

    await _handleInitialUri();

    await _linkSub?.cancel();
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(handleUri(uri)),
      onError: (Object e, StackTrace st) {
        debugPrint('AuthDeepLinkHandler uri stream error: $e');
        debugPrint('$st');
      },
    );
  }

  Future<void> dispose() async {
    await _linkSub?.cancel();
    _linkSub = null;
  }

  Future<void> _handleInitialUri() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        await handleUri(uri);
      }
    } catch (e, st) {
      debugPrint('AuthDeepLinkHandler initial uri read failed: $e');
      debugPrint('$st');
    }
  }

  bool _isAuthCallback(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();
    final isBrainbubbleScheme =
        scheme == 'brainbubble' || scheme == 'com.brainbubble.app';
    final isExpectedRoute =
        (host == 'auth' && (path == '/callback' || path == '/callback/')) ||
        (host.isEmpty &&
            (path == '/auth/callback' || path == '/auth/callback/'));
    return isBrainbubbleScheme && isExpectedRoute;
  }

  Future<void> handleUri(Uri uri) async {
    debugPrint('AuthDeepLinkHandler callback URI: $uri');
    _lastAuthError = null;

    if (!_isAuthCallback(uri)) {
      return;
    }

    final auth = Supabase.instance.client.auth;
    final existingSession = auth.currentSession;
    if (existingSession != null) {
      debugPrint(
        'AuthDeepLinkHandler callback received with existing session; skipping code exchange.',
      );
      OAuthSignInCoordinator.instance.markCompleted(
        reason: 'existing_session_before_exchange',
      );
      _onSessionEstablished?.call();
      return;
    }
    final fragment = uri.fragment.replaceFirst('#', '');
    final fragmentParams = fragment.isEmpty
        ? <String, String>{}
        : Uri.splitQueryString(fragment);
    final mergedParams = <String, String>{
      ...uri.queryParameters,
      ...fragmentParams,
    };

    final oauthError = mergedParams['error'];
    final oauthErrorCode = mergedParams['error_code'];
    final oauthErrorDescription = mergedParams['error_description'];
    final code = mergedParams['code'];
    final callbackKey = code != null && code.isNotEmpty
        ? 'code:$code'
        : 'error:${oauthError ?? ''}|${oauthErrorCode ?? ''}|${oauthErrorDescription ?? ''}';
    final now = DateTime.now();
    final isRecentDuplicate =
        _lastHandledCallbackKey == callbackKey &&
        _lastHandledCallbackAt != null &&
        now.difference(_lastHandledCallbackAt!) < const Duration(minutes: 2);
    if (_inFlightCallbackKey == callbackKey || isRecentDuplicate) {
      debugPrint(
        'AuthDeepLinkHandler duplicate callback ignored key=$callbackKey',
      );
      return;
    }
    _inFlightCallbackKey = callbackKey;
    _lastHandledCallbackKey = callbackKey;
    _lastHandledCallbackAt = now;

    try {
      if ((oauthError ?? '').isNotEmpty) {
        if (!OAuthSignInCoordinator.instance.isSigningIn) {
          debugPrint(
            'AuthDeepLinkHandler ignoring provider error callback with no active OAuth attempt.',
          );
          return;
        }
        _lastAuthError = [
          'OAuth provider returned an error.',
          if (oauthErrorCode != null && oauthErrorCode.isNotEmpty)
            'code=$oauthErrorCode',
          if (oauthErrorDescription != null && oauthErrorDescription.isNotEmpty)
            'description=$oauthErrorDescription',
        ].join(' ');
        debugPrint('AuthDeepLinkHandler $_lastAuthError');
        _onAuthError?.call(_lastAuthError!);
        OAuthSignInCoordinator.instance.markFailed(reason: 'provider_error');
        return;
      }

      try {
        if (code != null && code.isNotEmpty) {
          debugPrint(
            'AuthDeepLinkHandler handling PKCE callback with code exchange.',
          );
          await auth.exchangeCodeForSession(code);
        } else {
          debugPrint(
            'AuthDeepLinkHandler handling implicit/hash callback via getSessionFromUrl.',
          );
          final dynamic dynAuth = auth;
          await dynAuth.getSessionFromUrl(uri);
        }
      } catch (e, st) {
        final raw = e.toString().toLowerCase();
        final hasActiveAttempt = OAuthSignInCoordinator.instance.isSigningIn;
        // Supabase Flutter can process the deep link in parallel and emit
        // signedIn shortly after this call throws. Give it a brief chance to
        // settle before treating this as a hard failure.
        for (var i = 0; i < 20 && auth.currentSession == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        if (auth.currentSession != null) {
          OAuthSignInCoordinator.instance.markCompleted(
            reason: 'session_established_after_exchange_error',
          );
          _onSessionEstablished?.call();
          return;
        }
        final isBadVerifier =
            raw.contains('bad_code_verifier') ||
            raw.contains(
              'code challenge does not match previously saved code verifier',
            );
        final isMissingVerifier = raw.contains(
          'code verifier could not be found in local storage',
        );
        final isFlowStateNotFound =
            raw.contains('flow_state_not_found') ||
            raw.contains('invalid flow state, no valid flow state found');
        final isStalePkceState = isMissingVerifier || isFlowStateNotFound;
        if (isStalePkceState && !hasActiveAttempt) {
          // Stale callback after restart/hot-restart: no in-flight OAuth state.
          debugPrint(
            'AuthDeepLinkHandler ignoring stale callback (missing/invalid PKCE flow state, no active attempt).',
          );
          OAuthSignInCoordinator.instance.markFailed(
            reason: 'stale_callback_no_flow_state',
          );
          return;
        }
        _lastAuthError = (isBadVerifier || isStalePkceState)
            ? 'Login expired - please try again.'
            : 'OAuth callback exchange failed: $e';
        debugPrint('AuthDeepLinkHandler $_lastAuthError');
        debugPrint('$st');
        _onAuthError?.call(_lastAuthError!);
        OAuthSignInCoordinator.instance.markFailed(
          reason: (isBadVerifier || isStalePkceState)
              ? 'pkce_verifier_invalid_or_missing'
              : 'exchange_failed',
        );
        return;
      }

      // Give auth state a short time to settle before treating as failure.
      for (var i = 0; i < 12 && auth.currentSession == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      final session = auth.currentSession;
      debugPrint(
        'AuthDeepLinkHandler session after callback: hasSession=${session != null} user=${session?.user.id}',
      );

      if (session != null) {
        OAuthSignInCoordinator.instance.markCompleted(
          reason: 'session_established',
        );
        _onSessionEstablished?.call();
        return;
      }

      _lastAuthError = 'OAuth returned, but no session could be established.';
      _onAuthError?.call(_lastAuthError!);
      OAuthSignInCoordinator.instance.markFailed(reason: 'no_session');
    } finally {
      _inFlightCallbackKey = null;
    }
  }
}
