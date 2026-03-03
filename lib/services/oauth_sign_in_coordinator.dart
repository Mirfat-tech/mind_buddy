import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum OAuthLaunchStatus { started, inProgress, throttled, failed }

class OAuthLaunchResult {
  const OAuthLaunchResult(this.status, {this.message});

  final OAuthLaunchStatus status;
  final String? message;

  bool get started => status == OAuthLaunchStatus.started;
}

class OAuthSignInCoordinator {
  OAuthSignInCoordinator._();

  static final OAuthSignInCoordinator instance = OAuthSignInCoordinator._();
  static const _tapDebounce = Duration(milliseconds: 800);
  static const _oauthTimeout = Duration(seconds: 45);
  // Mobile OAuth should return to the app deep link. The hosted auth domain is
  // configured via Supabase.initialize(url: ...), not via redirectTo.
  static const _redirectTo = 'brainbubble://auth/callback';
  static const timeoutMessage =
      'Google sign-in is taking longer than expected - tap to retry';

  final ValueNotifier<bool> _isSigningIn = ValueNotifier<bool>(false);
  final ValueNotifier<int> _timeoutSignal = ValueNotifier<int>(0);
  DateTime? _lastAttemptAt;
  OAuthProvider? _activeProvider;
  OAuthProvider? _lastRequestedProvider;
  bool _lastRequestedFreshSession = false;
  Timer? _timeoutTimer;

  ValueListenable<bool> get isSigningInListenable => _isSigningIn;
  ValueListenable<int> get timeoutSignalListenable => _timeoutSignal;
  bool get isSigningIn => _isSigningIn.value;
  OAuthProvider? get activeProvider => _activeProvider;

  Future<OAuthLaunchResult> start(
    OAuthProvider provider, {
    bool forceFreshSession = false,
  }) async {
    final existingSession = Supabase.instance.client.auth.currentSession;
    if (existingSession != null && !forceFreshSession) {
      return const OAuthLaunchResult(
        OAuthLaunchStatus.failed,
        message: 'You are already signed in.',
      );
    }

    final now = DateTime.now();
    final last = _lastAttemptAt;
    if (_isSigningIn.value) {
      return const OAuthLaunchResult(
        OAuthLaunchStatus.inProgress,
        message: 'Sign in is already in progress. Finish it in the browser.',
      );
    }
    if (last != null && now.difference(last) < _tapDebounce) {
      return const OAuthLaunchResult(
        OAuthLaunchStatus.throttled,
        message: 'Please wait a moment and try again.',
      );
    }

    _lastAttemptAt = now;
    _activeProvider = provider;
    _lastRequestedProvider = provider;
    _lastRequestedFreshSession = forceFreshSession;
    _isSigningIn.value = true;
    _armTimeout();

    try {
      debugPrint(
        'OAuthCoordinator start provider=$provider redirect=$_redirectTo',
      );
      if (forceFreshSession) {
        try {
          await Supabase.instance.client.auth.signOut(
            scope: SignOutScope.global,
          );
        } catch (_) {
          // Ignore sign-out failures and still attempt OAuth start.
        }
      }
      // Use external auth session on iOS to avoid stuck in-app webview
      // requiring manual "Done" after callback.
      const launchMode = LaunchMode.externalApplication;
      final queryParams = provider == OAuthProvider.google
          ? const {'prompt': 'select_account'}
          : null;
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        queryParams: queryParams,
        redirectTo: _redirectTo,
        authScreenLaunchMode: launchMode,
      );
      return const OAuthLaunchResult(OAuthLaunchStatus.started);
    } on AuthException catch (e) {
      markFailed(reason: 'start_auth_exception');
      return OAuthLaunchResult(OAuthLaunchStatus.failed, message: e.message);
    } catch (e) {
      markFailed(reason: 'start_unexpected_exception');
      return OAuthLaunchResult(
        OAuthLaunchStatus.failed,
        message: 'OAuth failed: $e',
      );
    }
  }

  Future<OAuthLaunchResult> retryLastAttempt({bool forceFreshSession = true}) {
    final provider = _lastRequestedProvider;
    if (provider == null) {
      return Future.value(
        const OAuthLaunchResult(
          OAuthLaunchStatus.failed,
          message: 'No previous OAuth attempt to retry.',
        ),
      );
    }
    return start(
      provider,
      forceFreshSession: forceFreshSession || _lastRequestedFreshSession,
    );
  }

  void markCompleted({String? reason}) {
    _cancelTimeout();
    if (_isSigningIn.value) {
      debugPrint('OAuthCoordinator completed reason=${reason ?? 'unknown'}');
    }
    _activeProvider = null;
    _isSigningIn.value = false;
  }

  void markFailed({String? reason}) {
    _cancelTimeout();
    if (_isSigningIn.value) {
      debugPrint('OAuthCoordinator failed reason=${reason ?? 'unknown'}');
    }
    _activeProvider = null;
    _isSigningIn.value = false;
  }

  void _armTimeout() {
    _cancelTimeout();
    _timeoutTimer = Timer(_oauthTimeout, () {
      if (!_isSigningIn.value) return;
      if (Supabase.instance.client.auth.currentSession != null) {
        markCompleted(reason: 'timeout_guard_session_already_established');
        return;
      }
      markFailed(reason: 'timeout');
      _timeoutSignal.value++;
    });
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }
}
