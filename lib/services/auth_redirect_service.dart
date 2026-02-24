import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRedirectService {
  AuthRedirectService._();

  static final AuthRedirectService instance = AuthRedirectService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  VoidCallback? _onSessionEstablished;
  void Function(String message)? _onAuthError;
  String? _lastAuthError;
  bool _sawAuthCallback = false;

  String? get lastAuthError => _lastAuthError;
  bool get sawAuthCallback => _sawAuthCallback;

  Future<void> init({
    VoidCallback? onSessionEstablished,
    void Function(String message)? onAuthError,
  }) async {
    _onSessionEstablished = onSessionEstablished;
    _onAuthError = onAuthError;
    await _handleInitialUri();
    _linkSub?.cancel();
    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) {
        unawaited(handleUri(uri));
      },
      onError: (Object e, StackTrace st) {
        debugPrint('AuthRedirectService uri stream error: $e');
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
      debugPrint('AuthRedirectService initial uri read failed: $e');
      debugPrint('$st');
    }
  }

  bool _isAuthCallback(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase();

    final isBrainBubble =
        scheme == 'brainbubble' || scheme == 'com.brainbubble.app';
    final isAuthPath =
        (host == 'auth' && (path == '/callback' || path == '/callback/')) ||
        (host.isEmpty && (path == '/auth/callback' || path == '/auth/callback/'));
    final isLegacyLoginCallback = scheme == 'mindbuddy' && host == 'login-callback';

    return (isBrainBubble && isAuthPath) || isLegacyLoginCallback;
  }

  bool _isPasswordReset(Uri uri) {
    return uri.scheme.toLowerCase() == 'mindbuddy' &&
        uri.host.toLowerCase() == 'reset';
  }

  Future<void> handleUri(Uri uri) async {
    debugPrint('AuthRedirectService callback URI: $uri');
    _lastAuthError = null;

    if (_isPasswordReset(uri)) {
      debugPrint('AuthRedirectService password reset deep link detected.');
      return;
    }

    if (!_isAuthCallback(uri)) {
      return;
    }
    _sawAuthCallback = true;

    final auth = Supabase.instance.client.auth;

    final fragment = uri.fragment.replaceFirst('#', '');
    final fragmentParams = fragment.isEmpty
        ? <String, String>{}
        : Uri.splitQueryString(fragment);
    final mergedParams = <String, String>{
      ...uri.queryParameters,
      ...fragmentParams,
    };

    final code = mergedParams['code'];
    final accessToken = mergedParams['access_token'];
    final hasImplicitTokens = accessToken != null && accessToken.isNotEmpty;
    final oauthError = mergedParams['error'] ?? mergedParams['error_description'];

    debugPrint(
      'AuthRedirectService parsed callback: hasCode=${code != null && code.isNotEmpty} hasImplicitTokens=$hasImplicitTokens hasError=${oauthError != null}',
    );

    if (oauthError != null && oauthError.isNotEmpty) {
      _lastAuthError = 'OAuth provider returned an error: $oauthError';
      debugPrint('AuthRedirectService $_lastAuthError');
      _onAuthError?.call(_lastAuthError!);
      return;
    }

    if (code != null && code.isNotEmpty) {
      try {
        await auth.exchangeCodeForSession(code);
        debugPrint('AuthRedirectService exchangeCodeForSession succeeded.');
      } catch (e, st) {
        _lastAuthError = 'OAuth code exchange failed: $e';
        debugPrint('AuthRedirectService exchangeCodeForSession failed: $e');
        debugPrint('$st');
        _onAuthError?.call(_lastAuthError!);
      }
    } else if (hasImplicitTokens) {
      var extracted = false;
      try {
        final dynamic dynAuth = auth;
        await dynAuth.getSessionFromUrl(uri);
        extracted = true;
        debugPrint('AuthRedirectService getSessionFromUrl succeeded.');
      } catch (e, st) {
        debugPrint('AuthRedirectService getSessionFromUrl failed: $e');
        debugPrint('$st');
      }

      if (!extracted) {
        try {
          // Some providers return hash params or mixed params; retry with merged query.
          final fallback = uri.replace(
            queryParameters: mergedParams,
            fragment: null,
          );
          final dynamic dynAuth = auth;
          await dynAuth.getSessionFromUrl(fallback);
          extracted = true;
          debugPrint(
            'AuthRedirectService getSessionFromUrl succeeded via fallback URI.',
          );
        } catch (e, st) {
          _lastAuthError = 'OAuth token extraction failed: $e';
          debugPrint(
            'AuthRedirectService getSessionFromUrl fallback failed: $e',
          );
          debugPrint('$st');
          _onAuthError?.call(_lastAuthError!);
        }
      }
    } else {
      _lastAuthError =
          'OAuth callback arrived without authorization code or token hash.';
      debugPrint('AuthRedirectService $_lastAuthError');
      _onAuthError?.call(_lastAuthError!);
    }

    final session = auth.currentSession;
    if (session == null) {
      await _waitForSession();
    }
    final settledSession = auth.currentSession;
    debugPrint(
      'AuthRedirectService session check after callback: hasSession=${settledSession != null} user=${settledSession?.user.id}',
    );

    if (settledSession != null) {
      _onSessionEstablished?.call();
      return;
    }

    if (_lastAuthError == null) {
      _lastAuthError = 'OAuth callback handled but no session was created.';
      _onAuthError?.call(_lastAuthError!);
    }
  }

  Future<void> _waitForSession() async {
    final auth = Supabase.instance.client.auth;
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (auth.currentSession != null) {
        return;
      }
    }
  }
}
